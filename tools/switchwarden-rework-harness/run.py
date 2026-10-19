#!/usr/bin/env python3
"""Native SpriteKit node and real policy/config/geometry. No app, UI or saves."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[2]
here=Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='sf-switch-rework-') as temp:
 out=Path(temp)
 subprocess.run(['sh',str(root/'tools/signature-draw-harness/extract-config.sh'),str(root/'Sparkforge/Config/GameConfig.swift'),str(out/'Config.swift'),'Arena','Geometry','Wave','BossMode','Player','Marchwarden','Switchwarden','Tollkeeper','Railspike','RangedEnemy','Physics'],check=True)
 protocol=(root/'Sparkforge/Nodes/ArenaBossNode.swift').read_text().replace('extension BossNode: ArenaBossNode {}','')
 (out/'Protocol.swift').write_text(protocol)
 def block(text,marker):
  a=text.index(marker);b=text.index('{',a)+1;depth=1
  while depth:
   depth+=(text[b]=='{')-(text[b]=='}');b+=1
  return text[a:b].replace('private ','').replace('override func ','func ')
 scene=(root/'Sparkforge/Scenes/GameScene.swift').read_text()
 contact=block(scene,'    private func handlePlayerEnemyContact(')
 contact=contact[:contact.index('        if consumeSilverSkin()')]+ '        contactDamageAttempts += 1\n    }'
 seams='import SpriteKit\nextension GameScene {\n'+contact+'\n'+block(scene,'    private func processSwitchwardenSurge()')+'\n'+block(scene,'    override func didFinishUpdate()')+'\n}\n'
 (out/'SceneSeams.swift').write_text(seams)
 sources=[here/'main.swift',here/'Stubs.swift',out/'Config.swift',out/'Protocol.swift',out/'SceneSeams.swift']+[root/p for p in ['Sparkforge/Config/ArenaConfig.swift','Sparkforge/Config/ArenaGeometry.swift','Sparkforge/Systems/SwitchwardenState.swift','Sparkforge/Nodes/SwitchwardenNode.swift','Sparkforge/Systems/ChannelAttackSchedule.swift','Sparkforge/Systems/TollkeeperState.swift','Sparkforge/Systems/MeleeSector.swift','Sparkforge/Systems/VulnerabilityChannels.swift','Sparkforge/Utils/VectorMath.swift','Sparkforge/Utils/ColorExtensions.swift']]
 subprocess.run(['swiftc','-D','DEBUG','-module-cache-path',os.environ.get('SWITCH_MODULE_CACHE','/tmp/sf-switch-rework-cache'),'-o',str(out/'probe'),*map(str,sources)],check=True)
 raise SystemExit(subprocess.run([str(out/'probe')]).returncode)
