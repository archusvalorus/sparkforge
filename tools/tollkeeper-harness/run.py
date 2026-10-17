from pathlib import Path
import subprocess,tempfile,shutil,os,sys
root=Path(__file__).resolve().parents[2]
def block(text,marker):
 start=text.index(marker); brace=text.index('{',start); end=brace+1; depth=1
 while depth:
  depth+=(text[end]=='{')-(text[end]=='}');end+=1
 return text[start:end].replace('private ','')
scene=(root/'Sparkforge/Scenes/GameScene.swift').read_text();node=(root/'Sparkforge/Nodes/TollkeeperNode.swift').read_text();enemy=(root/'Sparkforge/Nodes/EnemyNode.swift').read_text()
scene_methods=[block(scene,x).replace('override ','') for x in ['    private func twinChannelsSpawnPoint()', '    private func spawnTwinChannelsBody()', '    private func spawnTwinChannelsEnemy()', '    private func processTollkeeperPulses()', '    private func processRailspikeLaunches()', '    private func updateChannelAttacks(_ dt:', '    private var channelPrototypeArrivalDue:', '    private func spawnSwitchwardenPreviewIfReady()', '    private func processSwitchwardenSurge()', '    override func didFinishUpdate()']]
node_methods=[block(node,x) for x in ['    func cancelAttack()', '    func approachGoal(', '    override func chase(', '    func consumePulse(']]
node_head='class TollkeeperNode: EnemyNode {\n var schedule:ChannelAttackSchedule?\n var attack=TollkeeperState()\n var pendingPlan:TollkeeperPlan?\n var attackVisual=FakeVisual()\n var onAimStart:(()->Void)?\n var attackRect:CGRect? { attack.attackRect }\n var syncCalls=0\n init() { super.init(health:1,moveSpeed:GameConfig.Enemy.baseSpeed,xpValue:3) }\n func syncAttackVisual() { syncCalls += 1 }\n'
rail=(root/'Sparkforge/Nodes/RailspikeNode.swift').read_text()
rail_methods=[block(rail,x) for x in ['    func cancelAttack()', '    func approachGoal(', '    override func chase(', '    func consumeLaunch()']]
rail_head='class RailspikeNode: EnemyNode {\n var attack=RailspikeState()\n var pendingPlan:RailspikePlan?\n var schedule:ChannelAttackSchedule?\n var canBeginTell=true\n var onAimStart:(()->Void)?\n var rail=FakeVisual()\n var attackRect:CGRect? {attack.plan?.rect}\n init(){super.init(health:1,moveSpeed:GameConfig.Enemy.baseSpeed*0.8,xpValue:3)}\n func syncAttackVisual(){}\n'
warden=(root/'Sparkforge/Nodes/SwitchwardenNode.swift').read_text()
warden_methods=[block(warden,x) for x in ['    func cancelAttack()', '    func update(', '    func consumeSurge(', '    func declarationValid()', '    func applyChallengeHealthScale(', '    func takeDamage(']]
warden_head='class SwitchwardenNode:SKNode,ArenaBossNode,PlayerReachHazards {\n var health=GameConfig.Marchwarden.baseHealth;var maxHealth=GameConfig.Marchwarden.baseHealth;var isDead=false\n var vulnerability=VulnerabilityChannels();var challengeFlatReduction=0;var healthPercent:CGFloat{CGFloat(health)/CGFloat(maxHealth)}\n var contactDamage:Int{GameConfig.Marchwarden.contactDamage};var geometryFootprintRadius:CGFloat{GameConfig.Arena.radius*GameConfig.Switchwarden.bodyFraction};var hitBodyRadius:CGFloat{geometryFootprintRadius*0.85}\n var playerHitRadius:CGFloat=10;var playerMoveSpeed:CGFloat=250;var onLethalHit:((Int)->Void)?;var onDeath:(()->Void)?;var schedule:ChannelAttackSchedule?;var planProvider:((CGPoint)->SwitchwardenPlan?)?\n var geometry=ArenaGeometry.twinChannels;var attack=SwitchwardenState();var pendingPlan:SwitchwardenPlan?;var floor=FakeVisual();var visualPhases:[SwitchwardenState.Phase]=[]\n func syncVisual(){visualPhases.append(attack.phase)}\n'
protocols=(root/'Sparkforge/Nodes/ArenaBossNode.swift').read_text().replace('import SpriteKit','import Foundation\nimport CoreGraphics').replace('extension BossNode: ArenaBossNode {}','')
with tempfile.TemporaryDirectory(prefix='sf-toll-') as temp:
 build=Path(temp)
 (build/'BossProtocol.swift').write_text(protocols)
 (build/'Seams.swift').write_text('import Foundation\nimport CoreGraphics\nclass EnemyNode:EnemyStorage {\n'+block(enemy,'    func chase(target:')+'\n}\n'+node_head+'\n'.join(node_methods)+'\n}\n'+rail_head+'\n'.join(rail_methods)+'\n}\n'+warden_head+'\n'.join(warden_methods)+'\n}\nextension GameScene {\n'+'\n'.join(scene_methods)+'\n}\n')
 subprocess.run(['sh',str(root/'tools/signature-draw-harness/extract-config.sh'),str(root/'Sparkforge/Config/GameConfig.swift'),str(build/'Config.swift'),'Arena','Geometry','Enemy','Tollkeeper','TwinChannels','Railspike','RangedEnemy','Switchwarden','Player','Marchwarden'],check=True)
 shutil.copy2(Path(sys.argv[1]) if len(sys.argv)>1 else root/'tools/tollkeeper-harness/main.swift',build/'main.swift')
 sources=[build/'main.swift',build/'BossProtocol.swift',root/'Sparkforge/Systems/SwitchwardenState.swift',root/'Sparkforge/Systems/VulnerabilityChannels.swift',root/'tools/tollkeeper-harness/Stubs.swift',build/'Seams.swift',build/'Config.swift',root/'Sparkforge/Config/ArenaGeometry.swift',root/'Sparkforge/Systems/TollkeeperState.swift',root/'Sparkforge/Systems/RailspikeState.swift',root/'Sparkforge/Systems/ChannelAttackSchedule.swift',root/'Sparkforge/Systems/MeleeSector.swift',root/'Sparkforge/Utils/VectorMath.swift']
 subprocess.run(['swiftc','-D','DEBUG','-module-cache-path',os.environ.get('TOLL_MODULE_CACHE','/tmp/sf-toll-module-cache'),'-o',str(build/'probe'),*map(str,sources)],check=True)
 result=subprocess.run([str(build/'probe')]);raise SystemExit(result.returncode)
