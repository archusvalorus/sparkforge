import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes{passed += 1;print("PASS \(name)")}else{failed += 1;print("FAIL \(name)")}}
let map=Arena8GameMap.sixRoom
guard let placement=Arena8VoidWellPlacement(map:map) else {fatalError("missing six-room placement")}
check("two-room excluded",Arena8VoidWellPlacement(map:.twoRoom)==nil)
let radii:[CGFloat]=[GameConfig.VoidTree.gravityWellRadius,GameConfig.VoidTree.blackholeRadius*GameConfig.VoidTree.nullBloomRadiusFraction,GameConfig.VoidTree.blackholeRadius]
var corrections=0
let points=map.rooms.map(\.center)+map.connections.map(\.center)+map.geometry.blockedFootprints.map(\.center)
 + map.rooms.flatMap{[CGPoint(x:$0.rect.minX,y:$0.rect.minY),CGPoint(x:$0.rect.maxX,y:$0.rect.maxY)]}
 + [CGPoint(x:map.world.minX-300,y:map.world.minY-300),CGPoint(x:map.world.maxX+300,y:map.world.maxY+300)]
for scale:CGFloat in [1,1.5,2,1+(834.0/390.0-1)*0.7] {for rawRadius in radii {
 let radius=rawRadius*scale
 for (i,p) in points.enumerated() {
  let center=placement.center(at:p,wellRadius:radius)
  check("r\(radius)-p\(i) safe half-radius",center.map{map.valid($0,radius:radius*0.5)}==true)
  check("r\(radius)-p\(i) SpriteKit float position safe",center.map{map.valid(CGPoint(x:CGFloat(Float($0.x)),y:CGFloat(Float($0.y))),radius:radius*0.5)}==true)
  if let raw=Arena8GardenFootprint.placementRoot(in:map,toward:p,clearance:radius*0.5),
     !map.valid(CGPoint(x:CGFloat(Float(raw.x)),y:CGFloat(Float(raw.y))),radius:radius*0.5),let center {
    corrections += 1
    let step=max(CGFloat(Float(raw.x).ulp),CGFloat(Float(raw.y).ulp))
    check("representational correction bounded to neighboring floats",center.distance(to:raw)<=3*step)
    check("corrected position exactly Float representable",center.x==CGFloat(Float(center.x)) && center.y==CGFloat(Float(center.y)))
  }
  if map.valid(p,radius:radius*0.5){check("valid requested center exact",center==p)}
 }
 let boundary=CGPoint(x:map.rooms[2].center.x,y:map.world.maxY-radius*0.5)
 let storedBoundary=CGPoint(x:CGFloat(Float(boundary.x)),y:CGFloat(Float(boundary.y)))
 check("valid boundary stays safe after storage",placement.center(at:boundary,wellRadius:radius).map{map.valid(CGPoint(x:CGFloat(Float($0.x)),y:CGFloat(Float($0.y))),radius:radius*0.5)}==true)
 if map.valid(storedBoundary,radius:radius*0.5){check("representable valid boundary exact",placement.center(at:boundary,wellRadius:radius)==boundary)}
 for room in map.rooms {
  check("outer-room center never circle-clamped",placement.center(at:room.center,wellRadius:radius)==room.center)
  // A full-radius adapter would displace this valid half-radius birth.
  let edge=CGPoint(x:room.rect.midX,y:room.rect.maxY-radius*0.75)
  check("existing half-clearance not whole aura",placement.center(at:edge,wellRadius:radius)==edge)
 }
}}
for connection in map.connections {for dx:CGFloat in [-140,-60,0,60,140] {for dy:CGFloat in [-140,-60,0,60,140] {
 let p=connection.center+CGPoint(x:dx,y:dy)
 check("corridor corner/edge radius",placement.center(at:p,wellRadius:60).map{map.valid($0,radius:30)}==true)
}}}
check("fractional iPad correction cases actually exercised",corrections>0)
for p in [CGPoint(x:CGFloat.nan,y:0),CGPoint(x:0,y:CGFloat.infinity)] {check("nonfinite input refuses",placement.center(at:p,wellRadius:30)==nil)}
for radius:CGFloat in [0,-1,.nan,.infinity,10000] {check("invalid or unplaceable radius refuses",placement.center(at:map.player,wellRadius:radius)==nil)}
print("RESULT \(passed) passed \(failed) failed")
exit(failed==0 ? 0:1)
