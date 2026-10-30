import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL \(name)")}}
func dist(_ a:CGPoint,_ b:CGPoint)->CGFloat{hypot(a.x-b.x,a.y-b.y)}
func stored(_ p:CGPoint)->CGPoint{CGPoint(x:CGFloat(Float(p.x)),y:CGFloat(Float(p.y)))}
// Independent dense segment/body oracle over the authored wall boxes.
func oracle(_ map:Arena8GameMap,_ p:CGPoint,_ q:CGPoint,_ r:CGFloat)->Bool{
 let length=dist(p,q), n=max(1,Int(ceil(length/0.25)))
 for k in 0...n {
  let t=CGFloat(k)/CGFloat(n),v=CGPoint(x:p.x+(q.x-p.x)*t,y:p.y+(q.y-p.y)*t)
  if v.x-r < map.world.minX || v.x+r > map.world.maxX || v.y-r < map.world.minY || v.y+r > map.world.maxY{return false}
  for wall in map.geometry.blockedFootprints {
   let dx=max(abs(v.x-wall.center.x)-wall.halfExtents.width,0)
   let dy=max(abs(v.y-wall.center.y)-wall.halfExtents.height,0)
   if hypot(dx,dy) < r-1e-5{return false}
  }
 }
 return true
}
for scale:CGFloat in [1,1.25,1.7777777] {
 DeviceScale.gameplay=scale;DeviceScale.arenaRadius=350;ArenaConfig.current=ArenaConfig(radiusScale:1)
 let map=Arena8GameMap.sixRoom, fear=Arena8RoomFear(map:map)
 let positions=map.rooms.flatMap { room in
  [room.center,CGPoint(x:room.rect.minX+28,y:room.rect.minY+28),CGPoint(x:room.rect.maxX-28,y:room.rect.maxY-28)]
 }+map.connections.map(\.center)
 for radius:CGFloat in [8,16,24] {
  for raw in positions {
   let p=stored(raw);guard map.valid(p,radius:radius) else {continue}
   for degrees in stride(from:0,through:315,by:45) {
    let a=CGFloat(degrees)*CGFloat.pi/180,spark=CGPoint(x:p.x-cos(a)*75,y:p.y-sin(a)*75)
    let goal=fear.goal(from:p,spark:spark,lookahead:150,radius:radius)
    if let g=goal {check("goal-clear",oracle(map,p,g,radius));check("goal-away",FleeRule.keepsAway(from:p,toward:g,spark:spark));check("goal-length",dist(p,g)<=150+1e-6)}
    for slow:CGFloat in [-0.2,0,0.4,0.8,1.2] {
     let speed:CGFloat=83,dt:Double=0.1,maxLength=speed*(1-min(max(slow,0),0.8))*CGFloat(dt)
     for target in [goal,Optional(spark),Optional(CGPoint(x:-p.x,y:-p.y)),nil] {
      let q=fear.step(from:p,spark:spark,preferred:target,moveSpeed:speed,slow:slow,dt:dt,radius:radius)
      check("actual-Float-stored",q==stored(q));check("step-body-clear",map.valid(q,radius:radius));check("step-swept-clear",oracle(map,p,q,radius));check("step-segment-away",FleeRule.keepsAway(from:p,toward:q,spark:spark));check("step-separation",dist(q,spark)>=dist(p,spark)-1e-6);check("speed-slow-cap",dist(p,q)<=maxLength+1e-6)
     }
    }
   }
  }
 }
 for room in map.rooms {
  let p=stored(room.center),spark=p+CGPoint(x:75,y:0)
  check("outer-room-free-moves",fear.step(from:p,spark:spark,preferred:nil,moveSpeed:80,slow:0,dt:0.1,radius:16) != p)
  if hypot(p.x,p.y)>350 {check("legacy-circle-held",FleeRule.fleeStep(from:p,spark:spark,preferred:nil,moveSpeed:80,slow:0,dt:0.1,arenaRadius:350,footprint:16,blocked:{_ in false})==p)}
  for slow:CGFloat in [0,0.4,1.2] {
   let actual=fear.step(from:p,spark:spark,preferred:nil,moveSpeed:80,slow:slow,dt:0.1,radius:16)
   let expected:CGFloat=80*(1-min(max(slow,0),0.8))*0.1
   check("free-interior-exact-speed",abs(dist(p,actual)-expected)<0.001)
  }
  check("zero-dt-holds",fear.step(from:p,spark:spark,preferred:nil,moveSpeed:80,slow:0,dt:0,radius:16)==p)
  check("negative-dt-holds",fear.step(from:p,spark:spark,preferred:nil,moveSpeed:80,slow:0,dt:-1,radius:16)==p)
  let coincident=fear.step(from:p,spark:p,preferred:nil,moveSpeed:80,slow:0,dt:0.1,radius:16)
  check("coincident-up",coincident.y>p.y && coincident.x==p.x)
 }
 let bad=CGPoint(x:map.world.maxX+100,y:0)
 check("invalid-root-holds",fear.step(from:bad,spark:.zero,preferred:nil,moveSpeed:80,slow:0,dt:0.1,radius:16)==bad)
 check("invalid-root-no-goal",fear.goal(from:bad,spark:.zero,lookahead:150,radius:16)==nil)
 check("two-room-not-adapted",Arena8RoomFear(map:.twoRoom).goal(from:.zero,spark:.zero,lookahead:100,radius:16)==nil)
}
// Actual extracted final resolver must retain a clear diagonal at a doorway.
DeviceScale.gameplay=1
let m=Arena8GameMap.sixRoom,f=Arena8RoomFear(map:m)
let corner=CGPoint(x:m.rooms[0].rect.maxX,y:m.connections[0].corridor.minY)
let p=corner+CGPoint(x:-10,y:10),spark=corner+CGPoint(x:-110,y:110),q=corner+CGPoint(x:-8,y:12)
check("review-fixture-clear",oracle(m,p,q,14))
check("review-fixture-away",FleeRule.keepsAway(from:p,toward:q,spark:spark))
let accepted=f.step(from:p,spark:spark,preferred:q,moveSpeed:80,slow:0,dt:0.1,radius:14)
check("preferred-kept",accepted==q)
let node=FearBody(p,14),resolver=ResolverProbe();resolver.debugRoomIntegration=m;resolver.enemies=[node];resolver.roomEnemyStarts=[ObjectIdentifier(node):p]
node.position=accepted;resolver.roomFearAccepted=[ObjectIdentifier(node):node.position];resolver.resolve()
check("final-resolver-keeps-certified",node.position==accepted)
check("final-resolver-keeps-away",FleeRule.keepsAway(from:p,toward:node.position,spark:spark))
resolver.roomFearAccepted.removeAll();node.position=q;resolver.resolve()
check("old-axis-fixture-moves-inward",!FleeRule.keepsAway(from:p,toward:node.position,spark:spark))
let changed=corner+CGPoint(x:-15,y:5)
node.position=changed;resolver.roomFearAccepted=[ObjectIdentifier(node):q];resolver.resolve()
check("later-force-not-bypassed",node.position==(m.move(from:p,toward:changed,radius:14) ?? p))
// Clear endpoints around a rounded doorway corner do not prove swept clearance.
let tunnelP=corner+CGPoint(x:-15,y:1),tunnelSpark=corner+CGPoint(x:-115,y:-99),tunnelQ=corner+CGPoint(x:-1,y:15)
check("tunnel-fixture-clear-endpoints",m.valid(tunnelP,radius:14) && m.valid(tunnelQ,radius:14))
check("tunnel-fixture-blocked-middle",!oracle(m,tunnelP,tunnelQ,14))
let tunnelActual=f.step(from:tunnelP,spark:tunnelSpark,preferred:tunnelQ,moveSpeed:300,slow:0,dt:0.1,radius:14)
check("tunnel-preferred-rejected",tunnelActual != tunnelQ)
check("tunnel-actual-segment-clear",oracle(m,tunnelP,tunnelActual,14))
print("G19 room fear: \(passed) passed, \(failed) failed")
exit(failed==0 ? 0:1)
