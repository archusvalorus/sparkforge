import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes {passed+=1}else{failed+=1;print("FAIL \(name)")}}
let map=Arena8GameMap.sixRoom,adapter=Arena8KaijuLunge(map:map)
for radius:CGFloat in [10,12.5,17.777777] {
 for room in map.rooms {
  for side in 0..<4 {
   let roots=[CGPoint(x:room.rect.minX+radius+0.5,y:room.rect.maxY-60),CGPoint(x:room.rect.maxX-radius-0.5,y:room.rect.maxY-60),CGPoint(x:room.rect.minX+60,y:room.rect.minY+radius+0.5),CGPoint(x:room.rect.minX+60,y:room.rect.maxY-radius-0.5)]
   let root=roots[side],from=CGPoint(x:CGFloat(Float(root.x)),y:CGFloat(Float(root.y)))
   check("valid fixture",map.valid(from,radius:radius))
   for i in 0..<32 {
    let angle=CGFloat(i)*CGFloat.pi/16,heading=CGPoint(x:cos(angle),y:sin(angle))
    for distance:CGFloat in [0.0001,4,4.8,8.8,100,600] {
     let q=adapter.step(from:from,toward:from+heading*distance,radius:radius)
     check("wall safe",map.valid(q,radius:radius))
     check("whole segment",!map.geometry.segmentBlockedExact(from,q,travelRadius:radius))
     check("Float exact",q==CGPoint(x:CGFloat(Float(q.x)),y:CGFloat(Float(q.y))))
     check("bounded displacement",q.distance(to:from)<=distance+0.001)
    }
   }
  }
 }
}
func player(_ root:CGPoint,constrained:Bool=true)->PlayerNode{
 let p=PlayerNode();p.position=root
 if constrained {p.debugKaijuLungeConstraint={a,b,r in adapter.step(from:a,toward:b,radius:r)}}
 return p
}
let heading=CGPoint(x:0.6,y:0.8)
let a=player(map.rooms[0].center),b=player(map.rooms[0].center,constrained:false)
a.strike(heading);b.strike(heading)
check("duration",abs((a.active?.duration ?? -1)-0.29)<1e-9)
for i in 0...290 {
 let t=Double(i)/1000;a.active?.sample(a,at:t);b.active?.sample(b,at:t)
 check("unobstructed legacy trace",a.position.distance(to:b.position)<0.001)
}
for root in [CGPoint(x:-689.5,y:280),CGPoint(x:689.5,y:280)] {
 let p=player(root);p.strike(CGPoint(x:1,y:0))
 for i in 0...290 {p.active?.sample(p,at:Double(i)/1000);check("action root safe",map.valid(p.position,radius:10))}
}
let p=player(map.player),q=player(map.player,constrained:false)
p.strike(heading);q.strike(heading)
for t in [0.0,0.02,0.05] {p.active?.sample(p,at:t);q.active?.sample(q,at:t)}
p.position=p.position+CGPoint(x:20,y:10);q.position=q.position+CGPoint(x:20,y:10)
for t in [0.06,0.08,0.12,0.15,0.29] {p.active?.sample(p,at:t);q.active?.sample(q,at:t);check("current root additive",p.position.distance(to:q.position)<0.001)}
p.strike(CGPoint(x:-1,y:0));q.strike(CGPoint(x:-1,y:0))
for t in [0.0,0.04,0.08,0.15,0.29] {p.active?.sample(p,at:t);q.active?.sample(q,at:t);check("replacement fresh state",p.position.distance(to:q.position)<0.001)}
let replacing=player(map.player),legacyReplacing=player(map.player,constrained:false)
replacing.strike(heading);legacyReplacing.strike(heading)
for t in [0.0,0.02,0.05] {replacing.active?.sample(replacing,at:t);legacyReplacing.active?.sample(legacyReplacing,at:t)}
replacing.strike(CGPoint(x:-0.8,y:0.6));legacyReplacing.strike(CGPoint(x:-0.8,y:0.6))
for t in [0.0,0.03,0.08,0.15,0.29] {replacing.active?.sample(replacing,at:t);legacyReplacing.active?.sample(legacyReplacing,at:t);check("midsegment replacement fresh state",replacing.position.distance(to:legacyReplacing.position)<0.001)}
let blocked=player(CGPoint(x:-690,y:280));var requests:[CGFloat]=[]
blocked.debugKaijuLungeConstraint={from,to,_ in requests.append(to.x-from.x);return from}
let action=blocked.constrainedKaijuMove(by:CGPoint(x:-4,y:0),duration:0.08)
for t in [0.0,0.02,0.04,0.06,0.08] {action.sample(blocked,at:t)}
check("blocked debt consumed",requests.dropFirst().allSatisfy{abs($0+1)<0.00001})
check("blocked position held",blocked.position==CGPoint(x:-690,y:280))
let radiusProbe=player(map.player);var radii:[CGFloat]=[];radiusProbe.debugKaijuLungeConstraint={from,to,r in radii.append(r);return to};let probe=radiusProbe.constrainedKaijuMove(by:CGPoint(x:4,y:0),duration:0.08)
probe.sample(radiusProbe,at:0.02);radiusProbe.stats?.effectiveCollisionRadius=12.5;probe.sample(radiusProbe,at:0.04)
check("live radius",radii==[10,12.5])
check("nonfinite request holds",adapter.step(from:map.player,toward:CGPoint(x:CGFloat.infinity,y:0),radius:10)==map.player)
check("invalid start holds",adapter.step(from:CGPoint(x:900,y:900),toward:map.player,radius:10)==CGPoint(x:900,y:900))
check("two room inert",Arena8KaijuLunge(map:.twoRoom).step(from:map.player,toward:map.player+CGPoint(x:2,y:0),radius:10)==map.player)
print("\(passed) passed / \(failed) failed")
exit(failed==0 ? 0:1)
