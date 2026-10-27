import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ value:Bool){if value{passed += 1;print("PASS \(name)")}else{failed += 1;print("FAIL \(name)")}}
let map=Arena8GameMap.sixRoom,rule=Arena8RiftGeometry(map:.sixRoom)!
check("two-room excluded",Arena8RiftGeometry(map:.twoRoom)==nil)
let points=map.rooms.map(\.center)+map.connections.map(\.center)+map.geometry.blockedFootprints.map(\.center)+map.rooms.flatMap{[CGPoint(x:$0.rect.minX,y:$0.rect.minY),CGPoint(x:$0.rect.maxX+60,y:$0.rect.maxY+30)]}
let w=map.world,corners=[CGPoint(x:w.minX,y:w.minY),CGPoint(x:w.minX,y:w.maxY),CGPoint(x:w.maxX,y:w.minY),CGPoint(x:w.maxX,y:w.maxY)]
for p in points {
 let root=rule.origin(at:p)
 check("safe origin exists",root != nil)
 if let root {
  check("nominal16 clearance",map.valid(root,radius:16))
  check("actual Float root clearance",map.valid(CGPoint(x:CGFloat(Float(root.x)),y:CGFloat(Float(root.y))),radius:16))
  if map.valid(p,radius:16){check("valid origin exact",root==p)}
  for legacy:CGFloat in [1,100,770,2200] {
   let span=rule.visualSpan(from:root,legacySpan:legacy)!
   check("legacy drawing never shortened",span>=legacy)
   for a in 0..<24 {
    let angle=CGFloat(a)*2 * .pi/24,d=CGPoint(x:cos(angle),y:sin(angle))
    check("all floor projections visible",corners.allSatisfy{abs(($0.x-root.x)*d.x+($0.y-root.y)*d.y)<=span+0.000001})
   }
  }
 }
}
// Independent bounded-drawing check: coverage must use the specified maximum,
// not arbitrary oversized artwork that merely happens to reach every target.
for root in [map.rooms[0].center,map.connections[0].center,map.rooms[5].center] {
 let farthest=corners.map{$0.distance(to:root)}.max()!
 for legacy:CGFloat in [1,770,2200] {
  check("visual span equals exact bounded maximum",rule.visualSpan(from:root,legacySpan:legacy)==max(legacy,farthest))
 }
}
for p in [CGPoint(x:CGFloat.nan,y:0),CGPoint(x:0,y:CGFloat.infinity)] {
 check("invalid origin rejected",rule.origin(at:p)==nil)
 check("invalid visual root rejected",rule.visualSpan(from:p,legacySpan:770)==nil)
}
for span:CGFloat in [0,-1,.nan,.infinity]{check("invalid span rejected",rule.visualSpan(from:.zero,legacySpan:span)==nil)}
print("RESULT \(passed) passed \(failed) failed")
if failed>0{exit(1)}
