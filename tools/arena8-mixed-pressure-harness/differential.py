"""Compile the actual unmodified WaveManager; compare event ordering without
using the copied reference formula in main.swift as the decisive oracle."""
from pathlib import Path
import hashlib,re,tempfile,subprocess,json
r=Path(__file__).resolve().parents[2]
wave=r/'Sparkforge/Systems/WaveManager.swift';config=r/'Sparkforge/Config/GameConfig.swift';clock=r/'Sparkforge/Prototypes/Arena8PreviewSpawnClock.swift'
constants=[]
for name in ['initialSpawnInterval','minimumSpawnInterval','spawnAcceleration','lateGameAcceleration','lateGameMinInterval','miniBossSpawnTime']:
 match=re.search(r'static let '+name+r': TimeInterval = [0-9.]+',config.read_text());assert match;constants.append(match[0])
source='import Foundation\nenum GameConfig { enum Wave {\n'+'\n'.join(constants)+'\n}}\n'+wave.read_text().replace('import SpriteKit','import Foundation')
main=r'''
import Foundation
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL "+name)}}
for hz in [30,60,120] {
 let wave=WaveManager();var clock=Arena8PreviewSpawnClock(profile:.baseline)
 for _ in 0..<(hz*125) {
  let dt=1.0/Double(hz);let event=wave.update(deltaTime:dt)
  check("actual shipped baseline event",clock.advance(dt:dt,baseInterval:wave.currentSpawnInterval)==event.shouldSpawnEnemy)
 }
}
for samples in [[0.0,0.05,0.1,0.2,0.75,1.0,0,4],[0.016,0.033,0.1],[29.999,0.001,9.999,0.001,19.999,0.001,4.999,0.001,24.999,0.001,14.999,0.001,15]] {
 let wave=WaveManager();var clock=Arena8PreviewSpawnClock(profile:.baseline)
 for _ in 0..<8 {
  for dt in samples {
   let event=wave.update(deltaTime:dt)
   check("actual irregular baseline event",clock.advance(dt:dt,baseInterval:wave.currentSpawnInterval)==event.shouldSpawnEnemy)
  }
 }
}
for hz in [30,60] {
 let control=WaveManager(),trial=WaveManager();var fast=Arena8PreviewSpawnClock(profile:.trial)
 for _ in 0..<(hz*125) {
  let dt=1.0/Double(hz);let old=control.update(deltaTime:dt);let new=trial.update(deltaTime:dt)
  _=fast.advance(dt:dt,baseInterval:trial.currentSpawnInterval)
  check("trial preserves actual game time and bell",control.elapsedTime==trial.elapsedTime && old.shouldSpawnMiniBoss==new.shouldSpawnMiniBoss && control.miniBossSpawned==trial.miniBossSpawned)
 }
 control.reset();trial.reset();fast=Arena8PreviewSpawnClock(profile:.trial)
 check("independent fresh game reset",trial.elapsedTime==0 && !trial.miniBossSpawned && fast.accumulated==0 && fast.attempts==0)
}
print("RESULT \(passed) passed \(failed) failed");exit(failed==0 ? 0:1)
'''
with tempfile.TemporaryDirectory(prefix='sf-mixed-actual-wave-') as d:
 d=Path(d);(d/'Wave.swift').write_text(source);(d/'main.swift').write_text(main)
 built=subprocess.run(['xcrun','swiftc','-module-cache-path',str(d/'cache'),str(clock),str(d/'Wave.swift'),str(d/'main.swift'),'-o',str(d/'proof')],capture_output=True,text=True)
 assert built.returncode==0,built.stderr
 run=subprocess.run([str(d/'proof')],capture_output=True,text=True);print(run.stdout,end='');assert run.returncode==0,run.stderr
 print(json.dumps({'actual_input_pins':{str(p.relative_to(r)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [wave,config,clock]},'scope':'Actual WaveManager+constant input code compiled on host; SpriteKit import substituted Foundation only; not runtime Scene/physics proof'},indent=2))
