"""Compile-valid bounded ledger faults. No Xcode, devices or canonical writes."""
from pathlib import Path
import json, subprocess, tempfile
root = Path(__file__).resolve().parents[2]
source = root / 'Sparkforge/Prototypes/Arena8NaturalWaveRun.swift'
original = source.read_text()
faults = [
 ('early-packet', 'static let packetIntroduction: TimeInterval = 30', 'static let packetIntroduction: TimeInterval = 0', 'before30-ordinary'),
 ('underfunded-packet', 'packetCost - 1 ? .reservePacket', 'packetCost - 2 ? .reservePacket', 'next-reserve'),
 ('free-packet-bodies', 'packetSlots = reservedSlots + 1;', 'packetSlots = 1;', 'accounting'),
 ('lost-blocked-fallback-accounting', 'ordinarySlots += 1', 'ordinarySlots += 0', 'accounting'),
 ('repeat-packet', 'packetIntroduced = true', 'packetIntroduced = false', 'placed-packet-exact-cost'),
 ('early-source', 'static let signalerIntroduction: TimeInterval = 34', 'static let signalerIntroduction: TimeInterval = 30', 'before34-ordinary'),
 ('reusable-completion', '        pending = nil\n        switch', '        // faulty reusable completion\n        switch', 'duplicate-finish-rejected'),
 ('repeat-command', 'guard signalerIntroduced, !commandPrepared else', 'guard signalerIntroduced else', 'command-once'),
 ('source-without-carrier', 'if carrierAlive { action = .signaler }', 'if true { action = .signaler }', 'lost-carrier-skips-source'),
 ('ignores-hold', 'guard !held, pending == nil,', 'guard pending == nil,', 'hold-no-emission'),
]
results = []
with tempfile.TemporaryDirectory(prefix='sf-natural-faults-') as tmp:
    work = Path(tmp)
    (work/'Mode.swift').write_bytes((root/'Sparkforge/Prototypes/Arena8MixedPressureMode.swift').read_bytes())
    (work/'Clock.swift').write_bytes((root/'Sparkforge/Prototypes/Arena8PreviewSpawnClock.swift').read_bytes())
    (work/'main.swift').write_bytes((root/'tools/arena8-natural-waves-harness/main.swift').read_bytes())
    for name, old, new, expected in faults:
        assert original.count(old) == 1, name
        (work/'Run.swift').write_text(original.replace(old,new,1))
        built = subprocess.run(['swiftc','-module-cache-path',str(work/'cache'),'-D','DEBUG',str(work/'Run.swift'),str(work/'Mode.swift'),str(work/'Clock.swift'),str(work/'main.swift'),'-o',str(work/'proof')],capture_output=True,text=True)
        assert built.returncode == 0, name + ' did not compile: ' + built.stderr
        run = subprocess.run([str(work/'proof')],capture_output=True,text=True,timeout=15)
        caught = run.returncode == 1 and ('FAIL ' + expected) in run.stdout and 'RESULT ' in run.stdout
        results.append({'fault':name,'compile_exit':0,'run_exit':run.returncode,'expected_assertion':expected,'caught':caught})
        print(json.dumps(results[-1]),flush=True)
        assert caught, name + ': ' + run.stdout[-1800:]
print('RESULT',len(results),'compile-valid behavioral faults caught')
