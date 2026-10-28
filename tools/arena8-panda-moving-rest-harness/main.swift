import Foundation
import CoreGraphics
// The actual rest method is extracted; only the host node/act boundary is stubbed.
final class Node {
 private var stored=CGPoint.zero
 var position:CGPoint {get{stored} set{stored=CGPoint(x:CGFloat(Float(newValue.x)),y:CGFloat(Float(newValue.y)))}}
 init(_ p:CGPoint){position=p}
}
enum Act {case bodyCheck,follow,pin,roll,samurai,bamboo,avalanche}
struct Panda {let node:Node;let act:Act;var destination:CGPoint}
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL \(name)")}}
let map=Arena8GameMap.sixRoom,scene=MovingRestScene();scene.debugRoomIntegration=map
for act in [Act.bodyCheck,.follow,.pin] {
 for room in map.rooms {
  for p in [room.center,CGPoint(x:room.rect.minX+20,y:room.rect.maxY-20),CGPoint(x:room.rect.maxX-1,y:room.rect.maxY-1),CGPoint(x:room.rect.maxX+12,y:room.center.y+100)] {
   var v=Panda(node:Node(p),act:act,destination:map.player);let before=v.node.position
   check("terminal-rest-succeeds",scene.preparePandaMovingRest(&v))
   check("Float-stored-actual-root-safe",map.valid(v.node.position,radius:20))
   check("destination-not-substituted",v.destination==map.player)
   if map.valid(before,radius:20){check("valid-actual-retained-exactly",v.node.position==before)}
   let after=v.node.position;check("idempotent",scene.preparePandaMovingRest(&v) && v.node.position==after)
  }
 }
 for corridor in map.connections {
  var v=Panda(node:Node(corridor.center),act:act,destination:map.player);let before=v.node.position
  check("corridor-actual-retained",scene.preparePandaMovingRest(&v) && v.node.position==before)
 }
 for p in [CGPoint(x:CGFloat.nan,y:0),CGPoint(x:0,y:CGFloat.infinity)] {
  var v=Panda(node:Node(p),act:act,destination:.zero)
  check("nonfinite-host-refused",!scene.preparePandaMovingRest(&v))
 }
}
for act in [Act.roll,.samurai,.bamboo,.avalanche] {
 var v=Panda(node:Node(CGPoint(x:9999,y:9999)),act:act,destination:.zero);let before=v.node.position
 check("unsupported-act-bypass",scene.preparePandaMovingRest(&v) && v.node.position==before)
}
for mode in 0...1 {
 scene.debugRoomIntegration=mode==0 ? nil : .twoRoom
 for act in [Act.bodyCheck,.follow,.pin] {
  var v=Panda(node:Node(CGPoint(x:9999,y:9999)),act:act,destination:.zero);let before=v.node.position
  check("circle-two-room-bypass",scene.preparePandaMovingRest(&v) && v.node.position==before)
 }
}
print("Panda moving-rest checks: \(passed) passed / \(failed) failed")
exit(failed==0 ? 0 : 1)
