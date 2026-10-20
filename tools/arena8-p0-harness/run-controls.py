#!/usr/bin/env python3
"""Sequential executable controls over temporary DEBUG proof source only."""
from pathlib import Path
import argparse,os,subprocess,json,hashlib
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[2];out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
model=root/'Sparkforge/Prototypes/Arena8P0Model.swift';bounds=root/'Sparkforge/Prototypes/Arena8P0Bounds.swift'
original={'model':model.read_text(),'bounds':bounds.read_text()}
controls=[
 ('P01-default-rectangle','bounds',[('self = .circle(center: .zero, radius: GameConfig.Arena8Prototype.defaultCircleRadius)','self = .rectangle(GameConfig.Arena8Prototype.world)')]),
 ('P02-ignore-body-inset','bounds',[('min(rect.maxX - bodyRadius, max(rect.minX + bodyRadius, point.x))','min(rect.maxX, max(rect.minX, point.x))'),('min(rect.maxY - bodyRadius, max(rect.minY + bodyRadius, point.y))','min(rect.maxY, max(rect.minY, point.y))')]),
 ('P03-origin-circle','bounds',[('let offset = point - center','let offset = point')]),
 ('P04-endpoint-walk','model',[('return ArenaGeometry(blockedFootprints: obstacles).pathShove(from: from, to: to, radius: radius)','return to')]),
 ('P05-reversed-support-plane','model',[('return delta.x * normal.x + delta.y * normal.y < 0','return delta.x * normal.x + delta.y * normal.y > 0')]),
 ('P06-shove-wraps-corner','model',[('let stopped = geometry.pathShove(from: from, to: end, radius: radius)','let stopped = move(from: from, toward: end, radius: radius) ?? from')]),
 ('P07-ignore-route','model',[('next = waypoint.position','next = goal')]),
 ('P08-reject-small-player-goal','model',[('guard bounds.contains(goal), !geometry.isBlocked(goal) else { return nil }','guard valid(goal, radius: radius) else { return nil }')]),
 ('P09-ignore-route-body','model',[('travelRadius: radius, arriveRadius: C.arrival','travelRadius: 0, arriveRadius: C.arrival')]),
 ('P10-unsafe-spawn','model',[('candidates.first { valid($0, radius: radius) && $0.distance(to: point) >= clearance + radius }','candidates.first')]),
 ('P11-ignore-wall-hit','model',[('return longShot || !geometry.segmentBlockedExact(from, to)','return true')]),
 ('P12-ignore-LongShot','model',[('return longShot || !geometry.segmentBlockedExact(from, to)','return false || !geometry.segmentBlockedExact(from, to)')]),
 ('P13-radial-retirement','model',[('Arena8P0Bounds.rectangle(C.world.insetBy(dx: -C.projectileMargin, dy: -C.projectileMargin)).contains(point)','point.length <= C.defaultCircleRadius')]),
 ('P14-ignore-hold','model',[('guard !held, raw.isFinite, raw > 0','guard raw.isFinite, raw > 0')]),
 ('P15-unbounded-hitch','model',[('let dt = min(raw, C.maximumStep)','let dt = raw')]),
]
results=[]
for name,kind,edits in controls:
 text=original[kind]
 for before,after in edits:
  if text.count(before)!=1:raise SystemExit(name+' target count '+str(text.count(before)))
  text=text.replace(before,after)
 f=out/(name+'.swift');f.write_text(text);env=dict(os.environ);env['SPARKFORGE_P0_'+kind.upper()+'_PATH']=str(f)
 try:
  run=subprocess.run(['sh',str(root/'tools/arena8-p0-harness/run.sh')],cwd=root,env=env,text=True,capture_output=True,timeout=180)
  log=run.stdout+run.stderr;(out/(name+'.log')).write_text(log);fail=[x for x in log.splitlines() if x.startswith('FAIL ')]
  outcome='KILLED' if run.returncode==1 and fail and 'error:' not in log else ('SURVIVED' if run.returncode==0 else 'ERROR')
  results.append({'name':name,'kind':kind,'outcome':outcome,'exit':run.returncode,'failed_checks':fail,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
 except subprocess.TimeoutExpired:results.append({'name':name,'outcome':'ERROR','reason':'timeout'})
 print(name+': '+results[-1]['outcome'],flush=True);(out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
assert model.read_text()==original['model'] and bounds.read_text()==original['bounds']
print(str(sum(x['outcome']=='KILLED' for x in results))+'/'+str(len(results))+' killed')
raise SystemExit(0 if all(x['outcome']=='KILLED' for x in results) else 1)
