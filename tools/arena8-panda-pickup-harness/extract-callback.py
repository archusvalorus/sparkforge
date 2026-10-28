from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text()
def method(name):
 start=source.index('    private func '+name+'(');brace=source.index('{',start);depth=1;i=brace+1
 while depth:
  if source[i]=='{':depth+=1
  elif source[i]=='}':depth-=1
  i+=1
 return source[start:i]
head='''import Foundation
import CoreGraphics
final class SKColor {
 init(hex:Int,alpha:CGFloat=1){}
}
final class SKAction {
 enum Timing {case easeIn}
 var timingMode:Timing = .easeIn
 var callback:(()->Void)?
 var children:[SKAction]=[]
 static func move(to:CGPoint,duration:Double)->SKAction{SKAction()}
 static func run(_ block:@escaping()->Void)->SKAction{let a=SKAction();a.callback=block;return a}
 static func sequence(_ a:[SKAction])->SKAction{let s=SKAction();s.children=a;return s}
 static func group(_ a:[SKAction])->SKAction{sequence(a)}
 static func fadeOut(withDuration:Double)->SKAction{SKAction()}
 static func scaleY(to:CGFloat,duration:Double)->SKAction{SKAction()}
 static func removeFromParent()->SKAction{SKAction()}
 func callbacks()->[()->Void]{(callback.map{[$0]} ?? [])+children.flatMap{$0.callbacks()}}
}
class SKNode {
 var position:CGPoint = .zero {didSet {position=CGPoint(x:CGFloat(Float(position.x)),y:CGFloat(Float(position.y)))}}
 var name:String?;var zPosition:CGFloat=0;var zRotation:CGFloat=0
 weak var parent:SKNode?;var children:[SKNode]=[];var actions:[SKAction]=[]
 func addChild(_ child:SKNode){children.append(child);child.parent=self}
 func removeFromParent(){parent?.children.removeAll{$0 === self};parent=nil}
 func removeAllActions(){actions.removeAll()}
 func run(_ action:SKAction){actions.append(action)}
}
final class SKShapeNode:SKNode {
 var fillColor:SKColor?;var strokeColor:SKColor?;var lineWidth:CGFloat=0
 init(rectOf:CGSize,cornerRadius:CGFloat){super.init()}
}
final class HealthOrbNode:SKNode{}
final class TestView {weak var scene:GameScene?}
final class GameScene {
 var debugRoomIntegration:Arena8GameMap? = .sixRoom
 var roomPandaPickupGeneration:UInt64=0
 let worldNode=SKNode();var healthOrbs:[HealthOrbNode]=[]
 var view:TestView?
'''
tests='''
 func testCallbacks()->(Int,Int) {
  var passed=0,failed=0
  func check(_ name:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL callback: \\(name)")}}
  func clear(){cancelRoomPandaPickupFalls();healthOrbs.forEach{$0.removeFromParent()};healthOrbs.removeAll()}
  let map=Arena8GameMap.sixRoom,wall=CGPoint(x:Arena8GameMap.sixRoom.rooms[0].rect.maxX,y:Arena8GameMap.sixRoom.rooms[0].center.y+100)
  let holder=TestView();holder.scene=self;view=holder
  dropFallingBamboo(at:wall,isPickup:true)
  let callbacks=worldNode.children.last!.actions.flatMap{$0.callbacks()}
  check("actual-source-callback-captured",callbacks.count==1)
  callbacks.forEach{$0()}
  check("current-generation-live-scene-creates-one",healthOrbs.count==1 && map.valid(healthOrbs[0].position,radius:12))
  clear();dropFallingBamboo(at:wall,isPickup:true)
  let stale=worldNode.children.last!.actions.flatMap{$0.callbacks()};let old=roomPandaPickupGeneration
  cancelRoomPandaPickupFalls();check("generation-advances",roomPandaPickupGeneration==old+1)
  stale.forEach{$0()};check("forced-late-same-scene-callback-rejected",healthOrbs.isEmpty)
  dropFallingBamboo(at:wall,isPickup:true);let replaced=worldNode.children.last!.actions.flatMap{$0.callbacks()}
  let other=GameScene();holder.scene=other;replaced.forEach{$0()};check("same-generation-replaced-scene-rejected",healthOrbs.isEmpty)
  holder.scene=self;clear()
  let before=worldNode.children.count
  dropFallingBamboo(at:CGPoint(x:CGFloat.nan,y:0),isPickup:true)
  check("nonfinite-before-art-action-allocation",worldNode.children.count==before)
  dropBamboo(at:CGPoint(x:0,y:CGFloat.infinity));check("nonfinite-before-orb-allocation",healthOrbs.isEmpty)
  dropFallingBamboo(at:wall,isPickup:false);let decoration=worldNode.children.last!
  dropFallingBamboo(at:wall,isPickup:true);cancelRoomPandaPickupFalls()
  check("cosmetic-node-preserved",decoration.parent === worldNode && decoration.name==nil)
  decoration.actions.flatMap{$0.callbacks()}.forEach{$0()};check("cosmetic-no-pickup",healthOrbs.isEmpty)
  for room in map.rooms {
   holder.scene=self;clear();let request=CGPoint(x:room.rect.maxX,y:room.rect.maxY)
   dropFallingBamboo(at:request,isPickup:true);let node=worldNode.children.last!
   let target=Arena8PandaPickupPlacement(map:map)!.pickup(at:request)!
   node.actions.flatMap{$0.callbacks()}.forEach{$0()}
   check("actual-callback-captured-safe-target",healthOrbs.count==1 && healthOrbs[0].position==CGPoint(x:CGFloat(Float(target.x)),y:CGFloat(Float(target.y))))
  }
  return(passed,failed)
 }
}
'''
Path(sys.argv[2]).write_text(head+'\n'.join(method(n) for n in ['cancelRoomPandaPickupFalls','dropBamboo','dropFallingBamboo'])+tests)
