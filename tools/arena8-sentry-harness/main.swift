import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ value:Bool){if value{passed += 1;print("PASS \(name)")}else{failed += 1;print("FAIL \(name)")}}
let map=Arena8GameMap.sixRoom
let rule=Arena8SentryPlacement(map:map)!
check("two-room excluded",Arena8SentryPlacement(map:.twoRoom)==nil)
let points=map.rooms.map(\.center)+map.connections.map(\.center)+map.rooms.flatMap{[CGPoint(x:$0.rect.maxX,y:$0.rect.maxY),CGPoint(x:$0.rect.minX,y:$0.rect.minY)]}+map.geometry.blockedFootprints.map(\.center)
for margin:CGFloat in [16,22,16.5,22.25] {for p in points {
 let result=rule.center(at:p,clearance:margin)
 check("root safe nominal clearance",result.map{map.valid($0,radius:margin)}==true)
 check("Float stored safe",result.map{map.valid(CGPoint(x:CGFloat(Float($0.x)),y:CGFloat(Float($0.y))),radius:margin)}==true)
 if map.valid(p,radius:margin){check("valid point preserved",result==p)}
}}
for room in map.rooms {
 var draws=0
 let result=rule.nearSpark(existing:[],spacing:60){draws += 1;return room.center+CGPoint(x:70,y:0)}
 check("first valid accepted no extra RNG",draws==1 && result==room.center+CGPoint(x:70,y:0))
 check("outer rooms never origin-circle-clamped",result.map{$0.distance(to:room.center)==70}==true)
 draws=0
 let forbidden=CGPoint(x:room.rect.maxX+100,y:room.rect.maxY+100)
 let fallback=rule.nearSpark(existing:[],spacing:60){draws += 1;return forbidden}
 check("unsafe samples bounded sixteen",draws==16)
 check("last candidate fallback safe",fallback.map{map.valid($0,radius:16)}==true)
 draws=0
 let overlap=rule.nearSpark(existing:[room.center],spacing:60){draws += 1;return room.center}
 check("best effort spacing retained after sixteen",draws==16 && overlap==room.center)
 draws=0
 let second=rule.nearSpark(existing:[room.center],spacing:60){draws += 1;return draws==1 ? room.center:room.center+CGPoint(x:80,y:0)}
 check("spacing rejects before valid second",draws==2 && second==room.center+CGPoint(x:80,y:0))
}
// Independent acceptance cases: failed raw samples do not get projected into
// an early success; only the final attempted candidate supplies the fallback.
let unsafeA=CGPoint(x:map.world.maxX+200,y:map.world.maxY+200)
let unsafeB=CGPoint(x:map.world.minX-200,y:map.world.minY-200)
var draws=0
let sixteenth=map.rooms[5].center
let lastSuccess=rule.nearSpark(existing:[],spacing:60){draws += 1;return draws==16 ? sixteenth:unsafeA}
check("unsafe samples rejected until valid sixteenth",draws==16 && lastSuccess==sixteenth)
draws=0
let lastFallback=rule.nearSpark(existing:[],spacing:60){draws += 1;return draws==16 ? unsafeB:unsafeA}
check("fallback projects final sample not first",draws==16 && lastFallback==rule.center(at:unsafeB,clearance:16))
// This raw point clears spacing, but Float storage brings it just inside 60.
let existing=map.rooms[0].center
var threshold=existing
for ix in -20...20 {for iy in -20...20 {
 let candidate=existing+CGPoint(x:36+CGFloat(ix)*0.00001,y:48+CGFloat(iy)*0.00001)
 let value=CGPoint(x:CGFloat(Float(candidate.x)),y:CGFloat(Float(candidate.y)))
 if candidate.distance(to:existing)>60 && value.distance(to:existing)<60 {threshold=candidate}
}}
let rounded=CGPoint(x:CGFloat(Float(threshold.x)),y:CGFloat(Float(threshold.y)))
check("Float spacing fixture is nonvacuous",threshold.distance(to:existing)>=60 && rounded.distance(to:existing)<60)
draws=0
let retry=existing+CGPoint(x:80,y:0)
let spaced=rule.nearSpark(existing:[existing],spacing:60){draws += 1;return draws==1 ? threshold:retry}
check("actual Float spacing rejects raw-only success",draws==2 && spaced==retry)
for spacing:CGFloat in [-1,.nan,.infinity] {
 draws=0
 let invalid=rule.nearSpark(existing:[],spacing:spacing){draws += 1;return map.player}
 check("invalid spacing consumes no samples",invalid==nil && draws==0)
}
for p in [CGPoint(x:CGFloat.nan,y:0),CGPoint(x:0,y:CGFloat.infinity)] {
 check("nonfinite rejected",rule.center(at:p,clearance:16)==nil)
 var draws=0;let result=rule.nearSpark(existing:[],spacing:60){draws += 1;return p}
 check("nonfinite no origin fallback",draws==16 && result==nil)
}
for margin:CGFloat in [0,-1,.nan,.infinity,100000]{check("invalid clearance rejected",rule.center(at:.zero,clearance:margin)==nil)}
check("central network anchor safe",rule.center(at:.zero,clearance:22).map{map.valid($0,radius:22)}==true)
let root=CommandLine.arguments[1]
let source=try! String(contentsOfFile:root+"/Sparkforge/Scenes/GameScene.swift",encoding:.utf8)
let original=try! String(contentsOfFile:root+"/tools/arena8-sentry-harness/baseline-targeting.swift.txt",encoding:.utf8)
let a=source.range(of:"    private func updateSentryCoils(")!.lowerBound
let b=source.range(of:"    private func deploySentryCoils(",range:a..<source.endIndex)!.lowerBound
check("targeting cadence damage wall policy byte identical",String(source[a..<b])==original)
print("RESULT \(passed) passed \(failed) failed")
if failed>0{exit(1)}
