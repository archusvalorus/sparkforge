from pathlib import Path
import subprocess,tempfile,shutil,os
root=Path(__file__).resolve().parents[2]
def block(text,marker):
 start=text.index(marker); brace=text.index('{',start); end=brace+1; depth=1
 while depth:
  depth+=(text[end]=='{')-(text[end]=='}');end+=1
 return text[start:end].replace('private ','')
scene=(root/'Sparkforge/Scenes/GameScene.swift').read_text();node=(root/'Sparkforge/Nodes/TollkeeperNode.swift').read_text();enemy=(root/'Sparkforge/Nodes/EnemyNode.swift').read_text()
scene_methods=[block(scene,x) for x in ['    private func twinChannelsSpawnPoint()', '    private func spawnTwinChannelsBody()', '    private func spawnTwinChannelsEnemy()', '    private func processTollkeeperPulses()']]
node_methods=[block(node,x) for x in ['    func cancelAttack()', '    func approachGoal(', '    override func chase(', '    func consumePulse(']]
node_head='class TollkeeperNode: EnemyNode {\n var attack=TollkeeperState()\n var pendingPlan:TollkeeperPlan?\n var attackVisual=FakeVisual()\n var onAimStart:(()->Void)?\n var attackRect:CGRect? { attack.attackRect }\n var syncCalls=0\n init() { super.init(health:1,moveSpeed:GameConfig.Enemy.baseSpeed,xpValue:3) }\n func syncAttackVisual() { syncCalls += 1 }\n'
with tempfile.TemporaryDirectory(prefix='sf-toll-') as temp:
 build=Path(temp)
 (build/'Seams.swift').write_text('import Foundation\nimport CoreGraphics\nclass EnemyNode:EnemyStorage {\n'+block(enemy,'    func chase(target:')+'\n}\n'+node_head+'\n'.join(node_methods)+'\n}\nextension GameScene {\n'+'\n'.join(scene_methods)+'\n}\n')
 subprocess.run(['sh',str(root/'tools/signature-draw-harness/extract-config.sh'),str(root/'Sparkforge/Config/GameConfig.swift'),str(build/'Config.swift'),'Arena','Geometry','Enemy','Tollkeeper','TwinChannels'],check=True)
 shutil.copy2(root/'tools/tollkeeper-harness/main.swift',build/'main.swift')
 sources=[build/'main.swift',root/'tools/tollkeeper-harness/Stubs.swift',build/'Seams.swift',build/'Config.swift',root/'Sparkforge/Config/ArenaGeometry.swift',root/'Sparkforge/Systems/TollkeeperState.swift',root/'Sparkforge/Systems/MeleeSector.swift',root/'Sparkforge/Utils/VectorMath.swift']
 subprocess.run(['swiftc','-D','DEBUG','-module-cache-path',os.environ.get('TOLL_MODULE_CACHE','/tmp/sf-toll-module-cache'),'-o',str(build/'probe'),*map(str,sources)],check=True)
 result=subprocess.run([str(build/'probe')]);raise SystemExit(result.returncode)
