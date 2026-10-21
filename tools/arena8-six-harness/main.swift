import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ value:Bool){if value{passed+=1;print("PASS \(name)")}else{failed+=1;print("FAIL \(name)")}}
let map=Arena8GameMap.sixRoom
check("six authored rooms seven open connections two loops",map.rooms.count==6 && map.connections.count==7 && map.world==CGRect(x:-700,y:-460,width:1400,height:920))
check("safe start and all room centers",map.player==CGPoint(x:-520,y:280) && map.rooms.allSatisfy{map.valid($0.center,radius:40)})
var exact=true
for x in stride(from:-695.0,through:695,by:10){for y in stride(from:-455.0,through:455,by:10){let p=CGPoint(x:x,y:y);let open=(map.rooms.map(\.rect)+map.connections.map(\.corridor)).contains{$0.contains(p)};exact = exact && (map.valid(p,radius:0)==open)}}
check("sampled wall complement matches authored union",exact)
for (index,c) in map.connections.enumerated(){
 let a=map.rooms[c.from].center,b=map.rooms[c.to].center
 let d=(b-a).normalized, perpendicular=CGPoint(x:-d.y,y:d.x)
 for r:CGFloat in [10,14,26,40,58]{
  check("door \(index) r\(r) both directions",map.move(from:a,toward:b,radius:r)==b && map.move(from:b,toward:a,radius:r)==a)
  let inside=perpendicular*(60-r-0.5),outside=perpendicular*(60-r+0.5)
  check("door \(index) r\(r) jamb clearance",map.move(from:a+inside,toward:b+inside,radius:r)==b+inside && map.move(from:a+outside,toward:b+outside,radius:r) != b+outside)
  let wallStart=a+perpendicular*120
  let wallStop=map.move(from:wallStart,toward:b+perpendicular*120,radius:r)
  check("door \(index) r\(r) wall slide and reverse",wallStop.map{p in map.valid(p,radius:r) && map.move(from:p,toward:p-d*20,radius:r)==p-d*20 && map.move(from:p,toward:p-perpendicular*10,radius:r)==p-perpendicular*10} == true)
 }
 check("door \(index) too wide rejected",map.move(from:a,toward:b,radius:61) != b && map.geometry.graphWaypoint(from:a,toward:b,travelRadius:61,arriveRadius:5)==nil)
 let from=a+perpendicular*160,to=b-perpendicular*160
 let forced=map.shove(from:from,toward:to,radius:14)
 check("door \(index) straight force stops on chord",forced.map{p in let u=p-from,v=to-from;return map.valid(p,radius:14) && p != to && abs(u.x*v.y-u.y*v.x)<0.01} == true)
}
for r:CGFloat in [14,26,40]{for a in map.rooms{for b in map.rooms where a.id != b.id{
 var p=a.center, safe=true,steps=0
 for _ in 0..<1800 {
  if p.distance(to:b.center)<0.1{break}
  let blocked = map.geometry.segmentBlockedExact(p,b.center,travelRadius:r)
  guard let aim = blocked ? map.geometry.graphWaypoint(from:p,toward:b.center,travelRadius:r,arriveRadius:5)?.position : b.center as CGPoint? else{safe=false;break}
  let delta=aim-p, distance=min(CGFloat(8),delta.length)
  guard let next=map.move(from:p,toward:p+delta.normalized*distance,radius:r) else{safe=false;break}
  safe = safe && map.valid(next,radius:r);p=next;steps+=1
 }
 check("route \(a.id) to \(b.id) r\(r)",safe && p.distance(to:b.center)<0.1 && steps<1800)
}}}
for room in map.rooms{
 let local=map.neighborhood(near:room.center)
 check("room \(room.id) spawn neighborhood",Set(map.spawnCandidates(near:room.center).map{map.roomID(near:$0)})==Set(local))
 let spawned=map.spawn(candidates:map.spawnCandidates(near:room.center),radius:40,avoiding:room.center,clearance:160)
 check("room \(room.id) safe spawn and clearance",spawned.map{map.valid($0,radius:40) && $0.distance(to:room.center)>=200} == true)
 check("room \(room.id) local pickups",map.pickupCandidates(near:room.center).allSatisfy{map.roomID(near:$0)==room.id && map.valid($0,radius:14)})
}
check("no unsafe fallback",map.spawn(candidates:[CGPoint(x:900,y:900),CGPoint(x:260,y:0)],radius:40,avoiding:map.player,clearance:160)==nil)
check("invalid movement refused",map.move(from:CGPoint(x:CGFloat.nan,y:0),toward:map.player,radius:14)==nil && map.move(from:map.player,toward:.zero,radius:-1)==nil)
let old=Arena8P0Model(),control=Arena8GameMap.twoRoom
var identical=true
for r:CGFloat in [14,26,40,70]{for a in [CGPoint(x:-280,y:150),CGPoint(x:280,y:0)]{for b in [CGPoint(x:280,y:150),CGPoint(x:-900,y:-900),CGPoint.zero]{identical = identical && control.move(from:a,toward:b,radius:r)==old.move(from:a,toward:b,radius:r) && control.shove(from:a,toward:b,radius:r)==old.shove(from:a,toward:b,radius:r)}}}
check("committed two-room control exact delegation",identical && control.geometry.blockedFootprints.count==old.geometry.blockedFootprints.count)
print("RESULT \(passed) passed \(failed) failed");exit(failed==0 ? 0:1)
