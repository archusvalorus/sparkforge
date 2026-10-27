import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ value:Bool){if value{passed += 1;print("PASS \(name)")}else{failed += 1;print("FAIL \(name)")}}
let map=Arena8GameMap.sixRoom,rule=Arena8PandaDestination(map:.sixRoom)!
check("two-room excluded",Arena8PandaDestination(map:.twoRoom)==nil)
let points=map.rooms.map(\.center)+map.connections.map(\.center)+map.geometry.blockedFootprints.map(\.center)+map.rooms.flatMap{[CGPoint(x:$0.rect.minX,y:$0.rect.minY),CGPoint(x:$0.rect.maxX+60,y:$0.rect.maxY+30)]}
func verify(_ p:CGPoint){
 let destination=rule.destination(at:p)
 check("destination exists",destination != nil)
 if let d=destination {
  check("nominal20-clear floor",map.valid(d,radius:20))
  let stored=CGPoint(x:CGFloat(Float(d.x)),y:CGFloat(Float(d.y)))
  check("Float-stored destination20-clear",map.valid(stored,radius:20))
  if map.valid(p,radius:20) && map.valid(CGPoint(x:CGFloat(Float(p.x)),y:CGFloat(Float(p.y))),radius:20){check("safe requested destination exact",d==p)}
 }
}
for p in points{verify(p)}
for room in map.rooms {
 check("outer-room destinations not circle-clamped",rule.destination(at:room.center)==room.center)
 for x:CGFloat in [-70,-35,0,35,70]{for y:CGFloat in [-70,-35,0,35,70]{verify(room.center+CGPoint(x:x,y:y))}}
 for offset:CGFloat in [-0.0001,0,0.0001,0.3] {
  verify(CGPoint(x:room.rect.minX+20+offset,y:room.center.y+0.1234567))
  verify(CGPoint(x:room.rect.maxX-20-offset,y:room.center.y+0.1234567))
  verify(CGPoint(x:room.center.x+0.1234567,y:room.rect.minY+20+offset))
  verify(CGPoint(x:room.center.x+0.1234567,y:room.rect.maxY-20-offset))
 }
}
for corridor in map.connections {for x:CGFloat in [-75,-20,0,20,75]{for y:CGFloat in [-75,-20,0,20,75]{verify(corridor.center+CGPoint(x:x,y:y))}}}
// Independent seam check: repairing an unsafe ordinary destination must not
// cause repeated projection drift or introduce another random choice.
for room in map.rooms {
 let unsafe=CGPoint(x:room.rect.maxX+70,y:room.rect.maxY+70)
 if let repaired=rule.destination(at:unsafe) {
  check("repair is idempotent",rule.destination(at:repaired)==repaired)
 } else { check("repair is idempotent",false) }
}
for p in [CGPoint(x:CGFloat.nan,y:0),CGPoint(x:0,y:CGFloat.infinity)]{check("nonfinite rejected",rule.destination(at:p)==nil)}
print("RESULT \(passed) passed \(failed) failed")
if failed>0{exit(1)}
