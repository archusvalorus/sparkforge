import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ value:Bool){if value{passed+=1;print("PASS \(name)")}else{failed+=1;print("FAIL \(name)")}}
let map=Arena8GameMap.sixRoom
for room in map.rooms {
 var safe=true,edge=true,which=Set<Int>()
 for i in 0...1000 {
  guard let p=map.echoOrigin(near:room.center,perimeterUnit:CGFloat(i)/1000) else {safe=false;continue}
  safe = safe && map.valid(p,radius:12)
  let d=p-room.center;edge = edge && abs(max(abs(d.x),abs(d.y))-153)<0.000001
  if abs(d.y+153)<0.000001 {which.insert(0)}
  if abs(d.x-153)<0.000001 {which.insert(1)}
  if abs(d.y-153)<0.000001 {which.insert(2)}
  if abs(d.x+153)<0.000001 {which.insert(3)}
 }
 check("room \(room.id) entire sampled perimeter valid and inset",safe && edge && which.count==4)
 let corners=[CGPoint(x:-153,y:-153),CGPoint(x:153,y:-153),CGPoint(x:153,y:153),CGPoint(x:-153,y:153),CGPoint(x:-153,y:-153)]
 for i in 0...4 {check("room \(room.id) corner \(i)",map.echoOrigin(near:room.center,perimeterUnit:CGFloat(i)/4)==room.center+corners[i])}
 // Equal intervals of unit perimeter distance yield equal physical wall distance.
 check("room \(room.id) uniform wall-length parameter",map.echoOrigin(near:room.center,perimeterUnit:0.125)==room.center+CGPoint(x:0,y:-153))
}
for c in map.connections {
 check("corridor tie \(c.from)-\(c.to)",map.roomID(near:c.center)==min(c.from,c.to) && map.echoOrigin(near:c.center,perimeterUnit:0)==map.rooms[min(c.from,c.to)].center+CGPoint(x:-153,y:-153))
 let d=(map.rooms[c.to].center-map.rooms[c.from].center).normalized
 check("corridor sides \(c.from)-\(c.to)",map.roomID(near:c.center-d*0.01)==c.from && map.roomID(near:c.center+d*0.01)==c.to)
}
for unit:CGFloat in [-1,-0.001,1.001,2,.nan,.infinity] {check("invalid unit \(unit)",map.echoOrigin(near:map.player,perimeterUnit:unit)==nil)}
for p in [CGPoint(x:CGFloat.nan,y:0),CGPoint(x:0,y:CGFloat.infinity)] {check("nonfinite Spark point",map.echoOrigin(near:p,perimeterUnit:0)==nil)}
let old=Arena8GameMap.twoRoom
check("two-room control excluded",old.echoOrigin(near:old.player,perimeterUnit:0)==nil)
print("RESULT \(passed) passed \(failed) failed");exit(failed==0 ? 0:1)
