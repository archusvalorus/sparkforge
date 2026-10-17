from pathlib import Path
import tempfile,shutil,subprocess,json
root=Path(__file__).resolve().parents[2]
files=['tools/tollkeeper-harness/run.py','tools/tollkeeper-harness/run.sh','tools/tollkeeper-harness/Stubs.swift','tools/tollkeeper-harness/main.swift','tools/railspike-harness/run.sh','tools/railspike-harness/main.swift','tools/signature-draw-harness/extract-config.sh','Sparkforge/Nodes/SwitchwardenNode.swift','Sparkforge/Systems/SwitchwardenState.swift','Sparkforge/Nodes/ArenaBossNode.swift','Sparkforge/Systems/VulnerabilityChannels.swift','Sparkforge/Nodes/TollkeeperNode.swift','Sparkforge/Nodes/RailspikeNode.swift','Sparkforge/Nodes/EnemyNode.swift','Sparkforge/Systems/TollkeeperState.swift','Sparkforge/Systems/RailspikeState.swift','Sparkforge/Systems/ChannelAttackSchedule.swift','Sparkforge/Config/GameConfig.swift','Sparkforge/Config/ArenaGeometry.swift','Sparkforge/Scenes/GameScene.swift','Sparkforge/Systems/MeleeSector.swift','Sparkforge/Utils/VectorMath.swift']
controls=[
('RC1 short tell','Sparkforge/Config/GameConfig.swift','static let tell: TimeInterval = 1.0','static let tell: TimeInterval = 0.01'),
('RC2 short interval','Sparkforge/Config/GameConfig.swift','static let interval: TimeInterval = 0.45','static let interval: TimeInterval = 0.01'),
('RC3 short recovery','Sparkforge/Config/GameConfig.swift','static let recovery: TimeInterval = 1.3','static let recovery: TimeInterval = 0.01'),
('RC4 short cadence','Sparkforge/Config/GameConfig.swift','static let cycle: TimeInterval = 5','static let cycle: TimeInterval = 0.1'),
('RC5 lost second','Sparkforge/Systems/RailspikeState.swift','if shots == 1 {','if shots == 0 {'),
('RC6 queued dead launch','Sparkforge/Nodes/RailspikeNode.swift','guard !isDying, !isFrozen, !isStunned, !isVoidTrapped, !isFeared,','guard !isFrozen, !isStunned, !isVoidTrapped, !isFeared,'),
('RC7 shoved launch','Sparkforge/Nodes/RailspikeNode.swift','position.distance(to: plan.anchor) <= GameConfig.Railspike.arriveRadius else','true else'),
('RC8 ignores live bolt lease','Sparkforge/Systems/ChannelAttackSchedule.swift','owner != .railspike || liveBolts == 0','true'),
('RC9 no clear gap','Sparkforge/Systems/ChannelAttackSchedule.swift','gap = 0.35','gap = 0'),
('RC10 nonalternating priority','Sparkforge/Systems/ChannelAttackSchedule.swift','next = owner == .tollkeeper ? .railspike : .tollkeeper','next = .tollkeeper'),
('RC11 crosslane plan','Sparkforge/Systems/RailspikeState.swift','from.x*player.x > 0','true'),
('RC12 offscreen tell','Sparkforge/Nodes/RailspikeNode.swift','if !canBeginTell || !atAnchor || attack.cooldown > 0','if !atAnchor || attack.cooldown > 0'),
('RC13 lease cooldown boundary','Sparkforge/Nodes/TollkeeperNode.swift','if !atAnchor || attack.cooldown > 0 || !schedule.request(.tollkeeper) { candidate = nil }','if atAnchor && attack.cooldown <= 0 && !schedule.request(.tollkeeper) { candidate = nil }'),
('RC14 no launch pause gate','Sparkforge/Scenes/GameScene.swift','    private func processRailspikeLaunches() {\n        guard isTwinChannels, gameState == .playing else { return }','    private func processRailspikeLaunches() {\n        guard isTwinChannels else { return }'),
]
results=[]
for name,path,before,after in controls:
 with tempfile.TemporaryDirectory(prefix='sf-rail-control-') as temp:
  clone=Path(temp)
  for file in files:
   dest=clone/file;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/file,dest)
  target=clone/path;s=target.read_text();assert s.count(before)==1,(name,s.count(before));target.write_text(s.replace(before,after))
  try:
   run=subprocess.run(['sh',str(clone/'tools/railspike-harness/run.sh')],capture_output=True,text=True,timeout=120)
   outcome='KILLED' if run.returncode==1 and 'FAIL R' in run.stdout and 'error:' not in run.stderr else 'SURVIVED' if run.returncode==0 else 'INVALID'
   record={'name':name,'outcome':outcome,'exit':run.returncode,'failures':[l for l in run.stdout.splitlines() if l.startswith('FAIL')],'stderr':run.stderr[-700:]}
  except subprocess.TimeoutExpired:record={'name':name,'outcome':'TIMEOUT'}
  results.append(record);print(json.dumps(record),flush=True)
print(json.dumps({'killed':sum(r['outcome']=='KILLED' for r in results),'total':len(results)}))
raise SystemExit(0 if all(r['outcome']=='KILLED' for r in results) else 1)
