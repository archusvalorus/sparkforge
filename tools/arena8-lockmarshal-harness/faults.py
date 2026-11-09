from pathlib import Path
import tempfile,subprocess,os,json,hashlib
r=Path(__file__).resolve().parents[2]; source=r/'Sparkforge/Prototypes/LockmarshalModel.swift';original=source.read_text()
cases=[
 ('hold-bypass','raw > 0, !held,','raw > 0, true,'),
 ('advance-homing','case .advance:\n            let before','case .advance:\n            goal=player\n            let before'),
 ('wall-sweep-bypass','position = Arena8KaijuLunge(map: map).step(from: before,\n                toward: before + delta.normalized * travel, radius: C.bodyRadius)','position = before + delta.normalized * travel'),
 ('cancel-rearm','mutating func cancel() { phase = .cancelled','mutating func cancel() { phase = .pursuit'),
 ('stamp-through-solid','let visible=footprint.visibilityPolygon','let visible=Self.rectangleVertices(square)'),
 ('repeat-advance-hits','if !advanceHit && Self.advanceContact','if Self.advanceContact'),
 ('invalid-contact-floor-bypass','&& map.valid(playerAtContact,radius:playerRadius)','&& true'),
 ('ignore-body-reach','segmentDistance(point,polygon[$0],polygon[($0+1)%polygon.count]) <= radius','segmentDistance(point,polygon[$0],polygon[($0+1)%polygon.count]) <= 0')]
output=Path(os.environ["SPARKFORGE_LOCKMARSHAL_FAULT_OUTPUT"]) if "SPARKFORGE_LOCKMARSHAL_FAULT_OUTPUT" in os.environ else Path(tempfile.mkdtemp(prefix="sf-lockmarshal-fault-evidence-"))
output.mkdir(exist_ok=True)
results=[]
for name,a,b in cases:
 assert original.count(a)==1,(name,original.count(a))
 with tempfile.TemporaryDirectory(prefix='sf-lockmarshal-fault-') as d:
  p=Path(d)/'LockmarshalModel.swift';p.write_text(original.replace(a,b));env=dict(os.environ,SPARKFORGE_LOCKMARSHAL_MODEL=str(p))
  x=subprocess.run(['sh',str(r/'tools/arena8-lockmarshal-harness/run.sh')],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  (output/(name+".swift")).write_text(p.read_text());(output/(name+".log")).write_text(x.stdout)
  # Only an actually executed assertion failure counts; compiler errors never do.
  caught=x.returncode==1 and 'Lockmarshal model:' in x.stdout and 'FAIL ' in x.stdout and 'error:' not in x.stdout
  results.append({'name':name,'exit':x.returncode,'caught_by_assertions':caught,'mutant_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'log_path':str(output/(name+'.log'))});(output/'receipts.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps({k:v for k,v in results[-1].items() if k!='log'}),flush=True)
  if not caught: print(x.stdout);raise SystemExit('Fault control did not execute/catch: '+name)
print('Lockmarshal behavioral faults: '+str(len(results))+' caught')
