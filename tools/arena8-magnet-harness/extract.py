from pathlib import Path
import sys
root=Path(sys.argv[1]);out=Path(sys.argv[2]);scene=Path(sys.argv[3]).read_text();node=(root/'Sparkforge/Nodes/XPOrbNode.swift').read_text()
def member(source,marker):
 assert source.count(marker)==1,marker
 a=source.index(marker);b=source.index('{',a);end=b+1;depth=1
 while depth:depth+=(source[end]=='{')-(source[end]=='}');end+=1
 return source[a:end].replace('private func','func',1)
constants='\n'.join(line for line in node.splitlines() if 'static let ' in line)
voidline=next(line for line in (root/'Sparkforge/Config/GameConfig.swift').read_text().splitlines() if 'static let devourXPMagnet:' in line)
text='''import Foundation
import CoreGraphics
extension GameConfig {enum VoidTree {VOID}}
final class SKPhysicsBody {weak var node:AnyObject?}
final class XPOrbNode {
CONSTANTS
var position=CGPoint.zero
let xpValue:Int
private(set) var isVacuuming=false
var collections=0
lazy var physicsBody:SKPhysicsBody={let b=SKPhysicsBody();b.node=self;return b}()
init(xpValue:Int=2){self.xpValue=xpValue}
func collect(){collections+=1}
UPDATE
VACUUM
}
final class FakePlayer {var position=CGPoint.zero;var xp=0;func addXP(_ n:Int)->Bool{xp+=n;return false}}
final class FakeStats {var effectivePickupRadius:CGFloat=80;var devourActive=false;var boosts=0;func triggerMagneticCoreBoost(){boosts+=1}}
final class AudioManager {static let shared=AudioManager();enum Sound{case orbPickup};func play(_ s:Sound){}}
enum PlayState {case playing,paused}
final class ActualScene {
var debugRoomIntegration:Arena8GameMap?
var xpOrbs:[XPOrbNode]=[]
let player=FakePlayer(),playerStats=FakeStats()
var gameState=PlayState.playing
func takeNextLevel(){}
XPUPDATE
COLLECT
}
'''.replace('CONSTANTS',constants).replace('VOID',voidline).replace('UPDATE',member(node,'    func updateMagnet('),1).replace('VACUUM',member(node,'    func startVacuum(')).replace('XPUPDATE',member(scene,'    private func updateXPOrbs(')).replace('COLLECT',member(scene,'    private func handleXPCollection('))
(out/'Actual.swift').write_text(text)
