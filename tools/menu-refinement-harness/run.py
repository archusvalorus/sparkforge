#!/usr/bin/env python3
"""Native full home-stack construction and actual hit/scroll seams; no UI/saves/network."""
from pathlib import Path
import os,subprocess,tempfile,sys
root=Path(__file__).resolve().parents[2];here=Path(__file__).resolve().parent
def member(s,marker):
 assert s.count(marker)==1,(marker,s.count(marker))
 a=s.index(marker);b=s.index('{',a)+1;depth=1
 while depth:depth+=(s[b]=='{')-(s[b]=='}');b+=1
 return s[a:b].replace('private ','',1)
scene=Path(os.environ.get('MENU_REFINEMENT_SCENE',str(root/'Sparkforge/Scenes/TitleScene.swift'))).read_text()
markers=['    private func setupForgeGlow()', '    private func setupTitle()', '    private func setupForgeLevel()', '    private func setupForgePathRow()', '    private func drawForgePathRow()', '    private func setupStats()', '    private func setupArenaProgress()', '    private func fitArenaRows()', '    private func refreshArenaSection()', '    private func setupDailyForge()', '    private var playButtonSize:', '    private func setupTapPrompt()', '    private func setupSettings()', '    private func removeAdsButtonText()', '    private func handleHomeTapUp(', '    private func buildMenuScrollSet(', '    private func clampedMenuOffset(', '    private func applyMenuScroll()']
for optional in ['    private var homeButtonWidth:', '    private var homeCenterX:', '    private func fitHomeLabel(', '    private func styleHomePlate(']:
 if optional in scene:markers.append(optional)
methods=[member(scene,m) for m in markers]
if '    private func fitHomeLabel(' not in scene:
 # Baseline compilation only: candidate-only assertions are disabled there.
 methods.append('func fitHomeLabel(_ label:SKLabelNode,maxWidth:CGFloat? = nil,maxHeight:CGFloat = 30) {}')
a=scene.index('    private let titleLabel');b=scene.index('    // MARK: - State',a)
nodes=scene[a:b].replace('private ','')
shell=(here/'Stubs.swift').read_text().replace('    // ACTUAL_NODES',nodes).replace('    // ACTUAL_MEMBERS','\n'.join(methods))
assert scene.index('        setupTitle()')<scene.index('        setupTapPrompt()')<scene.index('        setupForgeLevel()')
with tempfile.TemporaryDirectory(prefix='sf-menu-refine-') as temp:
 out=Path(temp);(out/'Seams.swift').write_text(shell)
 subprocess.run(['sh',str(root/'tools/signature-draw-harness/extract-config.sh'),str(root/'Sparkforge/Config/GameConfig.swift'),str(out/'Config.swift'),'Arena','Geometry','Wave','BossMode'],check=True)
 sources=[out/'Seams.swift',out/'Config.swift',here/'main.swift']+[root/p for p in ['Sparkforge/Config/UITheme.swift','Sparkforge/Config/ArenaConfig.swift','Sparkforge/Config/ArenaGeometry.swift','Sparkforge/Systems/MeleeSector.swift','Sparkforge/Utils/VectorMath.swift','Sparkforge/Utils/ColorExtensions.swift']]
 binary=out/'probe'
 subprocess.run(['swiftc','-O','-module-cache-path',os.environ.get('MENU_REFINEMENT_CACHE','/tmp/sf-menu-refinement-cache'),'-o',str(binary),*map(str,sources)],check=True)
 raise SystemExit(subprocess.run([str(binary),*sys.argv[1:]]).returncode)
