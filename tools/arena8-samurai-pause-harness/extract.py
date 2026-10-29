from pathlib import Path
import sys
node=Path(sys.argv[1]).read_text();scene=Path(sys.argv[2]).read_text()
def member(s,marker):
 a=s.index(marker);i=s.index('{',a)+1;depth=1
 while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[a:i]
a=node.index('    // G22:');b=node.index('    // MARK: - Movement',a)
methods=node[a:b]+member(node,'    func strike(')
methods=methods.replace('private ','')
parts=[member(scene,'    enum GameState {'),member(scene,'    private(set) var gameState:'), 'var samuraiBackgroundHold=false',member(scene,'    private func syncSamuraiStrike('),member(scene,'    private func syncSamuraiStrikes('),member(scene,'    private func cancelSamuraiStrikes('),member(scene,'    @objc private func appDidEnterBackground('),member(scene,'    @objc private func appWillEnterForeground(')]
parts=[x.replace('private(set) ','').replace('@objc ','').replace('private ','') for x in parts]
out='''import Foundation
// Actual lifecycle code extracted below. Explicit host boundary substitutes
// only SpriteKit action scheduling, node pause inheritance and render poses.
final class PandaNode:SKNode {
 var currentClip="idle"
 var sprite:SKNode?
 var strikeFrames:[Int]=[]
 func playIdle(){currentClip="idle"}
'''+methods+'''\n}
final class GameScene:SKNode {
 enum Act {case samurai,other}
 struct Panda {let node:PandaNode;let act:Act}
 var pandas:[Panda]=[]
'''+ '\n'.join(parts)+'''\n func attach(_ n:PandaNode,act:Act = .samurai){addChild(n);pandas.append(Panda(node:n,act:act))}
}
'''
Path(sys.argv[3]).write_text(out)
