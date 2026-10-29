from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
def member(marker):
 a=s.index(marker);i=s.index('{',a)+1;d=1
 while d:d+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[a:i]
markers=['    private func spawnAvalanchePanda(', '    private final class AvalancheEntrance ', '    private func scheduleAvalancheEntrance(', '    private func finishAvalancheEntrance(', '    private func restoreAvalanchePause(', '    private func discardAvalancheEntrance(', '    private func syncAvalancheEntrances(', '    private func deliverAvalancheEntrance(', '    private func beginAvalancheRoll(', '    private func cancelAvalancheEntrances(']
parts=[member(x).replace('private ','') for x in markers]
# Exact production guard and timer decrement; later movement/contact is a host
# diagnostic, not an extracted damage implementation. Runtime owns full-loop proof.
a=s.index('            case .acting:',s.index('    private func updatePandas('));b=s.index('                let done = runPandaAct',a)
guard=s[a:b];guard=guard[guard.index('                // Entrance'):]
assert 'panda.timer -= dt' in guard
out='import Foundation\nimport CoreGraphics\nfinal class GameScene:SKNode {\n enum Act {case roll,other};enum Phase {case acting,lingering}\n struct Panda {let node:PandaNode;var act:Act;var phase:Phase;var timer:Double;var destination:CGPoint;var rollDir=CGPoint.zero;var leaving=false;var avalancheWaiting=false}\n var pandas:[Panda]=[];let worldNode=SKNode();var view:HostView?\n var gameState:GameState = .playing {didSet{syncAvalancheEntrances()}}\n var avalancheBackgroundHold=false\n var avalancheEntrances:[ObjectIdentifier:AvalancheEntrance]=[:]\n var hostCombatSteps=0\n init(active:Bool=true){super.init();addChild(worldNode);if active{view=HostView(self)}}\n func hostGuardTick(_ dt:Double){for i in pandas.indices.reversed(){var panda=pandas[i]\n'+guard+'\n hostCombatSteps+=1;pandas[i]=panda\n }}\n'+member('    enum GameState {')+'\n'+'\n'.join(parts)+'\n}\n'
Path(sys.argv[2]).write_text(out)
