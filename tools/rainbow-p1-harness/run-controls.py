#!/usr/bin/env python3
"""Sequential executable fault controls over temporary model copies only."""
from pathlib import Path
import argparse, hashlib, json, os, subprocess, tempfile

parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path)
args=parser.parse_args()
root=Path(__file__).resolve().parents[2]
source=root/'Sparkforge/Prototypes/RainbowP1Model.swift'
original=source.read_bytes()
output=args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='rainbow-p1-controls-'))
output.mkdir(parents=True,exist_ok=True)
controls=[
 ('P01-held-time-runs',[('guard owned, holds.isEmpty, raw.isFinite','guard owned, raw.isFinite')]),
 ('P02-accidental7x',[('max(0, current.attacker.ordinaryBasis) * C.sweepMultiplier','max(0, current.attacker.ordinaryBasis) * C.sweepMultiplier * C.primaryMultiplier')]),
 ('P03-always-crit',[('let crit = random() < current.attacker.critChance','let crit = random() < 1')]),
 ('P04-ignore-walls',[('current.attacker.longShotT4 ? entry : Self.firstVisibleContact(','true ? entry : Self.firstVisibleContact(')]),
 ('P05-miss-doorway-exposure',[('candidate = next','return nil')]),
 ('P06-repeated-body-hits',[
     (' && !current.hitIDs.contains(target.id)',''),
     ('guard current.hitIDs.insert(target.id).inserted else { continue }','current.hitIDs.insert(target.id)')]),
 ('P07-endpoint-only',[('MeleeSector.segmentCrossesRoundedBox(a, end, center: .zero,','MeleeSector.segmentCrossesRoundedBox(end, end, center: .zero,')]),
 ('P08-endrun-keeps-front',[('''    mutating func endRun() {
        owned = false
        elapsed = 0
        sweep = nil
    }''','''    mutating func endRun() {
        owned = false
        elapsed = 0
    }''')]),
 ('P09-board-loses-ownership',[('''    mutating func boardHandoff() {
        elapsed = 0''','''    mutating func boardHandoff() {
        owned = false
        elapsed = 0''')]),
 ('P10-double-vulnerability',[('vulnerability: target.vulnerability,','vulnerability: target.vulnerability * target.vulnerability,')]),
 ('P11-zero-damage-floor',[('max(0, current.attacker.ordinaryBasis)','max(1, current.attacker.ordinaryBasis)')]),
 ('P12-animation-delays-nextcycle',[('sweep = current.age >= C.crossing ? nil : current','if current.age >= C.crossing { elapsed = 0 }; sweep = current.age >= C.crossing ? nil : current')]),
 ('P13-wrong-kill-credit',[('var source: KillSource { .capstone }','var source: KillSource { .burst }')]),
 ('P14-zero-hit-melts',[('target.snowman && hit.targetEntry.basis > 0 && hit.targetEntry.dealt > 0','target.snowman')]),
 ('P15-no-board-clipping',[('let visible = viewport.intersection(board)','let visible = viewport')]),
 ('P16-fullheight-lane',[('let height = visible.height * C.laneHeightFraction','let height = visible.height')]),
 ('P17-fixed-center-lane',[('y: origin.y - height / 2,','y: visible.midY - height / 2,')]),
 ('P18-shift-instead-of-clip',[('return proposed.intersection(visible)','return CGRect(x: visible.minX, y: min(visible.maxY - height, max(visible.minY, proposed.minY)), width: visible.width, height: height)')]),
 ('P19-ignore-subframe-aim',[('let origin = fromOrigin.lerp(to: toOrigin, t: fraction)','let origin = toOrigin')]),
 ('P20-wrong-clipped-contact-center',[('let centerY = current.footprint.midY','let centerY = current.origin.y')]),
]
results=[]
for name,edits in controls:
    text=original.decode()
    for before,after in edits:
        if text.count(before)!=1:raise SystemExit(f'{name}: target count {text.count(before)}')
        text=text.replace(before,after)
    mutant=output/(name+'.swift');mutant.write_text(text)
    env=dict(os.environ);env['SPARKFORGE_P1_MODEL_PATH']=str(mutant)
    try:
        run=subprocess.run(['sh',str(root/'tools/rainbow-p1-harness/run.sh')],cwd=root,env=env,capture_output=True,text=True,timeout=180)
        log=run.stdout+run.stderr;(output/(name+'.log')).write_text(log)
        failures=[line for line in log.splitlines() if line.startswith('FAIL ')]
        outcome='KILLED' if run.returncode==1 and failures else ('SURVIVED' if run.returncode==0 else 'ERROR')
        results.append({'name':name,'outcome':outcome,'exit':run.returncode,'failed_checks':failures,'sha256':hashlib.sha256(mutant.read_bytes()).hexdigest()})
    except subprocess.TimeoutExpired:results.append({'name':name,'outcome':'ERROR','reason':'timeout'})
    print(name+': '+results[-1]['outcome'],flush=True)
    (output/'results.json').write_text(json.dumps(results,indent=2)+'\n')
assert source.read_bytes()==original,'Original source changed'
killed=sum(x['outcome']=='KILLED' for x in results)
print(f'Rainbow P1 controls: {killed}/{len(controls)} killed; logs {output}')
raise SystemExit(0 if killed==len(controls) else 1)
