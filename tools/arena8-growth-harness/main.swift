import Foundation
import CoreGraphics
var passed = 0, failed = 0
func check(_ name: String, _ condition: Bool) {
    if condition { passed += 1; print("PASS \(name)") } else { failed += 1; print("FAIL \(name)") }
}
let map = Arena8GameMap.sixRoom
var roots = map.rooms.map(\.center) + map.connections.map(\.center)
roots += map.rooms.map { CGPoint(x:$0.rect.minX + 55.01, y:$0.rect.minY + 55.01) }
for room in map.rooms {
    let f = Arena8GardenFootprint(map:map, root:room.center, startingRadius:110)
    check("room\(room.id) cap is180 not world or legacy circle",f?.maximumRadius == 180)
    check("room\(room.id) root room captured",f?.roomID == room.id)
    check("room\(room.id) covers own root",f?.covers(room.center,radius:110) == true)
    if let f {
        var radius: CGFloat = 110
        for multiplier: CGFloat in [1.16,1.22,1.20,1.16,1.22,1.20] {
            let grown = f.grownRadius(current:radius,multiplier:multiplier)
            check("room\(room.id) monotonic growth",grown >= radius && grown <= 180)
            radius = grown
        }
        check("room\(room.id) expansion Tree RichSoil reach same cap",radius == 180)
        check("room\(room.id) already above cap never shrinks",f.grownRadius(current:240,multiplier:1.22) == 240)
        check("room\(room.id) non-growth never shrinks",f.grownRadius(current:170,multiplier:0.5) == 170)
        let large = Arena8GardenFootprint(map:map,root:room.center,startingRadius:220)
        check("room\(room.id) starting size retained",large?.maximumRadius == 220)
        var validSamples = 0, badSamples = 0
        for i in 0...100 {
            if let p = f.flowerPoint(radius:153,radialUnit:CGFloat(i)/100,angularUnit:CGFloat((i*37)%101)/100,margin:10) {
                validSamples += 1
                if !f.covers(p,radius:153) || !map.valid(p,radius:10) { badSamples += 1 }
            }
        }
        check("room\(room.id) flower candidates stay on visible clear ground",validSamples > 0 && badSamples == 0)
    }
    for offset in [CGPoint(x:-400,y:-400),CGPoint(x:400,y:400),CGPoint(x:-185,y:0),CGPoint(x:185,y:0)] {
        let p = Arena8GardenFootprint.placementRoot(in:map,toward:room.center+offset,clearance:55)
        check("room\(room.id) projection never roots in walls or outside",p.map { map.valid($0,radius:55) } == true)
    }
}
for connection in map.connections {
    let root = connection.center
    let d = (map.rooms[connection.to].center - map.rooms[connection.from].center).normalized
    let perpendicular = CGPoint(x:-d.y,y:d.x)
    guard let f = Arena8GardenFootprint(map:map,root:root,startingRadius:110) else { check("corridor initializer",false); continue }
    check("corridor\(connection.from)-\(connection.to) tie retains authored order",f.roomID == min(connection.from,connection.to))
    let visible = root - d * 130 + perpendicular * 20
    let hidden = root - d * 130 + perpendicular * 100
    check("corridor\(connection.from)-\(connection.to) open doorway covered",f.covers(visible,radius:180) && !map.geometry.segmentBlockedExact(root,visible))
    check("corridor\(connection.from)-\(connection.to) valid floor behind wall excluded",map.valid(hidden,radius:0) && hidden.distance(to:root)<180 && map.geometry.segmentBlockedExact(root,hidden) && !f.covers(hidden,radius:180))
    check("corridor\(connection.from)-\(connection.to) solid side excluded",!f.covers(root+perpendicular*80,radius:180))
    check("corridor\(connection.from)-\(connection.to) root projection stays here",Arena8GardenFootprint.placementRoot(in:map,toward:root,clearance:55) == root)
}
var comparisons = 0, mismatches = 0, maskMismatches = 0
for root in roots {
    guard let f = Arena8GardenFootprint(map:map,root:root,startingRadius:110) else { mismatches += 1; continue }
    // SKCropNode consumes this polygon without a floor or LoS guard. Compare
    // the raw render path independently so a polygon spill cannot be hidden
    // by the gameplay-side exact-wall check in covers().
    let rawMask = CGMutablePath()
    rawMask.addLines(between:f.visibilityPolygon)
    rawMask.closeSubpath()
    for x in stride(from:-690.0,through:690,by:37) { for y in stride(from:-450.0,through:450,by:31) {
        let p = CGPoint(x:x+0.173,y:y+0.319)
        let expected = p.distance(to:root)<180 && map.valid(p,radius:0) && !map.geometry.segmentBlockedExact(root,p)
        comparisons += 1
        if f.covers(p,radius:180) != expected { mismatches += 1 }
        let rendered = rawMask.contains(p) && p.distance(to:root)<180
        if rendered != expected { maskMismatches += 1 }
    }}
}
check("dense exact-wall/radius coverage comparison",comparisons > 20000 && mismatches == 0)
check("raw rendered polygon independently matches visible ground",comparisons > 20000 && maskMismatches == 0)
check("two-room control excluded",Arena8GardenFootprint(map:.twoRoom,root:Arena8GameMap.twoRoom.player,startingRadius:110) == nil)
for radius: CGFloat in [-1,0,.nan,.infinity] { check("invalid initial radius\(radius)",Arena8GardenFootprint(map:map,root:map.player,startingRadius:radius) == nil) }
for p in [CGPoint(x:CGFloat.nan,y:0),CGPoint(x:0,y:CGFloat.infinity)] {
    check("invalid root refuses safely",Arena8GardenFootprint.placementRoot(in:map,toward:p,clearance:55) == nil)
}
print("INFO \(comparisons) exact coverage comparisons, \(mismatches) gameplay / \(maskMismatches) raw mask mismatches")
print("RESULT \(passed) passed \(failed) failed")
exit(failed == 0 ? 0 : 1)
