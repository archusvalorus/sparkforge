import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL \(name)")}}
let map=Arena8GameMap.sixRoom
func stored(_ p:CGPoint)->CGPoint{CGPoint(x:CGFloat(Float(p.x)),y:CGFloat(Float(p.y)))}
guard let rule=Arena8PandaPickupPlacement(map:map) else{fatalError("authored six-room placement unavailable")}
var requested:[CGPoint]=map.rooms.map(\.center)+map.connections.map(\.center)
for room in map.rooms {
 for x:CGFloat in [-30,0,11.99999,12,12.00001,30] {
  for y:CGFloat in [-30,0,11.99999,12,12.00001,30] {
   requested.append(CGPoint(x:room.rect.minX+x,y:room.rect.minY+y))
   requested.append(CGPoint(x:room.rect.maxX-x,y:room.rect.maxY-y))
  }
 }
}
for wall in map.geometry.blockedFootprints{requested.append(wall.center)}
for p in requested {
 guard let q=rule.pickup(at:p) else{check("finite-request-produces-pickup",false);continue}
 check("resolved-center-12-clear",map.valid(q,radius:12))
 check("actual-Float-center-12-clear",map.valid(stored(q),radius:12))
 if map.valid(p,radius:12) && map.valid(stored(p),radius:12){check("valid-request-retained-exactly",q==p)}
 check("real-fall-then-generic-drop-idempotent",rule.pickup(at:q)==q)
 check("stored-fall-endpoint-then-orb-stable",rule.pickup(at:stored(q))==stored(q))
}
for p in [CGPoint(x:CGFloat.nan,y:0),CGPoint(x:0,y:CGFloat.infinity),CGPoint(x:-CGFloat.infinity,y:0)] {
 check("nonfinite-rejected-before-node",rule.pickup(at:p)==nil)
}
check("two-room-does-not-use-new-helper",Arena8PandaPickupPlacement(map:.twoRoom)==nil)
let callbacks=GameScene().testCallbacks();passed+=callbacks.0;failed+=callbacks.1
print("Panda pickup checks: \(passed) passed / \(failed) failed")
exit(failed==0 ? 0 : 1)
