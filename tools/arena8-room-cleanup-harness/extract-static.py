from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text()
def member(marker):
 a=source.index(marker);b=source.index('{',a);i=b+1;d=1
 while d:d+=(source[i]=='{')-(source[i]=='}');i+=1
 return source[a:i].replace('private func','func',1)
a=source.index('        // And the arena is left with pandas');b=source.index('\n    }',source.index('        for _ in 0..<GameConfig.Panda.afterKaijuPandas',a));witness=source[a:b]
witness=witness.replace('CGFloat.random(in: 40...70)','TestRandom.distance()').replace('Bool.random()','TestRandom.facing()')
head='''import Foundation
import CoreGraphics
enum TestRandom {
 static var nextDistance:CGFloat=40;static var nextFacing=true;static var draws=0
 static func distance()->CGFloat{draws+=1;return nextDistance}
 static func facing()->Bool{draws+=1;return nextFacing}
}
final class SKAction {
 var callback:(()->Void)?;var children:[SKAction]=[]
 static func fadeIn(withDuration:Double)->SKAction{SKAction()}
 static func wait(forDuration:Double)->SKAction{SKAction()}
 static func run(_ b:@escaping()->Void)->SKAction{let a=SKAction();a.callback=b;return a}
 static func sequence(_ xs:[SKAction])->SKAction{let a=SKAction();a.children=xs;return a}
 func callbacks()->[()->Void]{(callback.map{[$0]} ?? [])+children.flatMap{$0.callbacks()}}
}
class SKNode {
 var position=CGPoint.zero {didSet{position=CGPoint(x:CGFloat(Float(position.x)),y:CGFloat(Float(position.y)))}}
 var zPosition:CGFloat=0;var alpha:CGFloat=1;var name:String?
 weak var parent:SKNode?;var children:[SKNode]=[];var actions:[SKAction]=[]
 func addChild(_ n:SKNode){children.append(n);n.parent=self}
 func run(_ action:SKAction){actions.append(action)}
 func removeFromParent(){parent?.children.removeAll{$0 === self};parent=nil}
}
final class PandaNode:SKNode {
 static var allocations=0;static let baseScale:CGFloat=GameConfig.Panda.bodyWidth/22
 var bodyScale:CGFloat=1;var rollStarts=0
 func startRolling(){rollStarts+=1}
 override init(){Self.allocations+=1;super.init()}
 func setBodyScale(_ s:CGFloat){bodyScale=s}
 func lookPleased(){};func sit(){};func bounce(){}
}
final class HealthOrbNode:SKNode{}
enum PandaAct {case pleased,roll}
enum PandaPhase {case lingering,acting}
struct Panda {
 let node:PandaNode;var act:PandaAct;var phase:PandaPhase;let timer:TimeInterval;let destination:CGPoint
 var leaving=false;var rollDir=CGPoint.zero
 var followMark:AnyObject?
}
final class TestView {weak var scene:GameScene?}
final class GameScene {
 var view:TestView?
 var debugRoomIntegration:Arena8GameMap? = .sixRoom
 let player=SKNode(),worldNode=SKNode()
 var pandas:[Panda]=[];var healthOrbs:[HealthOrbNode]=[];var spawnAttempts=0
 func spawnPanda(){spawnAttempts+=1}
'''
Path(sys.argv[2]).write_text(head+'\n'.join(member('    private func '+n+'(') for n in ['roomStationaryPandaRoot','spawnStackedPanda','dropBamboo','beginRoomAvalancheRoll','spawnAvalanchePanda'])+'\n func actualWitnessBlock(){\n'+witness+'\n }\n}\n')
