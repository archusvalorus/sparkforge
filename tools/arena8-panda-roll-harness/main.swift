import Foundation
import CoreGraphics
final class Node {
 private var stored=CGPoint.zero
 var position:CGPoint {get{stored} set{stored=CGPoint(x:CGFloat(Float(newValue.x)),y:CGFloat(Float(newValue.y)))}}
 init(_ p:CGPoint){position=p}
}
enum Act {case roll,bamboo,samurai,avalanche}
struct Panda {let node:Node;let act:Act;var destination:CGPoint}
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL \(name)")}}
let map=Arena8GameMap.sixRoom,scene=RestScene();scene.debugRoomIntegration=map
for world in [map.world,CGRect(x:123,y:-480,width:720,height:310),CGRect(x:-40,y:70,width:100,height:400)] {
 let hx=world.width*0.95/2,hy=world.height*0.95/2,c=CGPoint(x:world.midX,y:world.midY)
 for i in -110...110 {for j in -110...110 {
  let x=hx*CGFloat(i)/100,y=hy*CGFloat(j)/100,p=c+CGPoint(x:x,y:y)
  let expected=abs(x)>hx || abs(y)>hy
  check("rect-grid",Arena8PandaRollBounds.outside(p,world:world,fraction:0.95)==expected)
 }}
 for p in [CGPoint(x:c.x-hx,y:c.y),CGPoint(x:c.x+hx,y:c.y),CGPoint(x:c.x,y:c.y-hy),CGPoint(x:c.x,y:c.y+hy),CGPoint(x:c.x+hx,y:c.y+hy)] {
  check("exact-edge-equality-inside",!Arena8PandaRollBounds.outside(p,world:world,fraction:0.95))
 }
 for sign:CGFloat in [-1,1] {
  let bx=c.x+sign*hx,by=c.y+sign*hy
  let outX=sign>0 ? bx.nextUp : bx.nextDown,insideX=sign>0 ? bx.nextDown : bx.nextUp
  let outY=sign>0 ? by.nextUp : by.nextDown,insideY=sign>0 ? by.nextDown : by.nextUp
  check("adjacent-x-out",Arena8PandaRollBounds.outside(CGPoint(x:outX,y:c.y),world:world,fraction:0.95))
  check("adjacent-x-in",!Arena8PandaRollBounds.outside(CGPoint(x:insideX,y:c.y),world:world,fraction:0.95))
  check("adjacent-y-out",Arena8PandaRollBounds.outside(CGPoint(x:c.x,y:outY),world:world,fraction:0.95))
  check("adjacent-y-in",!Arena8PandaRollBounds.outside(CGPoint(x:c.x,y:insideY),world:world,fraction:0.95))
 }
}
for room in map.rooms {
 for p in [room.center,CGPoint(x:room.rect.maxX-20,y:room.rect.minY+20),CGPoint(x:room.rect.minX+1,y:room.rect.maxY-1),CGPoint(x:room.rect.maxX+10,y:room.center.y+100)] {
  var v=Panda(node:Node(p),act:.roll,destination:map.player);let before=v.node.position
  check("rest-resolves",scene.preparePandaRollRest(&v));check("actual-Float-root-safe",map.valid(v.node.position,radius:20))
  if map.valid(before,radius:20){check("valid-actual-retained",v.node.position==before)}
  check("destination-kept",v.destination==map.player)
  let after=v.node.position;check("idempotent",scene.preparePandaRollRest(&v) && v.node.position==after)
 }
}
for corridor in map.connections {
 var v=Panda(node:Node(corridor.center),act:.roll,destination:map.player);let before=v.node.position
 check("corridor-rest-exact",scene.preparePandaRollRest(&v) && v.node.position==before)
}
for wall in map.geometry.blockedFootprints {
 if !Arena8PandaRollBounds.outside(wall.center,world:map.world,fraction:0.95){check("internal-wall-does-not-retire",!Arena8PandaRollBounds.outside(wall.center,world:map.world,fraction:0.95))}
}
for act in [Act.bamboo,.samurai,.avalanche] {
 var v=Panda(node:Node(CGPoint(x:9999,y:9999)),act:act,destination:.zero);let before=v.node.position
 check("other-acts-bypass",scene.preparePandaRollRest(&v) && v.node.position==before)
}
for mode in 0...1 {
 scene.debugRoomIntegration=mode==0 ? nil : .twoRoom
 var v=Panda(node:Node(CGPoint(x:9999,y:9999)),act:.roll,destination:.zero);let before=v.node.position
 check("circle-two-room-bypass",scene.preparePandaRollRest(&v) && v.node.position==before)
}
scene.debugRoomIntegration=map
for p in [CGPoint(x:CGFloat.nan,y:0),CGPoint(x:0,y:CGFloat.infinity)] {
 var v=Panda(node:Node(p),act:.roll,destination:.zero)
 check("nonfinite-rest-refused-host-only",!scene.preparePandaRollRest(&v))
 check("nonfinite-outside",Arena8PandaRollBounds.outside(p,world:map.world,fraction:0.95))
}
check("invalid-world-retires",Arena8PandaRollBounds.outside(.zero,world:.zero,fraction:0.95))
print("Panda roll checks: \(passed) passed / \(failed) failed")
exit(failed==0 ? 0 : 1)
