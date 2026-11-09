#!/usr/bin/env python3
"""Compile-valid, named WR12/WR21 guard controls. Never edits the source repo.
Four serial Debug compilations/catalog runs in a separate output source copy;
known baseline failures are retained, not counted as a successful whole suite.
Requires an explicit cache and fresh output path. No Simulator/signing/upload.
"""
from pathlib import Path
import argparse,subprocess,shutil,json,hashlib,time,os,signal
parser=argparse.ArgumentParser();parser.add_argument('--packages',required=True);parser.add_argument('--output',required=True);a=parser.parse_args()
root=Path(__file__).resolve().parents[2];out=Path(a.output).resolve();assert not out.exists();assert root!=out and root not in out.parents
out.mkdir();c=out/'source';shutil.copytree(root,c)
node=c/'Sparkforge/Nodes/LockmarshalNode.swift';oldboss=c/'Sparkforge/Nodes/BossNode.swift';scene=c/'Sparkforge/Scenes/GameScene.swift'
original={p:p.read_text() for p in [node,oldboss,scene]}
faults=[('baseline',None,None,None,None),
 ('new-body-consumer',node,'CGFloat(amount) * vulnerabilityMultiplier','CGFloat(amount) * vulnerabilityMultiplier * vulnerabilityMultiplier','WR12'),
 ('old-body-consumer',oldboss,'CGFloat(amount) * vulnerabilityMultiplier','CGFloat(amount) * vulnerabilityMultiplier * vulnerabilityMultiplier','WR12'),
 ('live-radius-bypass',scene,'(boss as? PlayerReachHazards)?.playerHitRadius = playerStats.effectiveCollisionRadius','(boss as? PlayerReachHazards)?.playerHitRadius = GameConfig.Player.collisionRadius','WR21')]
(out/'catalog-harness-main.swift').write_bytes((c/'tools/catalog-harness/main.swift').read_bytes())
for index,(path,text) in enumerate(original.items()):
 (out/('original-target-'+str(index)+'-'+path.name)).write_text(text)
def run_owned(command,log,timeout):
 process=subprocess.Popen(command,cwd=c,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 try:return subprocess.CompletedProcess(command,process.wait(timeout=timeout))
 except subprocess.TimeoutExpired:
  # This process group belongs only to the just-created validation runner.
  os.killpg(process.pid,signal.SIGTERM)
  try:process.wait(timeout=15)
  except subprocess.TimeoutExpired:
   os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=10)
  raise RuntimeError('Owned validation runner exceeded finite timeout; stopped its group: '+str(process.pid))

results=[];baseline_fails=None
for name,target,old,new,expected in faults:
 for p,text in original.items():p.write_text(text)
 if target:
  assert target.read_text().count(old)==1,name;target.write_text(target.read_text().replace(old,new))
  (out/(name+'-mutated-source.swift')).write_text(target.read_text())
 pins={str(p.relative_to(c)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (c/'Sparkforge').rglob('*.swift')}
 command=['xcodebuild','-project','Sparkforge.xcodeproj','-scheme','Sparkforge','-configuration','Debug','-destination','generic/platform=iOS Simulator','-derivedDataPath',str(out/'DerivedData'),'-clonedSourcePackagesDirPath',a.packages,'-disableAutomaticPackageResolution','-skipPackageUpdates','-onlyUsePackageVersionsFromResolvedFile','-jobs','1','CODE_SIGNING_ALLOWED=NO','COMPILER_INDEX_STORE_ENABLE=NO','build']
 with (out/(name+'-build.log')).open('w') as log:b=run_owned(command,log,300)
 assert b.returncode==0,'App mutation must compile: '+name
 with (out/(name+'-catalog.log')).open('w') as log:q=run_owned(['sh','tools/catalog-harness/run.sh'],log,180)
 raw=(out/(name+'-catalog.log')).read_text();assert q.returncode==1,'Known baseline guard failures must remain executed/nonzero'
 assert 'error:' not in raw and 'passed, ' in raw,'Expected executed catalog assertion output'
 fails=[line.split()[1] for line in raw.splitlines() if line.startswith('FAIL  ')]
 if target is None:
  baseline_fails=fails;assert len(fails)==5 and set(fails)=={'WR5','PB-E','WR17','WR19','WR20'}
 else:assert sorted(fails)==sorted(baseline_fails+[expected]),(name,fails,baseline_fails)
 assert pins=={str(p.relative_to(c)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (c/'Sparkforge').rglob('*.swift')}
 binary=out/'DerivedData/Build/Products/Debug-iphonesimulator/Sparkforge.app/Sparkforge.debug.dylib'
 item={'name':name,'app_compile_exit':b.returncode,'catalog_exit':q.returncode,'failed_guard_ids':fails,'expected_additional_guard':expected,'matched_expected':True,'source_pins':pins,'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'catalog_harness_sha256':hashlib.sha256((c/'tools/catalog-harness/main.swift').read_bytes()).hexdigest()}
 results.append(item);(out/'receipts.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps({k:v for k,v in item.items() if k not in ['source_pins']}),flush=True)
print('Catalog guard controls: baseline5known failures retained;3specific compile-valid negatives caught')
