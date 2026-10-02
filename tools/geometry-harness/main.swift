// main.swift — geometry proof harness (v2.1 abilities Unit A7b, seam S0b).
//
// The baseline every CL-109 seam builds on. It proves the geometry contract the
// A7b fixes will call (docs/arena6-geometry-reconciliation.md §4, §7.1):
//   G0  open arenas block and resolve nothing (arenas 1–5 are unchanged);
//   G1  the Splitworks is one Fallen Carrier, solid at its centre, anchors clear;
//   G2  resolve always ends clear of the Carrier, and leaves valid points alone;
//   G3  the EXACT segment test (A4c CL-38) equals a dense brute-force march;
//   G4  the stepped test never over-reports, and it does miss short segments
//       that clip a rounded end (the A4c "short-segment hole" the exact test closes);
//   G5  the shared placement sampler never returns a point inside the Carrier,
//       and its give-up fallback (every candidate rejected) resolves out (G5b).
// The harness's own draws are seeded, so a failure reproduces. The sampler
// draws from the system RNG (production code), so G5/G5b assert properties
// that must hold for every draw.

import CoreGraphics
import Foundation

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("PASS  \(name)") }
    else { failed += 1; print("FAIL  \(name)  \(detail())") }
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
var rng = SplitMix64(state: 0xA7B0_5E0B)
func rnd(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { CGFloat.random(in: lo...hi, using: &rng) }
func rndDir() -> CGPoint { let a = rnd(0, 2 * .pi); return CGPoint(x: cos(a), y: sin(a)) }

// The radius INPUTS come from the app's own source (never mirrored); the
// formula that combines them is the extracted `GameConfig.Arena.radius`.
do {
    let env = ProcessInfo.processInfo.environment
    guard let arenaSrc = try? String(contentsOfFile: env["GEO_ARENACONFIG"] ?? "", encoding: .utf8),
          let deviceSrc = try? String(contentsOfFile: env["GEO_DEVICESCALE"] ?? "", encoding: .utf8) else {
        check("GR0 ArenaConfig.swift and DeviceScale.swift are readable", false)
        exit(1)
    }
    func number(after marker: String, then key: String, in text: String) -> CGFloat? {
        guard let m = text.range(of: marker),
              let k = text.range(of: key, range: m.upperBound..<text.endIndex) else { return nil }
        let digits = text[k.upperBound...].prefix { "0123456789.".contains($0) }
        return Double(digits).map { CGFloat($0) }
    }
    // v2.1 geometry Unit 4: the shell became the registered `splitworks` (same entry).
    let scale = number(after: "static let splitworks = ArenaConfig(", then: "radiusScale: ", in: arenaSrc)
    let phone = number(after: "static var arenaRadius: CGFloat {", then: " : ", in: deviceSrc)
    check("GR0 the Splitworks radiusScale and the phone arena radius are read from source",
          (scale ?? 0) > 0 && (phone ?? 0) > 0, "scale=\(String(describing: scale)) phone=\(String(describing: phone))")
    ArenaConfig.current = ArenaConfig(radiusScale: scale ?? 1)
    DeviceScale.arenaRadius = phone ?? 350
}

// GR1 — the EXECUTED radius (corrective 2). `GameConfig.Arena.radius` is the
// extracted production formula; its value for the Splitworks on a phone is
// pinned here, so a formula or tuning change fails on the value itself (a
// deliberate retune updates this pin).
check("GR1 the executed Splitworks arena radius on a phone is 402.5pt (the production formula, extracted)",
      abs(GameConfig.Arena.radius - 402.5) < 1e-6, "radius=\(GameConfig.Arena.radius)")

let r = GameConfig.Arena.radius
let geo = ArenaGeometry.splitworks
let travel = GameConfig.Geometry.projectileTravelRadius
guard let carrier = geo.blockedFootprints.first else {
    check("G1 the Splitworks has a Carrier footprint", false)
    print("\n\(passed) passed, \(failed) failed"); exit(1)
}
print("INFO  arena radius \(r)pt; Carrier half-extents \(carrier.halfExtents), corner \(carrier.cornerRadius)pt; travel radius \(travel)pt")

// G0 — open arenas: every query short-circuits (reconciliation §7.1).
do {
    let open = ArenaGeometry.open
    var bad = 0
    for _ in 0..<2000 {
        let p = CGPoint(x: rnd(-r, r), y: rnd(-r, r)), q = CGPoint(x: rnd(-r, r), y: rnd(-r, r))
        if open.isBlocked(p, margin: 20) || open.resolve(p, actorRadius: 14) != p
            || open.segmentBlocked(p, q, travelRadius: travel) || open.segmentBlockedExact(p, q, travelRadius: travel) { bad += 1 }
    }
    check("G0 an open arena blocks nothing, resolves nothing and occludes nothing (arenas 1–5 unchanged)",
          !open.hasBlockedGeometry && bad == 0, "bad=\(bad)")
}

// G1 — the authored layout.
do {
    let anchorsClear = geo.safeAnchors.allSatisfy { !geo.isBlocked($0.position, margin: 14) }
    check("G1 the Splitworks is exactly one Fallen Carrier, solid at its centre, with both safe anchors clear at a 14pt margin",
          geo.blockedFootprints.count == 1 && carrier.label == "fallen_carrier" && geo.isBlocked(carrier.center)
            && geo.safeAnchors.count == 2 && anchorsClear)
}

// G2 — resolve: every actor size ends clear; a valid point is returned unchanged.
do {
    var stuck: [String] = [], moved = 0, resolvedDeep = 0
    for a: CGFloat in [5.95, 10, 14, 26.4] {       // Spark at its smallest, Spark, an enemy, a mini-boss
        for _ in 0..<4000 {
            let p = carrier.center + rndDir() * rnd(0, carrier.boundingRadius + 40)
            let q = geo.resolve(p, actorRadius: a)
            let before = carrier.signedDistance(to: p), after = carrier.signedDistance(to: q)
            if after < a - 0.05 { stuck.append("a=\(a) p=\(p) sd=\(after)") }
            if before >= a, q != p { moved += 1 }
            if before < 0 { resolvedDeep += 1 }
        }
    }
    check("G2 resolve ends every actor (5.95/10/14/26.4pt) clear of the Carrier and leaves valid points untouched",
          stuck.isEmpty && moved == 0 && resolvedDeep > 0, "stuck=\(stuck.prefix(3)) moved=\(moved)")
}

// Ground truth for a segment: march it at 0.25pt and take the Carrier's
// smallest signed distance. Blocked iff that dips under the margin.
func bruteMin(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let n = max(1, Int(ceil(a.distance(to: b) / 0.25)))
    var best = CGFloat.greatestFiniteMagnitude
    for i in 0...n { best = min(best, carrier.signedDistance(to: a.lerp(to: b, t: CGFloat(i) / CGFloat(n)))) }
    return best
}

// G3 + G4 — the exact test is the truth; the stepped test is conservative but
// can miss a short segment past a rounded end.
do {
    var exactWrong: [String] = [], steppedOver = 0, holes = 0, shortestHole = CGFloat.greatestFiniteMagnitude
    var tested = 0
    while tested < 20000 {
        let mid = carrier.center + rndDir() * rnd(0, carrier.boundingRadius + 60)
        let len = rnd(5, 300)
        let d = rndDir()
        let a = mid - d * (len / 2), b = mid + d * (len / 2)
        let truth = bruteMin(a, b)
        if abs(truth - travel) < 0.2 { continue }          // tangent: the march can't decide
        tested += 1
        let blocked = truth < travel
        let exact = geo.segmentBlockedExact(a, b, travelRadius: travel)
        let stepped = geo.segmentBlocked(a, b, travelRadius: travel)
        if exact != blocked { exactWrong.append("len=\(len) truth=\(truth) exact=\(exact)") }
        if stepped && !blocked { steppedOver += 1 }
        if blocked && !stepped { holes += 1; shortestHole = min(shortestHole, len) }
    }
    check("G3 the exact segment test equals a dense 0.25pt march on 20,000 random segments (travel radius \(travel)pt)",
          exactWrong.isEmpty, "\(exactWrong.count) wrong: \(exactWrong.prefix(3))")
    check("G4 the stepped test never over-reports, and it misses short segments that clip a rounded end (why CL-109 uses the exact test)",
          steppedOver == 0 && holes > 0, "over=\(steppedOver) holes=\(holes)")
    print("INFO  stepped-test holes: \(holes) of 20000; shortest \(shortestHole)pt")
}

// G5 — the shared placement sampler never places inside the Carrier.
do {
    PlacementSampler.resetRejectionCount()
    var inside = 0
    for _ in 0..<5000 {
        let p = PlacementSampler.randomPoint(in: geo, minRadius: 0, maxRadius: r * 0.9, margin: 14)
        if geo.isBlocked(p, margin: 14 - 0.05) { inside += 1 }
    }
    check("G5 the shared placement sampler never returns a point inside the Carrier (14pt margin), and it does reject some",
          inside == 0 && PlacementSampler.rejectionCount > 0, "inside=\(inside) rejections=\(PlacementSampler.rejectionCount)")
}

// G5b — every candidate rejected (an annulus deep inside the Carrier): the
// fallback must still resolve out (internal review LOW-3).
do {
    var inside = 0
    for _ in 0..<200 {
        let p = PlacementSampler.randomPoint(in: geo, minRadius: 0, maxRadius: 5, margin: 14)
        if geo.isBlocked(p, margin: 14 - 0.05) { inside += 1 }
    }
    check("G5b the sampler's give-up fallback resolves out of the Carrier when every candidate is rejected",
          inside == 0 && geo.isBlocked(.zero, margin: 20), "inside=\(inside)")
}

// G6 — A7b S13 (CL-109 / CL-123a): arcs and hops take the nearest candidate
// with a clear EXACT segment (arc travel radius), else none. On the real
// Splitworks: the result always equals a brute force over the same candidates
// (filter by the exact test and the strict range, then the nearest, ties to the
// first); an occluded nearer target loses to a farther visible one; a field of
// occluded targets gives nil; and an open arena is plain nearest-within-range.
do {
    let arc = GameConfig.Geometry.arcTravelRadius
    struct Foe { let id: Int; let p: CGPoint }
    func brute(_ o: CGPoint, _ foes: [Foe], _ range: CGFloat, _ g: ArenaGeometry) -> Int? {
        var best: Foe?, bestD = range
        for f in foes where o.distance(to: f.p) < bestD && !g.segmentBlockedExact(o, f.p, travelRadius: arc) { best = f; bestD = o.distance(to: f.p) }
        return best?.id
    }
    var mismatches: [String] = [], occludedSkips = 0, nils = 0
    for trial in 0..<4000 {
        let o = carrier.center + rndDir() * rnd(carrier.boundingRadius * 0.6, carrier.boundingRadius + 120)
        guard !geo.isBlocked(o, margin: 3) else { continue }
        let foes = (0..<Int.random(in: 0...8)).map { Foe(id: $0, p: carrier.center + rndDir() * rnd(0, carrier.boundingRadius + 140)) }
            .filter { !geo.isBlocked($0.p, margin: 3) }
        let range = rnd(60, 260)
        let got = geo.nearestVisible(from: o, among: foes, position: { $0.p }, within: range, travelRadius: arc)?.id
        if got != brute(o, foes, range, geo) { mismatches.append("trial \(trial)") }
        if got == nil { nils += 1 }
        // The plain nearest is occluded and a farther one was chosen instead.
        if let plain = foes.filter({ o.distance(to: $0.p) < range }).min(by: { o.distance(to: $0.p) < o.distance(to: $1.p) }),
           geo.segmentBlockedExact(o, plain.p, travelRadius: arc), got != nil { occludedSkips += 1 }
    }
    // A hand-built case: the target straight through the Carrier is nearer, the
    // visible one is farther; and with only the hidden one, nothing.
    let west = carrier.center + CGPoint(x: -(carrier.boundingRadius + 30), y: 0)
    let east = carrier.center + CGPoint(x: carrier.boundingRadius + 30, y: 0)
    let span = west.distance(to: east)
    let hidden = Foe(id: 1, p: east), visible = Foe(id: 2, p: west + CGPoint(x: 0, y: span + 20))
    let far = west.distance(to: visible.p)
    let handOK = geo.segmentBlockedExact(west, east, travelRadius: arc) && span < far
        && geo.nearestVisible(from: west, among: [hidden, visible], position: { $0.p }, within: far + 1, travelRadius: arc)?.id == 2
        && geo.nearestVisible(from: west, among: [hidden], position: { $0.p }, within: far + 1, travelRadius: arc) == nil
        && ArenaGeometry.open.nearestVisible(from: west, among: [hidden, visible], position: { $0.p }, within: far + 1, travelRadius: arc)?.id == 1
    // Strict range and ties: exactly at the range is out; equal distances keep the first.
    let o = CGPoint(x: -r * 0.8, y: -r * 0.8)
    let tie = [Foe(id: 7, p: o + CGPoint(x: 50, y: 0)), Foe(id: 8, p: o + CGPoint(x: 0, y: 50))]
    let edgeOK = ArenaGeometry.open.nearestVisible(from: o, among: tie, position: { $0.p }, within: 50, travelRadius: arc) == nil
        && ArenaGeometry.open.nearestVisible(from: o, among: tie, position: { $0.p }, within: 50.001, travelRadius: arc)?.id == 7
    check("G6 A7b S13 nearestVisible: the nearest candidate with a clear exact segment, strictly within range, else none — equal to a brute force on 4,000 Splitworks fields; an occluded nearer target loses to a visible one; an open arena is plain nearest",
          mismatches.isEmpty && occludedSkips > 0 && nils > 0 && handOK && edgeOK && abs(arc - 3) < 1e-9,
          "mismatches=\(mismatches.count) skips=\(occludedSkips) nils=\(nils) hand=\(handOK) edge=\(edgeOK)")
}

// G7 — A7b S14 (CL-124a): THE path-tested shove (Guard's exact test + bisection,
// lifted into ArenaGeometry). From a free start: a clear path lands exactly on
// the target; a blocked one stops on the segment at a point whose own segment
// is clear, never inside the Carrier, and no more than one bisection step short
// of the blocked point; an open arena always lands on the target.
do {
    var wrong: [String] = [], stopped = 0, clearExact = 0
    for _ in 0..<6000 {
        let body: CGFloat = [5.95, 10, 14, 26.4].randomElement()!
        let from = carrier.center + rndDir() * rnd(carrier.boundingRadius * 0.5, carrier.boundingRadius + 80)
        guard carrier.signedDistance(to: from) >= body + 0.5 else { continue }
        let to = from + rndDir() * rnd(5, 220)
        let got = geo.pathShove(from: from, to: to, radius: body)
        if !geo.segmentBlockedExact(from, to, travelRadius: body) {
            if got != to { wrong.append("clear path moved: \(from)->\(to) got \(got)") } else { clearExact += 1 }
            continue
        }
        stopped += 1
        let t = (got - from).length / max((to - from).length, 1e-9)
        let onSegment = abs(((got - from).x * (to - from).y) - ((got - from).y * (to - from).x)) < 1e-3 * max(1, (to - from).length)
        let next = from + (to - from) * min(1, t + 1.0 / 64.0)
        if geo.segmentBlockedExact(from, got, travelRadius: body) { wrong.append("result path blocked") }
        if carrier.signedDistance(to: got) < body - 0.05 { wrong.append("ends inside: sd=\(carrier.signedDistance(to: got)) body=\(body)") }
        if !onSegment || t > 1 { wrong.append("off the segment") }
        if !geo.segmentBlockedExact(from, next, travelRadius: body) { wrong.append("stopped more than a step short (t=\(t))") }
    }
    let openOK = (0..<500).allSatisfy { _ in
        let a = CGPoint(x: rnd(-r, r), y: rnd(-r, r)), b = a + rndDir() * rnd(1, 200)
        return ArenaGeometry.open.pathShove(from: a, to: b, radius: 14) == b
    }
    check("G7 A7b S14 the shared path-tested shove: a clear path lands exactly on target; a blocked one stops on the segment, never inside the Carrier, within one bisection step of the block; open arenas never stop",
          wrong.isEmpty && stopped > 100 && clearExact > 100 && openOK,
          "wrong=\(wrong.count) \(wrong.prefix(3)) stopped=\(stopped) clear=\(clearExact) open=\(openOK)")
}

// G8 — A7b S14 (CL-124c): a persistent placement in a disc (a Wildbloom flower
// in its garden) is never in the Carrier or past the arena wall, by its margin;
// with every candidate rejected it returns the caller's valid fallback.
do {
    let margin = GameConfig.Growth.flowerRootMargin
    var bad = 0, fallbacks = 0
    PlacementSampler.resetRejectionCount()
    for _ in 0..<3000 {
        // Gardens near the Carrier and near the wall (where the bug lived).
        let c = Bool.random() ? carrier.center + rndDir() * rnd(0, carrier.boundingRadius + 60)
                              : rndDir() * rnd(r * 0.6, r)
        let zr = rnd(60, r * 0.55)
        let fb = CGPoint(x: 1e6, y: 1e6)   // a sentinel: counted, never valid
        let p = PlacementSampler.randomPoint(inDiscAt: c, radius: zr, in: geo, arenaRadius: r, margin: margin, fallback: fb)
        if p == fb { fallbacks += 1; continue }
        if geo.isBlocked(p, margin: margin - 0.05) || p.length + margin > r + 1e-6 || p.distance(to: c) > zr + 1e-6 { bad += 1 }
    }
    let rejected = PlacementSampler.rejectionCount
    let allRejected = PlacementSampler.randomPoint(inDiscAt: carrier.center, radius: 2, in: geo, arenaRadius: r,
                                                   margin: margin, fallback: CGPoint(x: 7, y: 9)) == CGPoint(x: 7, y: 9)
    check("G8 A7b S14 a persistent placement in a disc is never in the Carrier or past the arena wall (by its margin), stays in its disc, and falls back to the caller's point when every candidate is rejected",
          bad == 0 && rejected > 0 && allRejected && abs(margin - 10) < 1e-9,
          "bad=\(bad) rejected=\(rejected) fallbacks=\(fallbacks) allRejected=\(allRejected)")
}

// Recon fact (CL-123), informational: the shortest blocked segment between two
// points that are each clear for a 14pt enemy body.
do {
    var shortest = CGFloat.greatestFiniteMagnitude
    for _ in 0..<60000 {
        let a = carrier.center + rndDir() * rnd(0, carrier.boundingRadius + 30)
        guard carrier.signedDistance(to: a) >= 14 else { continue }
        let b = a + rndDir() * rnd(1, 120)
        guard carrier.signedDistance(to: b) >= 14 else { continue }
        if geo.segmentBlockedExact(a, b, travelRadius: travel) { shortest = min(shortest, a.distance(to: b)) }
    }
    print("INFO  shortest blocked segment between two 14pt-clear points: \(shortest)pt (60,000 samples)")
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
