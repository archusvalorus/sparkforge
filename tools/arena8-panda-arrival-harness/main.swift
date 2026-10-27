import Foundation
import CoreGraphics
// Only host boundaries are stubbed. The method under test is extracted from
// the actual GameScene, then calls the real map and existing20-clear resolver.
final class Node {
 private var stored=CGPoint.zero
 var position:CGPoint {
  get{stored}
  set{stored=CGPoint(x:CGFloat(Float(newValue.x)),y:CGFloat(Float(newValue.y)))}
 }
 init(_ p:CGPoint){position=p}
}
enum Act {case bamboo,samurai}
struct Panda {let node:Node;let act:Act;var destination:CGPoint}
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes{passed += 1;print("PASS \(name)")}else{failed += 1;print("FAIL \(name)")}}
let map=Arena8GameMap.sixRoom,scene=HandoffScene();scene.debugRoomIntegration=map
for scale:CGFloat in [1,1.5,2,3] {
 for room in map.rooms {
  let goals=[(CGPoint(x:room.rect.minX+20,y:room.rect.maxY-60),CGPoint(x:-2*scale,y:0)),
             (CGPoint(x:room.rect.maxX-20,y:room.rect.maxY-60),CGPoint(x:2*scale,y:0)),
             (CGPoint(x:room.rect.maxX-60,y:room.rect.minY+20),CGPoint(x:0,y:-2*scale)),
             (CGPoint(x:room.rect.maxX-60,y:room.rect.maxY-20),CGPoint(x:0,y:2*scale)),
             (CGPoint(x:room.rect.maxX-20,y:room.rect.maxY-20),CGPoint(x:scale,y:scale))]
  for (goal,offset) in goals {
   var panda=Panda(node:Node(goal+offset),act:.bamboo,destination:goal)
   let before=panda.node.position
   check("unsafe actual within original stopping tolerance",before.distance(to:goal)<4*scale && !map.valid(before,radius:20))
   check("ordinary handoff succeeds",scene.preparePandaArrival(&panda))
   check("actual stored root20-clear",map.valid(panda.node.position,radius:20))
   check("destination not mutated",panda.destination==goal)
   check("repair no farther than known safe goal",panda.node.position.distance(to:before)<=goal.distance(to:before)+0.001)
   let settled=panda.node.position;check("second handoff exact idempotence",scene.preparePandaArrival(&panda) && panda.node.position==settled)
   var valid=Panda(node:Node(goal-CGPoint(x:offset.x,y:offset.y)),act:.bamboo,destination:goal)
   let actual=valid.node.position;check("valid ACTUAL differs from destination",actual != valid.destination && map.valid(actual,radius:20))
   check("valid actual retained instead of snapping goal",scene.preparePandaArrival(&valid) && valid.node.position==actual)
  }
 }
}
for connection in map.connections {
 var panda=Panda(node:Node(connection.center+CGPoint(x:1,y:0)),act:.bamboo,destination:connection.center)
 let before=panda.node.position;check("corridor valid actual retained",scene.preparePandaArrival(&panda) && panda.node.position==before)
}
for point in [CGPoint(x:CGFloat.nan,y:0),CGPoint(x:0,y:CGFloat.infinity)] {
 var panda=Panda(node:Node(point),act:.bamboo,destination:map.player)
 check("invalid actual rejects even with valid destination",!scene.preparePandaArrival(&panda))
}
var samurai=Panda(node:Node(CGPoint(x:map.world.maxX+10,y:0)),act:.samurai,destination:map.player)
let samuraiBefore=samurai.node.position;check("Samurai untouched",scene.preparePandaArrival(&samurai) && samurai.node.position==samuraiBefore)
for context:Arena8GameMap? in [nil,.twoRoom] {
 scene.debugRoomIntegration=context
 var panda=Panda(node:Node(CGPoint(x:10000,y:0)),act:.bamboo,destination:map.player);let before=panda.node.position
 check("circle/two-room untouched",scene.preparePandaArrival(&panda) && panda.node.position==before)
}
print("RESULT \(passed) passed \(failed) failed")
if failed>0{exit(1)}
