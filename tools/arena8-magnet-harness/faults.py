from pathlib import Path
import subprocess,tempfile,os,json
root=Path(__file__).resolve().parents[2];scene=(root/'Sparkforge/Scenes/GameScene.swift').read_text();results=[]
faults=[('wall-routing','if orb.isVacuuming {','if false && orb.isVacuuming {'),('outer-clamp','orb.position = rooms.bounds.clamped(target, bodyRadius: XPOrbNode.visualRadius) ?? from','orb.position = target'),('overshoot','let step = min(from.distance(to: desired), delta.length)','let step = from.distance(to: desired)'),('passive-phasing','if orb.isVacuuming {','if true {'),('double-credit','guard let index = xpOrbs.firstIndex(where: { $0 === orbNode }) else { return }\n        xpOrbs.remove(at: index)','if let index = xpOrbs.firstIndex(where: { $0 === orbNode }) {xpOrbs.remove(at:index)}')]
for name,old,new in faults:
 assert scene.count(old)==1,(name,'imprecise mutation')
 with tempfile.TemporaryDirectory(prefix='sf-magnet-fault-') as t:
  p=Path(t)/'GameScene.swift';p.write_text(scene.replace(old,new));env=dict(os.environ);env['SPARKFORGE_MAGNET_SCENE']=str(p)
  run=subprocess.run(['sh',str(root/'tools/arena8-magnet-harness/run.sh')],env=env,capture_output=True,text=True)
  detected=run.returncode==1 and 'FAIL ' in run.stdout and 'Magnet real-source:' in run.stdout
  results.append({'fault':name,'detected_by_behavior':detected,'exit':run.returncode,'summary':run.stdout.splitlines()[-1] if run.stdout else run.stderr[-500:]});assert detected,(name,run.stdout,run.stderr)
print(json.dumps(results,indent=2))
