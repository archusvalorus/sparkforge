import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ id:String,_ yes:@autoclosure()->Bool){if yes(){passed+=1;print("PASS \(id)")}else{failed+=1;print("FAIL \(id)")}}
let provenance=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))) as? [String:Any]
let recorded=provenance?["recorded_radius"] as? Double ?? .nan
check("recorded actual Guard radius loaded",recorded.isFinite && recorded>0 && recorded.rounded() != recorded)
let stage=GameConfig.Arena9TraversalLab.map
check("validated stage map exists",stage != nil)
if let stage {
 for (label,map) in [("A8",Arena8GameMap.sixRoom),("A9",stage)] {
  let rect=map.world
  let root=label=="A8" ? map.rooms[2].center:CGPoint(x:2000,y:0)
  func length(_ d:CGPoint,_ range:CGFloat,_ blocked:((CGPoint,CGPoint)->Bool)?=nil)->CGFloat{BeamTick.length(origin:root,direction:d,maxLength:range,arenaRect:rect,blocked:blocked,steps:14)}
  check(label+" unlimited forward to rectangular edge",abs(length(CGPoint(x:1,y:0),.infinity)-(rect.maxX-root.x))<0.000001)
  check(label+" finite range retained",length(CGPoint(x:1,y:0),25)==25)
  check(label+" zero range",length(CGPoint(x:1,y:0),0)==0)
  check(label+" negative-X exit",abs(length(CGPoint(x:-1,y:0),.infinity)-(root.x-rect.minX))<0.000001)
  check(label+" positive-Y exit",abs(length(CGPoint(x:0,y:1),.infinity)-(rect.maxY-root.y))<0.000001)
  check(label+" negative-Y exit",abs(length(CGPoint(x:0,y:-1),.infinity)-(root.y-rect.minY))<0.000001)
  let unit:CGFloat=1/sqrt(2)
  for (dx,dy) in [(unit,unit),(unit,-unit),(-unit,unit),(-unit,-unit)] {
   let horizontal=dx>0 ? rect.maxX-root.x:root.x-rect.minX
   let vertical=dy>0 ? rect.maxY-root.y:root.y-rect.minY
   check(label+" diagonal analytic exit",abs(length(CGPoint(x:dx,y:dy),.infinity)-min(horizontal,vertical)/unit)<0.000001)
  }
  let boundary=CGPoint(x:rect.maxX,y:rect.midY)
  check(label+" boundary outward ray zero",BeamTick.length(origin:boundary,direction:CGPoint(x:1,y:0),maxLength:.infinity,arenaRect:rect,blocked:nil,steps:14)==0)
  check(label+" boundary inward crosses width",BeamTick.length(origin:boundary,direction:CGPoint(x:-1,y:0),maxLength:.infinity,arenaRect:rect,blocked:nil,steps:14)==rect.width)
  check(label+" boundary tangent reaches corner",BeamTick.length(origin:boundary,direction:CGPoint(x:0,y:1),maxLength:.infinity,arenaRect:rect,blocked:nil,steps:14)==rect.height/2)
  check(label+" negative range fails closed",length(CGPoint(x:1,y:0),-1)==0)
  let wallX=root.x+50
  let blocked:(CGPoint,CGPoint)->Bool={_,b in b.x>=wallX}
  let wall=length(CGPoint(x:1,y:0),.infinity,blocked)
  check(label+" first-solid bisection unchanged",wall>0 && wall<=50 && 50-wall<rect.width/16384)
  check(label+" nil terrain predicate passes walls",length(CGPoint(x:1,y:0),.infinity)>50)
  for radius:CGFloat in [0,4,CGFloat(recorded),7,8.5,10,14.3,20,40] {
   let left=map.rooms.first{$0.rect.minX==rect.minX},right=map.rooms.first{$0.rect.maxX==rect.maxX},top=map.rooms.first{$0.rect.maxY==rect.maxY},bottom=map.rooms.first{$0.rect.minY==rect.minY}
   guard let left,let right,let top,let bottom else{check("edge rooms exist",false);continue}
   let edges=[(CGPoint(x:rect.minX+radius+20,y:left.center.y),CGPoint(x:-1,y:0)),(CGPoint(x:rect.maxX-radius-20,y:right.center.y),CGPoint(x:1,y:0)),(CGPoint(x:top.center.x,y:rect.maxY-radius-20),CGPoint(x:0,y:1)),(CGPoint(x:bottom.center.x,y:rect.minY+radius+20),CGPoint(x:0,y:-1))]
   for (from,dir) in edges {
    check(label+" edge start legal",map.valid(from,radius:radius))
    let desired=from+dir*500
    for end in [map.move(from:from,toward:desired,radius:radius),map.shove(from:from,toward:desired,radius:radius)] {
     check(label+" endpoint exists",end != nil)
     if let end {
      let stored=CGPoint(x:CGFloat(Float(end.x)),y:CGFloat(Float(end.y)))
      check(label+" unchanged-radius stored root safe",map.valid(stored,radius:radius))
      check(label+" normal edge sweep not across a wall",!map.geometry.segmentBlockedExact(from,stored,travelRadius:radius))
     }
    }
   }
   for (x,y,dx,dy) in [(rect.minX,rect.minY,CGFloat(1),CGFloat(1)),(rect.maxX,rect.minY,CGFloat(-1),CGFloat(1)),(rect.minX,rect.maxY,CGFloat(1),CGFloat(-1)),(rect.maxX,rect.maxY,CGFloat(-1),CGFloat(-1))] {
    let from=CGPoint(x:x+dx*(radius+20),y:y+dy*(radius+20)),desired=CGPoint(x:x-dx*100,y:y-dy*100)
    check(label+" corner start legal",map.valid(from,radius:radius))
    for end in [map.move(from:from,toward:desired,radius:radius),map.shove(from:from,toward:desired,radius:radius)] {
     check(label+" simultaneous corner endpoint exists",end != nil)
     if let end {check(label+" simultaneous stored corner safe",map.valid(CGPoint(x:CGFloat(Float(end.x)),y:CGFloat(Float(end.y))),radius:radius))}
    }
   }
  }
 }
 // Exact room terrain must stop the preserved short-corner ray before a
 // legal target across the solid corner, while Long Shot4 remains exempt.
 let cornerMap=Arena8GameMap.sixRoom
 if let middle=cornerMap.rooms.first(where:{$0.id==1}),let door=cornerMap.connections.first(where:{$0.from==0 && $0.to==1}) {
  let corner=CGPoint(x:middle.rect.minX,y:door.corridor.minY)
  let origin=corner+CGPoint(x:20,y:-40),target=corner+CGPoint(x:-40,y:20),direction=(target-origin).normalized
  let exact:(CGPoint,CGPoint)->Bool={a,b in cornerMap.geometry.segmentBlockedExact(a,b,travelRadius:GameConfig.Geometry.projectileTravelRadius)}
  check("corner geometry positive setup",cornerMap.valid(origin,radius:10) && cornerMap.valid(target,radius:14) && exact(origin,target))
  let stopped=BeamTick.length(origin:origin,direction:direction,maxLength:400,arenaRect:cornerMap.world,blocked:exact,steps:14)
  check("exact corner query first solid before hidden target",stopped>0 && stopped<origin.distance(to:target))
  let passing=BeamTick.length(origin:origin,direction:direction,maxLength:.infinity,arenaRect:cornerMap.world,blocked:nil,steps:14)
  check("Long Shot passage retains corner crossing",passing>=origin.distance(to:target))
 }else{check("short corner authored fixture exists",false)}
 let slideMap=Arena8GameMap.sixRoom
 let slideFrom=CGPoint(x:slideMap.rooms[0].rect.maxX-10,y:slideMap.connections[0].corridor.minY-60)
 let slideDesired=slideFrom+CGPoint(x:100,y:100)
 let slide=slideMap.move(from:slideFrom,toward:slideDesired,radius:CGFloat(recorded))
 check("walking preserves X-then-Y face slide rather than diagonal shove",slide.map{$0.y==slideDesired.y && $0.x<slideDesired.x && slideMap.valid(CGPoint(x:CGFloat(Float($0.x)),y:CGFloat(Float($0.y))),radius:CGFloat(recorded))}==true)
 // Many clear and blocked room walks preserve endpoint safety at the actual
 // stored radius. This calls real adapters; no replacement collision model.
 let map=Arena8GameMap.sixRoom
 for radius:CGFloat in [CGFloat(recorded),14.3,20,40] {
  for room in map.rooms {
   for destination in map.rooms.map(\.center)+map.connections.map(\.center) {
    let from=room.center
    if let p=map.move(from:from,toward:destination,radius:radius) {
     let stored=CGPoint(x:CGFloat(Float(p.x)),y:CGFloat(Float(p.y)))
     check("room/corridor stored walking root safe",map.valid(stored,radius:radius))
    }else{check("room/corridor walking fallback start remains safe",map.valid(from,radius:radius))}
    if let p=map.shove(from:from,toward:destination,radius:radius) {
     let stored=CGPoint(x:CGFloat(Float(p.x)),y:CGFloat(Float(p.y)))
     check("room/corridor shove full sweep retained",map.valid(stored,radius:radius) && !map.geometry.segmentBlockedExact(from,stored,travelRadius:radius))
    }else{check("room/corridor shove fallback start remains safe",map.valid(from,radius:radius))}
   }
  }
 }
}
let valid=CGRect(x:-500,y:-350,width:3000,height:700)
for rect in [CGRect.zero,CGRect.null,CGRect.infinite,CGRect(x:CGFloat.nan,y:0,width:10,height:10),CGRect(x:1e200,y:0,width:1,height:10),CGRect(x:0,y:1e200,width:10,height:1)] {
 check("invalid or representably collapsed rectangle fails closed",BeamTick.length(origin:CGPoint(x:rect.midX,y:rect.midY),direction:CGPoint(x:0,y:1),maxLength:.infinity,arenaRect:rect,blocked:nil,steps:14)==0)
}
for dir in [CGPoint.zero,CGPoint(x:CGFloat.nan,y:0),CGPoint(x:0,y:CGFloat.infinity)] {check("invalid direction fails closed",BeamTick.length(origin:.zero,direction:dir,maxLength:100,arenaRect:valid,blocked:nil,steps:14)==0)}
check("NaN range fails closed",BeamTick.length(origin:.zero,direction:CGPoint(x:1,y:0),maxLength:.nan,arenaRect:valid,blocked:nil,steps:14)==0)
check("parallel offset outside ray misses floor",BeamTick.length(origin:CGPoint(x:0,y:400),direction:CGPoint(x:1,y:0),maxLength:.infinity,arenaRect:valid,blocked:nil,steps:14)==0)
check("outside inward ray retains positive-exit convention",BeamTick.length(origin:CGPoint(x:2506,y:0),direction:CGPoint(x:-1,y:0),maxLength:.infinity,arenaRect:valid,blocked:nil,steps:14)==3006)
// Frozen actual T1 circle function, renamed only in the temporary build.
// Compare exact results, including sampled terrain and infinite range.
for radius:CGFloat in [350,629,1000] {
 for origin in [CGPoint.zero,CGPoint(x:radius*0.5,y:radius*0.2),CGPoint(x:radius+6,y:0)] {
  for i in 0..<32 {
   let a=CGFloat(i)*2 * .pi/32,d=CGPoint(x:cos(a),y:sin(a))
   for range:CGFloat in [0,25,400,.infinity] {
    for solid in [false,true] {
     let block:((CGPoint,CGPoint)->Bool)?=solid ? {_,b in b.x>100}:nil
     let old=BaselineBeamTick.length(origin:origin,direction:d,maxLength:range,arenaRadius:radius,blocked:block,steps:14)
     let actual=BeamTick.length(origin:origin,direction:d,maxLength:range,arenaRadius:radius,blocked:block,steps:14)
     check("circle output exactly equals frozen T1 source",old==actual)
    }
   }
  }
 }
}
let control=Arena8GameMap.twoRoom
for p in [control.player,CGPoint(x:40,y:0),CGPoint(x:390,y:150)] {
 let desired=p+CGPoint(x:1000,y:1000),r:CGFloat=10,legacy=Arena8P0Model()
 check("two-room movement delegation unchanged",control.move(from:p,toward:desired,radius:r)==legacy.move(from:p,toward:desired,radius:r))
 check("two-room shove delegation unchanged",control.shove(from:p,toward:desired,radius:r)==legacy.shove(from:p,toward:desired,radius:r))
}
print("RESULT \(passed) passed \(failed) failed");exit(failed==0 ? 0:1)
