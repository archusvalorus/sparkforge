from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text();node=Path(sys.argv[2]).read_text()
def member(source,marker):
 a=source.index(marker);b=source.index('{',a)+1;i=b;depth=1
 while depth:depth+=(source[i]=='{')-(source[i]=='}');i+=1
 return source[a:i].replace('private func','func',1).replace('private enum','enum',1).replace('private struct','struct',1)
head='''import Foundation
import CoreGraphics
// Host boundaries only. SKNode Float storage, callbacks and damage entry are
// explicit stubs; actual update/targeting/waddle/strike-closure bodies follow.
struct SKColor {init(hex:Int,alpha:CGFloat=1){};static let clear=SKColor(hex:0)}
final class SKAction {
 static func sequence(_ xs:[SKAction])->SKAction{SKAction()}
 static func group(_ xs:[SKAction])->SKAction{SKAction()}
 static func scaleX(to:CGFloat,duration:Double)->SKAction{SKAction()}
 static func fadeOut(withDuration:Double)->SKAction{SKAction()}
 static func removeFromParent()->SKAction{SKAction()}
}
class SKNode {
 private var root=CGPoint.zero
 var position:CGPoint{get{root}set{root=CGPoint(x:CGFloat(Float(newValue.x)),y:CGFloat(Float(newValue.y)))}}
 weak var parent:SKNode?;var children:[SKNode]=[];var zPosition:CGFloat=0
 var xScale:CGFloat=1;var zRotation:CGFloat=0
 func addChild(_ node:SKNode){children.append(node);node.parent=self}
 func removeFromParent(){parent?.children.removeAll{$0 === self};parent=nil}
 func removeAllActions(){};func run(_ a:SKAction){};func shake(intensity:CGFloat,duration:Double){}
}
final class SKShapeNode:SKNode {
 var fillColor=SKColor.clear,strokeColor=SKColor.clear;var glowWidth:CGFloat=0
 init(rectOf:CGSize){super.init()}
}
class EnemyNode:SKNode {
 var isDying=false,isMiniBoss=false;var health:Int;let maximum:Int
 var healthPercent:CGFloat{CGFloat(health)/CGFloat(maximum)}
 init(_ hp:Int){health=hp;maximum=hp;super.init()}
}
final class Boss:SKNode {
 var health=1000;var isDead:Bool{health<=0};var healthPercent:CGFloat{CGFloat(health)/1000}
 func takeDamage(_ n:Int){health=max(0,health-n)}
}
final class PandaNode:SKNode {
 var waddlePhase:CGFloat=0,bodyScale:CGFloat=1
 var bowCalls=0,strikeCalls=0,removedActions=0;var strikeRoot=CGPoint.zero
 var callback:(()->Void)?
 func playIdle(){};func playWalk(){}
 func bow(){bowCalls+=1}
 func strike(completion:@escaping()->Void){strikeCalls+=1;strikeRoot=position;callback=completion}
 func leave(completion:@escaping()->Void){}
 override func removeAllActions(){removedActions+=1;callback=nil}
'''
head+=member(node,'    func waddle(')+'\n}\n'
head+='''// The real resolver is compiled under RealDestination. This host wrapper
// injects explicit dependency failure without altering application source.
struct Arena8PandaDestination {
 static var rejectRequests=false
 let real:RealDestination
 init?(map:Arena8GameMap){guard let x=RealDestination(map:map)else{return nil};real=x}
 func destination(at p:CGPoint)->CGPoint?{Self.rejectRequests ? nil:real.destination(at:p)}
}
final class Stats {var pandaTier=5;var effectiveAttack:CGFloat=10}
final class GameScene {
 var debugRoomIntegration:Arena8GameMap? = .sixRoom
 var pandas:[Panda]=[],enemies:[EnemyNode]=[];var boss:Boss?
 let playerStats=Stats(),worldNode=SKNode()
 var pandaArrivalTimer:TimeInterval = -10000,spawnCalls=0,actStarts=0,actEnds=0
 var damageCalls:[Int]=[]
 var roomPandaArrivalHandoffs=0,roomPandaRollRests=0,roomPandaMovingRests=0
 var roomPandaArrivalLastHandoff:[String:Any]=[:],roomPandaRollLastRest:[String:Any]=[:],roomPandaMovingLastRest:[String:Any]=[:]
 func spawnPanda(){spawnCalls+=1}
 func runPandaAct(_ p:inout Panda,dt:TimeInterval)->Bool{false}
 func endPandaAct(_ p:inout Panda){actEnds+=1}
 func dealDirectDamage(_ n:Int,toEnemy e:EnemyNode,source:KillSource){damageCalls.append(n);e.health=max(0,e.health-n)}
'''
blocks=[member(s,'    private enum PandaAct'),member(s,'    private enum PandaPhase'),member(s,'    private struct Panda'),member(s,'    enum CombatTarget').replace('any ArenaBossNode','Boss')]
for name in ['updatePandas','preparePandaArrival','prepareSamuraiHandoff','preparePandaRollRest','preparePandaMovingRest','stillValid','findSamuraiTarget','resolveSamuraiStrike']:
 blocks.append(member(s,'    private func '+name+'('))
a=s.index('        case .samurai:',s.index('    private func beginPandaAct('));b=s.index('\n        }\n    }',a);actual=s[a+len('        case .samurai:'):b]
blocks.append('func beginPandaAct(_ panda:inout Panda){actStarts+=1;if panda.act == .samurai{'+actual+'\n}}')
Path(sys.argv[3]).write_text(head+'\n'.join(blocks)+'\n}\n')
