import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ yes:Bool) { if yes { passed += 1;print("PASS \(name)") } else {failed += 1;print("FAIL \(name)")} }
let map=Arena8GameMap.sixRoom
guard let rules=Arena8PandaEndpoints(map:map) else { fatalError("Missing six-room endpoint adapter") }
check("two-room excluded",Arena8PandaEndpoints(map:.twoRoom)==nil)
let desired = map.rooms.map(\.center) + map.connections.map(\.center)
    + map.geometry.blockedFootprints.map(\.center)
    + [CGPoint(x:map.world.maxX+300,y:map.world.maxY+300),CGPoint(x:map.world.minX-300,y:map.world.minY-300)]
for radius:CGFloat in [8,18,28,44] {
 for room in map.rooms {
  let previous=room.center
  for (i,p) in desired.enumerated() {
   let end=rules.resolved(from:previous,toward:p,radius:radius)
   check("room\(room.id) r\(radius) endpoint\(i) body clear",end.map{map.valid($0,radius:radius)}==true)
   if map.valid(p,radius:radius) {check("valid endpoint retained exactly",end==p)}
  }
  for x:CGFloat in [.nan,.infinity,-.infinity] {
   check("invalid desire retains verified previous",rules.resolved(from:previous,toward:CGPoint(x:x,y:0),radius:radius)==previous)
  }
 }
}
for (i,connection) in map.connections.enumerated() {
 let previous=connection.center
 for dx:CGFloat in [-120,-40,0,40,120] {for dy:CGFloat in [-120,-40,0,40,120] {
  let p=previous+CGPoint(x:dx,y:dy)
  check("door\(i) displacement \(dx)/\(dy) safe",rules.resolved(from:previous,toward:p,radius:18).map{map.valid($0,radius:18)}==true)
 }}
}
let previous=map.rooms[0].center
let across=map.rooms[4].center
check("cross-wall segment is blocked",map.geometry.segmentBlockedExact(previous,across))
check("Panda cross-wall valid destination remains exact",rules.resolved(from:previous,toward:across,radius:18)==across)
for radius:CGFloat in [0,-1,.nan,.infinity] {check("invalid grounded radius refuses",rules.resolved(from:previous,toward:previous,radius:radius)==nil)}
for start in [CGPoint(x:CGFloat.nan,y:0),CGPoint(x:map.world.maxX+10,y:0),map.geometry.blockedFootprints[0].center] {
 check("invalid prior not certified",rules.resolved(from:start,toward:previous,radius:18)==nil)
}
print("RESULT \(passed) passed \(failed) failed")
exit(failed==0 ? 0:1)
