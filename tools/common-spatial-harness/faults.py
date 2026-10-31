from pathlib import Path
import json,os,subprocess,tempfile
r=Path(__file__).resolve().parent;root=r.parents[1]
beam=(root/'Sparkforge/Systems/BeamTick.swift').read_text();world=(root/'Sparkforge/Prototypes/Arena8GameMap.swift').read_text()
faults=[
 ('reject-LongShot-infinity','beam','!maxLength.isNaN','maxLength.isFinite'),
 ('ignore-finite-range','beam','var limit = min(maxLength, max(0, exit))','var limit = max(0, exit)'),
 ('ignore-first-solid','beam','guard blocked(origin, end) else { return limit }','guard false else { return limit }'),
 ('parallel-ray-outside-floor','beam','if value < low || value > high { return 0 }','if false { return 0 }'),
 ('store-unsafe-raw-boundary','map','return neighbors.filter { legal($0) }\n            .min { $0.distance(to: point) < $1.distance(to: point) }','return point'),
 ('shove-skips-swept-wall','map','let stopped = geometry.pathShove(from: from, to: end, radius: radius)','let stopped = end'),
 ('walk-becomes-diagonal-shove','map','let result = walkingSweep(from: x, to: CGPoint(x: x.x, y: end.y), radius: radius)','let result = geometry.pathShove(from: from, to: end, radius: radius)'),
]
results=[]
with tempfile.TemporaryDirectory(prefix='sf-common-spatial-faults-') as tmp:
 for name,kind,old,new in faults:
  source=beam if kind=='beam' else world
  if name=='ignore-first-solid':
   # Only mutate the new rectangular overload; original circle stays frozen.
   marker=source.index('static func length(origin: CGPoint, direction d: CGPoint, maxLength: CGFloat, arenaRect')
   assert source[marker:].count(old)==1
   mutated=source[:marker]+source[marker:].replace(old,new,1)
  else:
   assert source.count(old)==1,name
   mutated=source.replace(old,new,1)
  p=Path(tmp)/(name+'.swift');p.write_text(mutated);env=dict(os.environ)
  env['SPARKFORGE_COMMON_BEAM_PATH' if kind=='beam' else 'SPARKFORGE_COMMON_MAP_PATH']=str(p)
  run=subprocess.run(['sh',str(r/'run.sh')],env=env,capture_output=True,text=True)
  failures=[x for x in run.stdout.splitlines() if x.startswith('FAIL ')];caught=run.returncode==1 and bool(failures) and 'RESULT ' in run.stdout
  results.append({'fault':name,'exit':run.returncode,'behaviorally_caught':caught,'failures':failures})
  if not caught:print(run.stdout,run.stderr);raise SystemExit('Fault not caught by executed behavior: '+name)
print(json.dumps(results,indent=2));print('RESULT 7 compile-valid behavioral faults caught')
