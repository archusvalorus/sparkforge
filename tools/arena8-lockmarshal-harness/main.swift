import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;if failed<=30 {print("FAIL \(name)")}}}
let map=Arena8GameMap.sixRoom
let C=GameConfig.LockmarshalFixture.self
func stored(_ p:CGPoint)->CGPoint { CGPoint(x:CGFloat(Float(p.x)),y:CGFloat(Float(p.y))) }
func ready(_ root:CGPoint,_ player:CGPoint)->LockmarshalModel{
 var m=LockmarshalModel(map:map,position:root)
 for _ in 0..<25 where m.phase == .pursuit {_=m.update(0.1,player:player,playerRadius:14)}
 return m
}
for room in map.rooms {
 for offset in [CGPoint.zero,CGPoint(x:-230,y:-230),CGPoint(x:230,y:230),CGPoint(x:-230,y:230),CGPoint(x:230,y:-230)] {
  let root=stored(room.center+offset)
  check("initial-body-safe",map.valid(root,radius:C.bodyRadius))
  for i in 0..<24 {
   let angle=CGFloat(i)*CGFloat.pi/12
   let aim=root+CGPoint(x:cos(angle),y:sin(angle))*200
   var m=ready(root,aim)
   check("warn-before-any-advance",m.phase == .thresholdWarning)
   check("declared-whole-segment-safe",!map.geometry.segmentBlockedExact(m.start,m.goal,travelRadius:C.bodyRadius))
   let goal=m.goal,start=m.start
   let heldRemaining=m.remaining
   for _ in 0..<30 {_=m.update(9,player:root,playerRadius:14,held:true)}
   check("held-model-exact",m.remaining==heldRemaining && m.position==start)
   var damage=0,checkedStamp=false
   for j in 0..<120 {
    let before=m.position
    let f=m.update(0.05,player:root+CGPoint(x:0,y:100),playerRadius:14)
    if f.damage{damage+=1}
    check("every-Float-body-safe",map.valid(m.position,radius:C.bodyRadius) && stored(m.position)==m.position)
    check("each-step-swept-not-endpoint",!map.geometry.segmentBlockedExact(before,m.position,travelRadius:C.bodyRadius))
    if m.phase == .advance {check("no-homing-goal",m.goal==goal && m.start==start)}
    if m.phase == .stampWarning && !checkedStamp {
      checkedStamp=true
      let polygon=m.stamp,path=LockmarshalModel.stampPath(polygon),center=m.position
      check("stamp-polygon-exists",polygon.count>=3 && path.contains(center))
      check("stamp-bounded",polygon.allSatisfy{abs($0.x-center.x)<=82.000001 && abs($0.y-center.y)<=82.000001})
      for x in 1...15 {for y in 1...15 {
        let p=center+CGPoint(x:-82+164*CGFloat(x)/16,y:-82+164*CGFloat(y)/16)
        if path.contains(p) {
          check("painted-interior-floor",map.valid(p,radius:0))
          check("painted-interior-root-visible",!map.geometry.segmentBlockedExact(center,p))
        }
      }}
      for k in polygon.indices {
        let a=polygon[k],b=polygon[(k+1)%polygon.count]
        let cross=(a.x-center.x)*(b.y-center.y)-(a.y-center.y)*(b.x-center.x)
        if abs(cross)>0.00001 {
          for weights in [(0.05,0.475,0.475),(0.001,0.4995,0.4995),(0.1,0.85,0.05),(0.1,0.05,0.85)] {
            let p=center*CGFloat(weights.0)+a*CGFloat(weights.1)+b*CGFloat(weights.2)
            check("painted-triangle-edge-neighborhood-floor",map.valid(p,radius:0))
            check("painted-triangle-edge-neighborhood-visible",!map.geometry.segmentBlockedExact(center,p))
          }
        }
      }
    }
    if j==119 {check("alternating-second-verb-reached",m.nextVerb == .threshold && checkedStamp)}
   }
   m.cancel();let p=m.position
   for _ in 0..<100 {let f=m.update(10,player:p,playerRadius:14);check("cancel-terminal-no-damage",!f.damage && !f.committed && m.position==p && m.phase == .cancelled && m.stamp.isEmpty)}
  }
 }
}
// Body-clear traversal through all seven actual authored doorways, both ways.
for c in map.connections {
 for pair in [(c.from,c.to),(c.to,c.from)] {
  var m=LockmarshalModel(map:map,position:map.rooms[pair.0].center)
  let aim=map.rooms[pair.1].center
  for _ in 0..<2500 {
   let before=m.position
   _=m.update(0.05,player:aim,playerRadius:14)
   check("door-route-swept",map.valid(m.position,radius:C.bodyRadius) && !map.geometry.segmentBlockedExact(before,m.position,travelRadius:C.bodyRadius))
   if m.position.distance(to:aim)<45 {break}
  }
  check("door-route-reaches-other-room",m.position.distance(to:aim)<45)
 }
}
// Every room/corridor admits an escape outside the painted square within one
// base-speed warning. Paths are swept with Spark's actual representative14pt body.
let edgeRoots=map.rooms.flatMap { r in [CGPoint(x:r.rect.minX+26.5,y:r.rect.minY+26.5),CGPoint(x:r.rect.maxX-26.5,y:r.rect.minY+26.5),CGPoint(x:r.rect.minX+26.5,y:r.rect.maxY-26.5),CGPoint(x:r.rect.maxX-26.5,y:r.rect.maxY-26.5)] }
let doorRoots=map.connections.flatMap { c in [c.center,CGPoint(x:c.corridor.minX+26.5,y:c.center.y),CGPoint(x:c.corridor.maxX-26.5,y:c.center.y),CGPoint(x:c.center.x,y:c.corridor.minY+26.5),CGPoint(x:c.center.x,y:c.corridor.maxY-26.5)] }.filter {map.valid($0,radius:C.bodyRadius)}
for root in map.rooms.map(\.center)+edgeRoots+doorRoots {
 let distance=C.stampHalfSide+14+1
 let escapes=(0..<8).map{CGFloat($0)*CGFloat.pi/4}.filter { a in
  let to=root+CGPoint(x:cos(a),y:sin(a))*distance
  let painted=LockmarshalModel.stampPolygon(map:map,root:root)
  return map.valid(to,radius:14) && !map.geometry.segmentBlockedExact(root,to,travelRadius:14) && !LockmarshalModel.circle(to,radius:14,touches:painted)
 }
 check("reachable-base-speed-stamp-escape",!escapes.isEmpty && distance<GameConfig.Player.speed*CGFloat(C.warningDuration))
}
var m=ready(map.player,map.player+CGPoint(x:160,y:0));let before=m.remaining
_=m.update(.nan,player:map.player,playerRadius:14);_=m.update(-1,player:map.player,playerRadius:14)
check("invalid-delta-no-work",m.remaining==before)
_=m.update(99,player:map.player,playerRadius:14)
check("bounded-resume-no-catchup",abs(m.remaining-(before-0.1))<1e-8)
m.interrupt();check("interrupt-fresh-pursuit",m.phase == .pursuit && m.remaining==C.pursuitDuration && m.stamp.isEmpty)
check("relative-crossing-positive",LockmarshalModel.segmentDistance(.zero,CGPoint(x:-100,y:0),CGPoint(x:100,y:0))==0)
check("relative-crossing-negative",LockmarshalModel.segmentDistance(.zero,CGPoint(x:-100,y:60),CGPoint(x:100,y:60))==60)

var once=ready(map.player,map.player+CGPoint(x:160,y:0))
let contactPoint=once.start
while once.phase == .thresholdWarning {_=once.update(0.05,player:contactPoint,playerRadius:14)}
var attempts=0
for _ in 0..<40 where once.phase == .advance {if once.update(0.01,player:contactPoint,playerRadius:14).damage {attempts+=1}}
check("one-hit-per-advance",attempts==1)

let cornerBoss=CGPoint(x:-536.5,y:506),oldSpark=CGPoint(x:-490,y:460),newSpark=CGPoint(x:-540,y:550)
check("contact-corner-input-bodies-valid",map.valid(cornerBoss,radius:26) && map.valid(oldSpark,radius:14) && map.valid(newSpark,radius:14))
check("invalid-closest-interpolated-body-rejected",!LockmarshalModel.advanceContact(map:map,bossFrom:cornerBoss,bossTo:cornerBoss,playerFrom:oldSpark,playerTo:newSpark,playerRadius:14))
check("valid-relative-crossing-hits",LockmarshalModel.advanceContact(map:map,bossFrom:map.player+CGPoint(x:-100,y:0),bossTo:map.player+CGPoint(x:100,y:0),playerFrom:map.player,playerTo:map.player,playerRadius:14))
for ix in 0...56 {for iy in 0...36 {
 let root=CGPoint(x:map.world.minX+CGFloat(ix)*map.world.width/56,y:map.world.minY+CGFloat(iy)*map.world.height/36)
 if map.valid(root,radius:C.bodyRadius) {
  let polygon=LockmarshalModel.stampPolygon(map:map,root:root)
  check("all-grid-valid-boss-roots-have-stamp",polygon.count>=3 && LockmarshalModel.stampPath(polygon).contains(root))
 }
}}
check("visibility-root-clearance-compatible",GameConfig.Growth.flowerRootMargin<=C.bodyRadius)
let shadowRoot=CGPoint(x:-536.5,y:500),hiddenSpark=CGPoint(x:-460,y:465),visibleSpark=CGPoint(x:-460,y:430)
let shadow=LockmarshalModel.stampPolygon(map:map,root:shadowRoot)
check("shadow-test-bodies-valid",map.valid(shadowRoot,radius:26) && map.valid(hiddenSpark,radius:14) && map.valid(visibleSpark,radius:14))
check("hidden-door-corner-really-occluded",map.geometry.segmentBlockedExact(shadowRoot,hiddenSpark))
check("hidden-door-body-unpainted-unharmed",!LockmarshalModel.circle(hiddenSpark,radius:14,touches:shadow))
check("open-door-passage-painted-hittable",!map.geometry.segmentBlockedExact(shadowRoot,visibleSpark) && LockmarshalModel.stampPath(shadow).contains(visibleSpark) && LockmarshalModel.circle(visibleSpark,radius:14,touches:shadow))
let openSquare=LockmarshalModel.stampPolygon(map:map,root:map.player)
for direction in [CGPoint(x:-1,y:-1),CGPoint(x:1,y:-1),CGPoint(x:1,y:1),CGPoint(x:-1,y:1)] {
 check("square-corners-not-Growth-circle-capped",LockmarshalModel.stampPath(openSquare).contains(map.player+direction*81.999))
}
let square=LockmarshalModel.rectangleVertices(CGRect(x:0,y:0,width:100,height:100))
check("shared-polygon-body-touch",LockmarshalModel.circle(CGPoint(x:114,y:50),radius:14,touches:square))
check("shared-polygon-body-miss",!LockmarshalModel.circle(CGPoint(x:114.001,y:50),radius:14,touches:square))
print("Lockmarshal model: \(passed) passed, \(failed) failed")
exit(failed==0 ? 0:1)
