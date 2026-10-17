from pathlib import Path
import tempfile,shutil,subprocess,json
root=Path(__file__).resolve().parents[2]
# Match the executed production-seam runner's complete explicit source set.
files=['tools/tollkeeper-harness/run.py','tools/tollkeeper-harness/Stubs.swift','tools/signature-draw-harness/extract-config.sh','tools/switchwarden-harness/run.sh','tools/switchwarden-harness/main.swift','Sparkforge/Nodes/SwitchwardenNode.swift','Sparkforge/Nodes/ArenaBossNode.swift','Sparkforge/Systems/VulnerabilityChannels.swift','Sparkforge/Systems/SwitchwardenState.swift','Sparkforge/Nodes/TollkeeperNode.swift','Sparkforge/Nodes/RailspikeNode.swift','Sparkforge/Nodes/EnemyNode.swift','Sparkforge/Systems/TollkeeperState.swift','Sparkforge/Systems/RailspikeState.swift','Sparkforge/Systems/ChannelAttackSchedule.swift','Sparkforge/Config/GameConfig.swift','Sparkforge/Config/ArenaGeometry.swift','Sparkforge/Scenes/GameScene.swift','Sparkforge/Systems/MeleeSector.swift','Sparkforge/Utils/VectorMath.swift']
controls=[
('SC1 short warning','Sparkforge/Config/GameConfig.swift','static let warning: TimeInterval = 1.5','static let warning: TimeInterval = 0.01'),
('SC2 short surge','Sparkforge/Config/GameConfig.swift','static let surge: TimeInterval = 0.35','static let surge: TimeInterval = 0.01'),
('SC3 short recovery','Sparkforge/Config/GameConfig.swift','static let recovery: TimeInterval = 1.5','static let recovery: TimeInterval = 0.01'),
('SC4 short cycle','Sparkforge/Config/GameConfig.swift','static let cycle: TimeInterval = 4.5','static let cycle: TimeInterval = 0.01'),
('SC5 repeated hazard hit','Sparkforge/Systems/SwitchwardenState.swift','hitSpent = true; return true','hitSpent = false; return true'),
('SC6 zero resurrected by DEF','Sparkforge/Nodes/ArenaBossNode.swift','guard scaled > 0 else { return 0 }','guard scaled >= 0 else { return 0 }'),
('SC7 double vulnerability','Sparkforge/Nodes/SwitchwardenNode.swift','let scaled = resolved ?? (vulnerabilityMultiplier == 1.0 ? amount : Int((CGFloat(amount) * vulnerabilityMultiplier).rounded()))','let scaled=(vulnerabilityMultiplier==1 ? amount:Int((CGFloat(amount)*vulnerabilityMultiplier).rounded()))'),
('SC8 death leaves attack','Sparkforge/Nodes/SwitchwardenNode.swift','isDead=true;cancelAttack();physicsBody?.categoryBitMask=0','isDead=true;physicsBody?.categoryBitMask=0'),
('SC9 shoved surge','Sparkforge/Nodes/SwitchwardenNode.swift','position.distance(to:plan.anchor)<=GameConfig.Switchwarden.arriveRadius else','true else'),
('SC10 boss ignores hostile bolts','Sparkforge/Systems/ChannelAttackSchedule.swift','bossRequested && hostileBolts == 0','bossRequested'),
('SC11 spawn over crowd','Sparkforge/Scenes/GameScene.swift','channelArrivalPending, enemies.isEmpty, enemyProjectiles.isEmpty,','channelArrivalPending, enemyProjectiles.isEmpty,'),
('SC12 old arena leak','Sparkforge/Scenes/GameScene.swift','guard isTwinChannels, !isGauntlet, gameState == .playing,','guard !isGauntlet, gameState == .playing,'),
('SC13 wrong damage class','Sparkforge/Scenes/GameScene.swift','applyBossHazardDamage(GameConfig.Marchwarden.contactDamage,shakeIntensity:4)','applyBossHazardDamage(GameConfig.Marchwarden.contactDamage,shakeIntensity:4,fromBossClass:false)'),
('SC14 stale body radius','Sparkforge/Scenes/GameScene.swift','overseer.playerHitRadius=playerStats.effectiveCollisionRadius','overseer.playerHitRadius=GameConfig.Player.collisionRadius'),
('SC15 boss bypasses coordinator','Sparkforge/Nodes/SwitchwardenNode.swift','else if let schedule=schedule,!schedule.request(.switchwarden){candidate=nil}','else if false{candidate=nil}'),
('SC16 blanket reaches end crossing','Sparkforge/Systems/SwitchwardenState.swift','width: 0.86*radius, height: 0.36*radius','width: 0.86*radius, height: 1.8*radius'),
('SC17 growing body keeps stale witness','Sparkforge/Systems/SwitchwardenState.swift','playerRadius <= self.playerRadius+0.001','true'),
('SC18 slowing keeps stale witness','Sparkforge/Systems/SwitchwardenState.swift','min(GameConfig.Player.speed,moveSpeed)+0.001 >= self.moveSpeed','true'),
('SC19 ignores kill gate','Sparkforge/Scenes/GameScene.swift','killCount >= GameConfig.Wave.bossSpawnKills,\n           waveManager.elapsedTime >= GameConfig.Wave.bossTimeFloor(for: .arena),','true,\n           waveManager.elapsedTime >= GameConfig.Wave.bossTimeFloor(for: .arena),'),
('SC20 ignores time gate','Sparkforge/Scenes/GameScene.swift','waveManager.elapsedTime >= GameConfig.Wave.bossTimeFloor(for: .arena),','true,'),
('SC21 ignores miniboss gate','Sparkforge/Scenes/GameScene.swift','!enemies.contains(where: { $0.isMiniBoss && !$0.isDying }) {','true {'),
('SC22 waiting latch lost','Sparkforge/Scenes/GameScene.swift','    private func updateSwitchwardenArrival() {','    private func updateSwitchwardenArrival() { channelArrivalPending = false'),
('SC23 entry ignores hostile projectiles','Sparkforge/Scenes/GameScene.swift','channelArrivalPending, enemies.isEmpty, enemyProjectiles.isEmpty,','channelArrivalPending, enemies.isEmpty,'),
('SC24 entry ignores active attack owner','Sparkforge/Scenes/GameScene.swift','              channelAttacks.owner == nil else { return }','              true else { return }'),
('SC25 drops boss discovery credit','Sparkforge/Scenes/GameScene.swift','CodexManager.shared.recordDefeat(.switchwarden)','_ = 0'),
('SC26 fails cleanup latch','Sparkforge/Scenes/GameScene.swift','        channelArrivalPending = false\n        channelSwitchwardenSpawned = false','        channelSwitchwardenSpawned = false'),
('SC27 skips BossMode spawner','Sparkforge/Scenes/GameScene.swift','        case "switchwarden":   spawnSwitchwarden()','        case "switchwarden":   break'),
('SC28 removes wave suppression','Sparkforge/Scenes/GameScene.swift','        if channelArrivalPending { return }','        if false { return }'),
('SC29 removes miniboss bell suppression','Sparkforge/Scenes/GameScene.swift','        if !channelArrivalPending {','        if true {'),
('SC30 loses scaled miniboss safety','Sparkforge/Scenes/GameScene.swift','twinChannelsSpawnPoint(actorRadius: boss.geometryFootprintRadius)','twinChannelsSpawnPoint()'),
]
results=[]
for name,path,before,after in controls:
 with tempfile.TemporaryDirectory(prefix='sf-switch-control-') as temp:
  clone=Path(temp)
  for file in files:
   target=clone/file;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/file,target)
  target=clone/path;s=target.read_text();assert s.count(before)==1,(name,s.count(before));target.write_text(s.replace(before,after))
  try:
   run=subprocess.run(['sh',str(clone/'tools/switchwarden-harness/run.sh')],capture_output=True,text=True,timeout=120)
   outcome='KILLED' if run.returncode==1 and 'FAIL S' in run.stdout and 'error:' not in run.stderr else 'SURVIVED' if run.returncode==0 else 'INVALID'
   record={'name':name,'outcome':outcome,'exit':run.returncode,'failures':[l for l in run.stdout.splitlines() if l.startswith('FAIL')],'stderr':run.stderr[-700:]}
  except subprocess.TimeoutExpired:record={'name':name,'outcome':'TIMEOUT'}
  results.append(record);print(json.dumps(record),flush=True)
print(json.dumps({'killed':sum(x['outcome']=='KILLED' for x in results),'total':len(results)}))
raise SystemExit(0 if all(x['outcome']=='KILLED' for x in results) else 1)
