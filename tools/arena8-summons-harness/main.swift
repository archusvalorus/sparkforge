import Foundation
import CoreGraphics
var passed = 0, failed = 0
func check(_ name:String,_ pass:Bool) {
    if pass { passed += 1; print("PASS \(name)") } else { failed += 1; print("FAIL \(name)") }
}
let map = Arena8GameMap.sixRoom
guard let rules = Arena8SummonRules(map:map) else { fatalError("six-room rules missing") }
check("two-room control excluded",Arena8SummonRules(map:.twoRoom) == nil)
for allowance:CGFloat in [0,78,156] {
    for room in map.rooms {
        check("room\(room.id) alive with pad\(allowance)",!rules.payloadOutside(room.center,allowance:allowance))
    }
    for (i,c) in map.connections.enumerated() {
        check("corridor\(i) alive with pad\(allowance)",!rules.payloadOutside(c.center,allowance:allowance))
    }
    for (i,wall) in map.geometry.blockedFootprints.enumerated() {
        // These payloads already fly through terrain. Do not accidentally use
        // walkable-floor validity as their cleanup boundary.
        check("flying payload crosses wall\(i) with pad\(allowance)",!rules.payloadOutside(wall.center,allowance:allowance))
    }
    let outer = map.world.insetBy(dx:-allowance,dy:-allowance)
    for p in [CGPoint(x:outer.minX,y:0),CGPoint(x:outer.maxX,y:0),CGPoint(x:0,y:outer.minY),CGPoint(x:0,y:outer.maxY),CGPoint(x:outer.maxX,y:outer.maxY),CGPoint(x:outer.minX,y:outer.minY)] {
        check("exact rectangular rim retained \(p)",!rules.payloadOutside(p,allowance:allowance))
    }
    for p in [CGPoint(x:outer.minX-1,y:0),CGPoint(x:outer.maxX+1,y:0),CGPoint(x:0,y:outer.minY-1),CGPoint(x:0,y:outer.maxY+1),CGPoint(x:outer.maxX+1,y:outer.maxY+1)] {
        check("past rectangular rim cleans \(p)",rules.payloadOutside(p,allowance:allowance))
    }
}
let roots = map.rooms.map(\.center) + map.connections.map(\.center)
    + map.rooms.map { CGPoint(x:$0.rect.midX,y:$0.rect.maxY-20) }
for (index,root) in roots.enumerated() {
    for body:CGFloat in [12,24,34] {
        for offset:CGFloat in [0,20,120,300] {
            let preferred = root + CGPoint(x:0,y:offset)
            let point = rules.lionSpawn(near:root,canopyOffset:offset,bodyRadius:body)
            check("root\(index) offset\(offset) body\(body) safe",point.map { map.valid($0,radius:body) } == true)
            if map.valid(preferred,radius:body) {
                check("root\(index) original safe canopy preserved",point == preferred)
            } else if map.valid(root,radius:body) {
                check("root\(index) blocked canopy falls back to Tree root",point == root)
            } else {
                check("root\(index) narrow root fallback stays nearby",point.map { $0.distance(to:root)<body+1 } == true)
            }
        }
    }
}
for p in [CGPoint(x:CGFloat.nan,y:0),CGPoint(x:0,y:CGFloat.infinity)] {
    check("nonfinite payload cleans",rules.payloadOutside(p,allowance:78))
    check("nonfinite root refuses birth",rules.lionSpawn(near:p,canopyOffset:20,bodyRadius:12) == nil)
}
for x:CGFloat in [-1,.nan,.infinity] {
    check("invalid allowance fails closed",rules.payloadOutside(map.player,allowance:x))
    check("invalid footprint refuses birth",rules.lionSpawn(near:map.player,canopyOffset:20,bodyRadius:x) == nil)
}
check("solid root refuses unsafe birth",rules.lionSpawn(near:map.geometry.blockedFootprints[0].center,canopyOffset:0,bodyRadius:12) == nil)
check("outside root refuses unsafe birth",rules.lionSpawn(near:CGPoint(x:9999,y:9999),canopyOffset:0,bodyRadius:12) == nil)
check("nonfinite canopy refuses birth",rules.lionSpawn(near:map.player,canopyOffset:.nan,bodyRadius:12) == nil)
// Approved bounded launch entry; ordinary cleanup resumes permanently.
for scale:CGFloat in [1, 1.7969230769230768] {
    let rootY:CGFloat = map.world.maxY - 55*scale
    let birth = CGPoint(x:map.rooms[2].center.x,y:rootY + 165*0.92*scale)
    let allowance:CGFloat = 350*scale*1.2 - 350*scale
    guard var fox = rules.payloadFlight(from:birth,allowance:allowance),
          var boar = rules.payloadFlight(from:birth,allowance:allowance) else {
        check("capture valid scaled crown",false);continue
    }
    check("crown needs temporary entry exception",rules.payloadOutside(birth,allowance:allowance) && !fox.enteredNormalBounds)
    check("captured crown starts inside envelope",!fox.outsideAfterAdvance(to:birth))
    check("fox first inward step survives",!fox.outsideAfterAdvance(to:birth-CGPoint(x:0,y:300*scale/60)))
    check("boar first inward step survives",!boar.outsideAfterAdvance(to:birth-CGPoint(x:0,y:460*scale/60)))
    let edge = CGPoint(x:map.rooms[2].center.x,y:map.world.maxY+allowance)
    check("exact ordinary rim arms permanent cleanup",!fox.outsideAfterAdvance(to:edge) && fox.enteredNormalBounds)
    check("return into launch exception now retires",fox.outsideAfterAdvance(to:birth-CGPoint(x:0,y:1)))
    check("other payload entry state independent",!boar.enteredNormalBounds && !boar.outsideAfterAdvance(to:birth))
    check("never-enter exit still retires",boar.outsideAfterAdvance(to:birth+CGPoint(x:0,y:1)))
}
let pad:CGFloat = 70
let rect = map.world.insetBy(dx:-pad,dy:-pad)
for birth in [CGPoint(x:rect.minX-25,y:0),CGPoint(x:rect.maxX+25,y:0),CGPoint(x:0,y:rect.minY-25),CGPoint(x:0,y:rect.maxY+25),CGPoint(x:rect.maxX+25,y:rect.maxY+25)] {
    guard var flight = rules.payloadFlight(from:birth,allowance:pad) else {check("finite edge capture",false);continue}
    let frozen = flight.launchEnvelope
    check("capture contains its original birth",!flight.outsideAfterAdvance(to:birth))
    check("normal entry is one-way",!flight.outsideAfterAdvance(to:map.player) && flight.enteredNormalBounds)
    check("captured envelope never follows later positions",flight.launchEnvelope == frozen)
    check("postentry outside is retired",flight.outsideAfterAdvance(to:birth))
}
if var normal = rules.payloadFlight(from:map.player,allowance:pad) {
    check("inside birth begins armed",normal.enteredNormalBounds)
    check("inside birth gets no global extension",normal.outsideAfterAdvance(to:CGPoint(x:rect.maxX+1,y:0)))
}
check("invalid birth refuses entry capture",rules.payloadFlight(from:CGPoint(x:CGFloat.nan,y:0),allowance:pad) == nil)
check("invalid allowance refuses entry capture",rules.payloadFlight(from:map.player,allowance:.infinity) == nil)
if var flight = rules.payloadFlight(from:map.player,allowance:pad) {
    check("nonfinite advance retires",flight.outsideAfterAdvance(to:CGPoint(x:0,y:CGFloat.nan)))
}
print("RESULT \(passed) passed \(failed) failed")
exit(failed == 0 ? 0 : 1)
