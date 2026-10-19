#!/usr/bin/env python3
"""Compile actual title/primary/scroll members; no app, simulator or window launch."""
from pathlib import Path
import subprocess,tempfile,sys,os
root=Path(__file__).resolve().parents[2]
def member(s,marker):
 assert s.count(marker)==1,(marker,s.count(marker))
 a=s.index(marker);b=s.index('{',a);i=b+1;depth=1
 while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[a:i].replace('private ','',1)
scene=(root/'Sparkforge/Scenes/TitleScene.swift').read_text()
methods=[member(scene,m) for m in ['    private func setupTitle()', '    private var playButtonSize:', '    private func setupTapPrompt()', '    private func buildMenuScrollSet(', '    private func clampedMenuOffset(', '    private func applyMenuScroll()']]
a=scene.index('        if let ignite = childNode(withName: "ignitePromptBox") {');hit=member(scene,'        if let ignite = childNode(withName: "ignitePromptBox") {')
methods.append('func tapPlay(at location:CGPoint) {\n'+hit+'\n}')
# The actual lifecycle entry supplies this cursor and ordering.
assert scene.count('        setupTapPrompt()')==1
assert scene.index('        setupTitle()')<scene.index('        setupTapPrompt()')<scene.index('        setupForgeLevel()')
with tempfile.TemporaryDirectory(prefix='sf-menu-cta-') as temp:
 out=Path(temp);shell=(root/'tools/menu-cta-harness/Stubs.swift').read_text().replace('    // SCENE_MEMBERS','\n'.join(methods));(out/'Seams.swift').write_text(shell)
 binary=out/'probe'
 subprocess.run(['swiftc','-O','-module-cache-path','/tmp/sf-menu-cta-cache','-o',str(binary),str(out/'Seams.swift'),str(root/'Sparkforge/Utils/ColorExtensions.swift'),str(root/'tools/menu-cta-harness/main.swift')],check=True)
 raise SystemExit(subprocess.run([str(binary),*sys.argv[1:]]).returncode)
