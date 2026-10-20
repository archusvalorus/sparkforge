#!/usr/bin/env python3
"""Sequential fault controls; never mutate a repository input.

A control counts only if the executable harness returns 1 and prints FAIL.
Compiler errors, extraction errors, crashes and timeouts are separate errors.
"""
from pathlib import Path
import argparse, hashlib, json, os, subprocess, tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='rainbow-r0-controls-'))
output.mkdir(parents=True, exist_ok=True)
policy = root/'Sparkforge/Systems/RainbowPolicy.swift'
manager = root/'Sparkforge/Systems/UpgradeManager.swift'
inputs = {p: p.read_bytes() for p in (policy, manager)}
controls = [
    ('C01-neutral-required', policy, 'manager.activeFamilies.subtracting([.neutral])', 'manager.activeFamilies'),
    ('C02-one-color-qualifies', policy, 'requiredColors.isSubset(of: coveredColors)', '!coveredColors.isEmpty'),
    ('C03-reroll-creates-entitlement', policy, 'if !fresh && offeredLevel != level { return nil }', 'if false { return nil }'),
    ('C04-overwrite-guarantees', policy, 'seats.firstIndex(where: { $0.protections.isEmpty })', 'seats.firstIndex(where: { _ in true })'),
    ('C05-drop-reroll-retention', policy, 'if !fresh && offeredLevel != level { return nil }', 'if !fresh { return nil }'),
    ('C06-every-level-reoffer', policy, 'nextOfferLevel = level + 2', 'nextOfferLevel = level + 1'),
    ('C07-free-commit-at-cap', policy, 'guard source == .ordinaryLevelUp, owedPicks > 0,\n              offer.reward', 'guard source == .ordinaryLevelUp,\n              offer.reward'),
    ('C08-ignore-prior-form', policy, 'conflict = !snapshot.capabilities.isDisjoint(with: [.chaosBeam, .glacialCondensation])', 'conflict = false'),
    ('C09-admit-conflicting-tier', policy, 'return grants.isDisjoint(with: [.chaosBeam, .glacialCondensation])', 'return grants.isDisjoint(with: [])'),
    ('C10-stale-reroll-receipt', policy, '''            offeredLevel = nil
            phase = .deferred
            return nil''', '''            phase = .deferred
            return nil'''),
    ('C11-stalled-focus-kept', manager, '&& nextTierOpen($0, additionalTierGate: additionalTierGate)', '&& nextTierOpen($0)'),
    ('C12-double-pick-cost', policy, 'picksConsumed: 1, picksRemaining: owedPicks - 1', 'picksConsumed: 2, picksRemaining: owedPicks - 2'),
]
results = []
for name, path, old, new in controls:
    source = inputs[path].decode()
    if source.count(old) != 1:
        raise SystemExit(f'{name}: expected exactly one target, found {source.count(old)}')
    mutated = output/(name + '.swift')
    mutated.write_text(source.replace(old, new))
    env = dict(os.environ)
    key = 'SPARKFORGE_RAINBOW_POLICY_PATH' if path == policy else 'SPARKFORGE_RAINBOW_MANAGER_PATH'
    env[key] = str(mutated)
    try:
        run = subprocess.run(['sh', str(root/'tools/rainbow-harness/run.sh')], cwd=root,
                             env=env, capture_output=True, text=True, timeout=180)
        log = run.stdout + run.stderr
        (output/(name + '.log')).write_text(log)
        failures = [line for line in log.splitlines() if line.startswith('FAIL ')]
        outcome = 'KILLED' if run.returncode == 1 and failures else ('SURVIVED' if run.returncode == 0 else 'ERROR')
        results.append({'name': name, 'outcome': outcome, 'exit': run.returncode, 'failed_checks': failures,
                        'mutant_sha256': hashlib.sha256(mutated.read_bytes()).hexdigest()})
    except subprocess.TimeoutExpired:
        results.append({'name': name, 'outcome': 'ERROR', 'reason': 'timeout'})
    print(f'{name}: {results[-1]["outcome"]}', flush=True)
    (output/'results.json').write_text(json.dumps(results, indent=2)+'\n')
assert all(p.read_bytes() == data for p, data in inputs.items()), 'An original input changed'
killed = sum(r['outcome'] == 'KILLED' for r in results)
print(f'Rainbow R0 controls: {killed}/{len(controls)} killed; logs {output}')
raise SystemExit(0 if killed == len(controls) else 1)
