#!/usr/bin/env python3
"""WR14 guard probe (WB-R1, Oct 14) — WR14 ITSELF must see the beam copy's boss entry.

The catalog harness's NB1 (rider-copy token equality) also rejects a drift in
`landBeamHitOnBoss`, so a whole-harness failure cannot show that WR14's own
boss-entry predicate is alive. WB-R1 was exactly that: an inline `//` comment
silenced WR14's `bossNode.takeDirectHit(bossHit, ignoresChallengeDEF: ignoresDEF)`
predicate while NB1 kept the overall exit nonzero. This probe attributes by NAME.

In isolated throwaway copies (mutations.fresh_copy — the repository is never
edited), it runs the REAL catalog harness three times and reads every `FAIL  <id>`:

  WG0  unmutated copy                                   → WR14 must PASS
  WG1  the reviewer's exact-once mutation inside        → WR14 must FAIL (an
       landBeamHitOnBoss: `ignoresChallengeDEF:            assertion: the run prints its
       ignoresDEF` → `ignoresChallengeDEF: false`          "N passed, M failed" summary)
  WG2  guard-disabling CONTROL: WG1's mutation + the    → WR14 must PASS (the WB-R1 bug
       WB-R1 bug re-created (the boss predicate            reproduced: only NB1 fails) —
       commented out inline in the copy's harness)         so WG1's WR14 failure is the
                                                           boss predicate's, and a future
                                                           commented-out clause makes WG1 fail

Exit 0 only if all three hold. Writes a JSON record (`--out`). `--root` selects the
source tree to copy (default: this repository) — e.g. a frozen snapshot, for a
before/after comparison. Usage:
    python3 tools/catalog-harness/wr14-guard-probe.py [--root DIR] [--out FILE] [--only WG1]
"""
import importlib.util, json, os, re, shutil, stat, subprocess, sys

args = sys.argv[1:]
def opt(name, default=None):
    if name in args:
        i = args.index(name); v = args[i + 1]; del args[i:i + 2]; return v
    return default
root = os.path.abspath(opt('--root', os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))
out = opt('--out')
only = opt('--only')

spec = importlib.util.spec_from_file_location('mut', os.path.join(root, 'tools/catalog-harness/mutations.py'))
mut = importlib.util.module_from_spec(spec); saved = sys.argv; sys.argv = ['x']; spec.loader.exec_module(mut); sys.argv = saved

GS = 'Sparkforge/Scenes/GameScene.swift'
HARNESS = 'tools/catalog-harness/main.swift'
BOSS_FN = '    private func landBeamHitOnBoss(_ hit: DirectHit, projectileNode: ProjectileNode, bossNode: any ArenaBossNode) {'
DEF_OLD, DEF_NEW = 'ignoresChallengeDEF: ignoresDEF', 'ignoresChallengeDEF: false'
GUARD = '&& n(beamFlat, "bossNode.takeDirectHit(bossHit, ignoresChallengeDEF: ignoresDEF)") == 1'


def writable(path):
    os.chmod(path, os.stat(path).st_mode | stat.S_IWUSR)


def mutate_boss_copy(tmp):
    """The reviewer's mutation, exactly once, INSIDE landBeamHitOnBoss only."""
    p = os.path.join(tmp, GS); writable(p)
    text = open(p, encoding='utf-8').read()
    start = text.find(BOSS_FN)
    if start < 0 or text.count(BOSS_FN) != 1:
        raise LookupError('landBeamHitOnBoss signature not found exactly once')
    end = text.find('\n    }\n', start)
    body = text[start:end]
    if body.count(DEF_OLD) != 1:
        raise LookupError(f'{body.count(DEF_OLD)} occurrences of {DEF_OLD!r} in landBeamHitOnBoss')
    open(p, 'w', encoding='utf-8').write(text[:start] + body.replace(DEF_OLD, DEF_NEW) + text[end:])


def reintroduce_wb_r1(tmp):
    """The control: comment the WR14 boss predicate out inline, as WB-R1 did."""
    p = os.path.join(tmp, HARNESS); writable(p)
    text = open(p, encoding='utf-8').read()
    live = ' ' + GUARD + '\n'
    if text.count(live) != 1:
        raise LookupError(f'WR14 boss predicate found {text.count(live)} times')
    open(p, 'w', encoding='utf-8').write(text.replace(live, '   // (WB-R1 control: inline comment) ' + GUARD + '\n'))


def run(label, edits):
    tmp = mut.fresh_copy()
    try:
        for edit in edits:
            edit(tmp)
        r = subprocess.run(['sh', os.path.join(tmp, 'tools/catalog-harness/run.sh')], capture_output=True, text=True,
                           cwd=tmp, timeout=mut.TIMEOUT)
        text = r.stdout + r.stderr
        fails = [l.split('  ')[1].split(' ')[0] for l in text.splitlines() if l.startswith('FAIL  ')]
        summary = next((l for l in reversed(text.splitlines()) if re.match(r'^\d+ passed, \d+ failed$', l)), None)
        return {'label': label, 'exit': r.returncode, 'summary': summary, 'fails': fails,
                'WR14': 'FAIL' if 'WR14' in fails else ('PASS' if summary else 'NOT RUN'),
                'NB1': 'FAIL' if 'NB1' in fails else ('PASS' if summary else 'NOT RUN'),
                'tail': text.strip().splitlines()[-3:]}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


cases = {'WG0': [], 'WG1': [mutate_boss_copy], 'WG2': [mutate_boss_copy, reintroduce_wb_r1]}
results = {}
for k, edits in cases.items():
    if only and k != only:
        continue
    results[k] = run(k, edits)
    print(f"{k}: exit {results[k]['exit']} · {results[k]['summary']} · WR14 {results[k]['WR14']} · NB1 {results[k]['NB1']} · fails {results[k]['fails']}", flush=True)

expect = {'WG0': lambda x: x['summary'] is not None and x['WR14'] == 'PASS',
          'WG1': lambda x: x['summary'] is not None and x['WR14'] == 'FAIL',
          'WG2': lambda x: x['summary'] is not None and x['WR14'] == 'PASS' and x['NB1'] == 'FAIL'}
verdicts = {k: bool(expect[k](v)) for k, v in results.items()}
ok = bool(verdicts) and all(verdicts.values())
record = {'root': root, 'results': results, 'verdicts': verdicts, 'ok': ok}
if out:
    json.dump(record, open(out, 'w'), indent=1)
for k, v in verdicts.items():
    print(f"{'PASS' if v else 'FAIL'}  {k} expectation")
sys.exit(0 if ok else 1)
