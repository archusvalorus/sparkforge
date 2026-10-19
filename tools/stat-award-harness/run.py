#!/usr/bin/env python3
"""Execute real stat awards and scene/UI members with shipped config, no app/UI launch.
Card acquisition is inert so this probe isolates stat awards from card effects.
"""
from pathlib import Path
import subprocess,tempfile,os
root=Path(__file__).resolve().parents[2]
def member(s,marker):
 assert s.count(marker)==1,(marker,s.count(marker))
 a=s.index(marker);b=s.index('{',a);i=b+1;depth=1
 while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[a:i].replace('private ','',1)
with tempfile.TemporaryDirectory(prefix='sf-stat-awards-') as temp:
 out=Path(temp)
 stubs=(root/'tools/signature-draw-harness/Stubs.swift').read_text()
 for name in ['Player','LevelUp']:
  block=member(stubs,'    enum '+name+' {');stubs=stubs.replace(block,'')
 stubs=stubs[:stubs.index('enum UpgradeCardNode {')]
 (out/'BaseStubs.swift').write_text(stubs)
 scene=(root/'Sparkforge/Scenes/GameScene.swift').read_text()
 markers=['    private func tryCommitLevelUp()', '    private func triggerLevelUp()', '    private func runRandomOpener(', '    private func presentStatRow(', '    private static func statCard(']
 methods='\n'.join(member(scene,m) for m in markers)
 lines=[l.replace('private ','',1) for l in scene.splitlines() if l.startswith('    static let statCardSize') or l.startswith('    private let statRowY:')]
 shell=(root/'tools/stat-award-harness/Stubs.swift').read_text().replace('    // SCENE_MEMBERS', '\n'.join(lines)+'\n'+methods)
 (out/'SceneSeams.swift').write_text(shell)
 subprocess.run(['sh',str(root/'tools/signature-draw-harness/extract-config.sh'),str(root/'Sparkforge/Config/GameConfig.swift'),str(out/'Config.swift'),'Player','LevelUp','Guard','VoidTree','Drafting','Panda','Growth','Chill','BossClass','Erasure','Shock','Neutral'],check=True)
 paths=['Sparkforge/Systems/PlayerStats.swift','Sparkforge/Systems/PlayerDamagePipeline.swift','Sparkforge/Systems/GuardState.swift','Sparkforge/Systems/VoidState.swift','Sparkforge/Systems/GameTimer.swift','Sparkforge/Systems/UpgradeManager.swift','Sparkforge/Systems/AbilityCatalog.swift','Sparkforge/Systems/AbilityBehaviors.swift','Sparkforge/Nodes/HPBarNode.swift','Sparkforge/Nodes/StatHUDNode.swift','Sparkforge/Systems/BarrierTellState.swift','Sparkforge/Utils/ColorExtensions.swift','tools/stat-award-harness/main.swift']
 subprocess.run(['swiftc','-O','-DDEBUG','-module-cache-path','/tmp/sf-stat-award-cache','-o',str(out/'probe'),str(out/'BaseStubs.swift'),str(out/'Config.swift'),str(out/'SceneSeams.swift'),*[str(root/p) for p in paths]],check=True)
 raise SystemExit(subprocess.run([str(out/'probe')]).returncode)
