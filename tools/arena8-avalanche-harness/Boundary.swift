import Foundation
import CoreGraphics
// Explicit host boundary: action clock, fade interpolation, own/ancestor pause,
// graph membership and render-start diagnostic. Real SpriteKit evidence is separate.
final class SKAction {
 enum Kind {case wait,run,sequence,fade,forever}
 let kind:Kind;let duration:Double;var remaining:Double;var children:[SKAction]=[];var index=0;var block:(()->Void)?;var initial:Double?
 init(_ k:Kind,_ d:Double=0){kind=k;duration=d;remaining=d}
 static func wait(forDuration d:Double)->SKAction{SKAction(.wait,d)}
 static func run(_ b:@escaping()->Void)->SKAction{let a=SKAction(.run);a.block=b;return a}
 static func fadeIn(withDuration d:Double)->SKAction{SKAction(.fade,d)}
 static func repeatForever(_ child:SKAction)->SKAction{assert(child.kind == .wait);return SKAction(.forever)}
 static func sequence(_ c:[SKAction])->SKAction{let a=SKAction(.sequence,c.reduce(0){$0+$1.duration});a.children=c;return a}
 var lastBlock:(()->Void)? {if kind == .run{return block};return children.reversed().compactMap{$0.lastBlock}.first}
 func advance(_ node:SKNode,_ dt:Double)->(Double,Bool){
 switch kind {
 case .forever:return(0,false)
 case .wait,.fade:
  if initial == nil {initial=node.alpha}
  let used=min(remaining,max(0,dt));remaining-=used
  if kind == .fade {node.alpha=remaining<=1e-10 ? 1 : initial!+(1-initial!)*(1-remaining/duration)}
  return remaining<=1e-10 ? (dt-used,true):(0,false)
 case .run:let saved=block;block=nil;saved?();return(dt,true)
 case .sequence:
  var rest=dt
  while index<children.count {let (unused,done)=children[index].advance(node,rest);if !done{return(0,false)};index+=1;rest=unused}
  return(rest,true)
 }
 }
}
class SKNode {
 var isPaused=false;var alpha=1.0;var position=CGPoint.zero
 weak var parent:SKNode?;var children:[SKNode]=[];var actions:[String:SKAction]=[:]
 func addChild(_ n:SKNode){n.removeFromParent();n.parent=self;children.append(n)}
 func removeFromParent(){parent?.children.removeAll{$0 === self};parent=nil}
 func run(_ a:SKAction,withKey k:String){actions[k]=a}
 func action(forKey k:String)->SKAction?{actions[k]}
 func removeAction(forKey k:String){actions.removeValue(forKey:k)}
 func removeAllActions(){actions.removeAll()}
 func tick(_ dt:Double){
  guard !isPaused else{return};let snapshot=actions
  for (key,action) in snapshot.sorted(by:{$0.key<$1.key}) {
   guard !isPaused,actions[key] === action else{continue}
   let (_,done)=action.advance(self,dt)
   if done && actions[key] === action {actions.removeValue(forKey:key)}
  }
  for n in Array(children) where n.parent === self {n.tick(dt)}
 }
}
final class PandaNode:SKNode {var rollStarts=0;func startRolling(){rollStarts+=1}}
final class HostView {weak var scene:GameScene?;init(_ s:GameScene){scene=s}}
enum GameConfig {enum Panda {static let maxPandas=6;static let lingerDuration=3.5}}
