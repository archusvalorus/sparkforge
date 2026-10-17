from pathlib import Path
import tempfile,shutil,subprocess,json
root=Path(__file__).resolve().parents[2]
files=['tools/tollkeeper-harness/run.py','tools/tollkeeper-harness/run.sh','tools/tollkeeper-harness/Stubs.swift','tools/tollkeeper-harness/main.swift','tools/signature-draw-harness/extract-config.sh','Sparkforge/Nodes/SwitchwardenNode.swift','Sparkforge/Systems/SwitchwardenState.swift','Sparkforge/Nodes/ArenaBossNode.swift','Sparkforge/Systems/VulnerabilityChannels.swift','Sparkforge/Nodes/TollkeeperNode.swift','Sparkforge/Nodes/RailspikeNode.swift','Sparkforge/Systems/RailspikeState.swift','Sparkforge/Systems/ChannelAttackSchedule.swift','Sparkforge/Nodes/EnemyNode.swift','Sparkforge/Systems/TollkeeperState.swift','Sparkforge/Config/GameConfig.swift','Sparkforge/Config/ArenaGeometry.swift','Sparkforge/Scenes/GameScene.swift','Sparkforge/Systems/MeleeSector.swift','Sparkforge/Utils/VectorMath.swift']
controls=[
('TC1 damage during tell','Sparkforge/Systems/TollkeeperState.swift','guard phase == .pulse, !hitSpent','guard phase == .windup || phase == .pulse, !hitSpent'),
('TC2 repeated pulse hit','Sparkforge/Systems/TollkeeperState.swift','hitSpent = true\n        return true','hitSpent = false\n        return true'),
('TC3 disabled state continues','Sparkforge/Systems/TollkeeperState.swift','if disabled { cancel(); return }','if false { cancel(); return }'),
('TC4 shortened tell','Sparkforge/Config/GameConfig.swift','static let windup: TimeInterval = 0.9','static let windup: TimeInterval = 0.01'),
('TC5 full crossing blanket','Sparkforge/Config/GameConfig.swift','static let halfLengthFraction: CGFloat = 0.15','static let halfLengthFraction: CGFloat = 0.43'),
('TC6 false boss-class damage','Sparkforge/Scenes/GameScene.swift','applyBossHazardDamage(damage, shakeIntensity: 4, fromBossClass: false)','applyBossHazardDamage(damage, shakeIntensity: 4, fromBossClass: true)'),
('TC7 ignore live body radius','Sparkforge/Scenes/GameScene.swift','keeper.consumePulse(player: player.position, radius: playerStats.effectiveCollisionRadius)','keeper.consumePulse(player: player.position, radius: 10)'),
('TC8 duplicate controller','Sparkforge/Systems/TollkeeperState.swift','firstSpawn && living == 0','firstSpawn && living >= 0'),
('TC9 post-shove still damages','Sparkforge/Nodes/TollkeeperNode.swift','position.distance(to: plan.anchor) <= GameConfig.Tollkeeper.arriveRadius','true'),
('TC10 fire through divider','Sparkforge/Systems/TollkeeperState.swift','!geometry.segmentBlockedExact(plan.anchor, player,\n                  travelRadius: GameConfig.Geometry.projectileTravelRadius)','true'),
('TC11 cycle too short','Sparkforge/Config/GameConfig.swift','static let cycle: TimeInterval = 3.5','static let cycle: TimeInterval = 0.1'),
('TC12 polling cancels seeking','Sparkforge/Nodes/TollkeeperNode.swift','guard attack.phase == .pulse else { return false }',''),
]
results=[]
for name,path,before,after in controls:
 with tempfile.TemporaryDirectory(prefix='sf-toll-control-') as temp:
  clone=Path(temp)
  for file in files:
   dest=clone/file;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/file,dest)
  target=clone/path;s=target.read_text();assert s.count(before)==1,(name,s.count(before));target.write_text(s.replace(before,after))
  try:
   run=subprocess.run(['sh',str(clone/'tools/tollkeeper-harness/run.sh')],capture_output=True,text=True,timeout=120)
   outcome='KILLED' if run.returncode==1 and 'FAIL T' in run.stdout and 'error:' not in run.stderr else 'SURVIVED' if run.returncode==0 else 'INVALID'
   record={'name':name,'outcome':outcome,'exit':run.returncode,'failures':[l for l in run.stdout.splitlines() if l.startswith('FAIL')],'stderr':run.stderr[-500:]}
  except subprocess.TimeoutExpired:record={'name':name,'outcome':'TIMEOUT'}
  results.append(record);print(json.dumps(record),flush=True)
print(json.dumps({'killed':sum(r['outcome']=='KILLED' for r in results),'total':len(results)}))
raise SystemExit(0 if all(r['outcome']=='KILLED' for r in results) else 1)
