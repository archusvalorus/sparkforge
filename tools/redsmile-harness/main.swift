// main.swift — deterministic validators for v2.1 abilities Unit A4c (Red
// Smile, the Bleed/Void bridge). Rulings: closure table §B3, CL-33…CL-48.
//   CP  active combat (CL-33)          RS  the 10s start-to-start cycle (CL-34)
//   SW  the form's melee clock (CL-42) KJ  kaiju priority (CL-44)
//   GF  FireClock freeze semantics — the mechanism CL-43 relies on (the scene's
//       guard itself is proven by the sim ledger's gunVolleysDuringForm = 0)
//   MS  body-radius-aware sector overlap (CL-41)   TB  the Carrier blocks it (CL-38)
//   RC  the card: dual gate, tags, copy (CL-45/48)   KS  kill credit
// Each validator prints PASS/FAIL; exit 1 on any FAIL. Everything is seeded
// except RC6/RC7, which sample the REAL card draw (its palette roll is random).

import CoreGraphics
import Foundation

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("PASS  \(name)") }
    else { failed += 1; print("FAIL  \(name)  \(detail())") }
}

func card(_ id: String, _ um: UpgradeManager) -> UpgradeManager.UpgradeCard {
    guard let c = um.allCards.first(where: { $0.id == id }) else { fatalError("missing card \(id)") }
    return c
}

// The approved numbers (Q-B4 / CL-34 / CL-15), mirrored here because the pure
// types take their tuning from the scene: 10s cycle, 3s form, 80pt, 110°.
let tuning = RedSmileState.Tuning(period: 10, duration: 3)
let reach: CGFloat = 80
let half: CGFloat = 110 * .pi / 360
// 1/64s frames: binary-exact, so boundary counts are deterministic.
let exact: TimeInterval = 1.0 / 64

struct Trace {
    var starts: [TimeInterval] = []
    var ends: [TimeInterval] = []
    var swings: [TimeInterval] = []
    /// Swings that landed inside each form, in order.
    var swingsPerForm: [Int] = []
}

/// Drive a RedSmileState for `seconds`; `t` is the frame's END time.
func simulate(_ s: inout RedSmileState, seconds: TimeInterval, dt: (Int) -> TimeInterval = { _ in exact },
              combat: (TimeInterval) -> Bool = { _ in true },
              kaiju: (TimeInterval) -> Bool = { _ in false },
              interval: (TimeInterval, TimeInterval?) -> TimeInterval = { _, _ in 0.5 }) -> Trace {
    var tr = Trace()
    var t: TimeInterval = 0, n = 0
    var formStart: TimeInterval?
    while t < seconds - 1e-12 {
        let step = dt(n); n += 1
        t += step
        let iv = interval(t, formStart.map { t - $0 })
        let out = s.tick(step, inCombat: combat(t), kaijuActive: kaiju(t), swingInterval: iv)
        if out.formEnded { tr.ends.append(t); formStart = nil }
        if out.formStarted { tr.starts.append(t); formStart = t; tr.swingsPerForm.append(0) }
        if out.swings > 0 {
            tr.swings.append(t)
            if !tr.swingsPerForm.isEmpty { tr.swingsPerForm[tr.swingsPerForm.count - 1] += out.swings }
        }
    }
    return tr
}

// ─────────────────────────────────────────────────────────────────────────────
// CP — active combat (CL-33): a hittable hostile exists; 0.5s linger.
do {
    var c = CombatPresence(linger: 0.5)
    check("CP1 inactive until a hostile exists; active the very frame one does",
          !c.isActive && c.update(exact, hostilePresent: true))
    // Lose the last hostile: holds for 0.5s, then drops (32 frames of 1/64).
    var held = 0
    for _ in 0..<31 { if c.update(exact, hostilePresent: false) { held += 1 } }
    let at32 = c.update(exact, hostilePresent: false)
    check("CP2 holds 0.5s after the last hostile, then drops (31 frames held, off on the 32nd)",
          held == 31 && !at32, "held=\(held) at32=\(at32)")

    var f = CombatPresence(linger: 0.5)
    f.update(exact, hostilePresent: true)
    var dropped = false
    for _ in 0..<10 {   // repeated 0.47s gaps, each bridged by one present frame
        for _ in 0..<30 { if !f.update(exact, hostilePresent: false) { dropped = true } }
        f.update(exact, hostilePresent: true)
    }
    check("CP3 a flicker shorter than the linger never toggles combat off", !dropped)

    var r = CombatPresence(linger: 0.5)
    r.update(exact, hostilePresent: true); r.reset()
    check("CP4 reset → out of combat", !r.isActive)
    var z = CombatPresence(linger: 0)
    z.update(exact, hostilePresent: true)
    check("CP5 a zero linger drops on the first frame without a hostile",
          !z.update(exact, hostilePresent: false))
}

// ─────────────────────────────────────────────────────────────────────────────
// RS — the cycle (CL-34).
do {
    var s = RedSmileState(tuning: tuning)
    let tr = simulate(&s, seconds: 31)
    check("RS1 the first form starts after exactly 10s of active combat",
          tr.starts.first.map { abs($0 - 10) < 1e-9 } ?? false, "starts=\(tr.starts)")
    check("RS2 start-to-start is 10s — the cycle counts through the form (10, 20, 30)",
          tr.starts.count == 3 && zip(tr.starts, [10.0, 20, 30]).allSatisfy { abs($0 - $1) < 1e-9 },
          "starts=\(tr.starts)")
    check("RS3 every form lasts exactly 3s", zip(tr.starts, tr.ends).allSatisfy { abs($1 - $0 - 3) < 1e-9 },
          "starts=\(tr.starts) ends=\(tr.ends)")

    // Lulls PAUSE, never reset: 6s fighting, 5s lull, then 4 more → t = 15.
    var p = RedSmileState(tuning: tuning)
    let lull = simulate(&p, seconds: 16, combat: { t in t <= 6 || t > 11 })
    check("RS4 a lull pauses the cycle without resetting it (6s + 5s lull + 4s → form at 15s)",
          lull.starts.first.map { abs($0 - 15) < 1e-9 } ?? false, "starts=\(lull.starts)")

    // A form runs its full 3s even when combat ends the instant it begins.
    var q = RedSmileState(tuning: tuning)
    let quiet = simulate(&q, seconds: 14, combat: { t in t <= 10 })
    check("RS5 a form always gets its full 3s, even if combat ends as it starts",
          quiet.starts.count == 1 && quiet.ends.count == 1
            && abs(quiet.ends[0] - quiet.starts[0] - 3) < 1e-9 && quiet.swingsPerForm == [6],
          "starts=\(quiet.starts) ends=\(quiet.ends) swings=\(quiet.swingsPerForm)")

    var never = RedSmileState(tuning: tuning)
    let idle = simulate(&never, seconds: 60, combat: { _ in false })
    check("RS6 no combat, no form — ever", idle.starts.isEmpty && never.cycleElapsed == 0)

    // The carry: on frames that don't divide 10s (0.03s), every start stays
    // within one frame of 10k — dropping the sub-frame overshoot would drift
    // later with every cycle.
    var drift = RedSmileState(tuning: tuning)
    let d = simulate(&drift, seconds: 61, dt: { _ in 0.03 })
    let late = zip(d.starts, [10.0, 20, 30, 40, 50, 60]).map { $0 - $1 }
    check("RS8 start-to-start never drifts: six starts each within one 0.03s frame of 10k",
          d.starts.count == 6 && late.allSatisfy { $0 >= -1e-9 && $0 < 0.03 + 1e-9 }, "late=\(late)")

    var reset = RedSmileState(tuning: tuning)
    _ = simulate(&reset, seconds: 11)
    reset.reset()
    check("RS7 death / restart: reset ends the form and zeroes the cycle",
          !reset.formActive && reset.cycleElapsed == 0 && reset.timeToNextForm == 10)
}

// ─────────────────────────────────────────────────────────────────────────────
// SW — the form's melee clock (CL-42).
do {
    var s = RedSmileState(tuning: tuning)
    let tr = simulate(&s, seconds: 13.5)
    let offsets = tr.swings.map { $0 - tr.starts[0] }
    check("SW1 six swings in a 3s form at the 0.5s base — the first on the form's first frame",
          tr.swingsPerForm == [6] && zip(offsets, [0.0, 0.5, 1.0, 1.5, 2.0, 2.5]).allSatisfy { abs($0 - $1) < 1e-9 },
          "swings=\(tr.swingsPerForm) at \(offsets)")

    for (label, fps) in [("30", 30.0), ("60", 60.0), ("120", 120.0)] {
        var r = RedSmileState(tuning: tuning)
        let run = simulate(&r, seconds: 13.5, dt: { _ in 1 / fps })
        check("SW2 six swings at \(label) fps", run.swingsPerForm == [6], "got \(run.swingsPerForm)")
    }
    // Jittered frames (seeded): 50–70 fps.
    var seed: UInt64 = 0x5eed
    func jitter(_ n: Int) -> TimeInterval {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return 1 / (50 + Double(seed >> 33 % 21))
    }
    var j = RedSmileState(tuning: tuning)
    let jit = simulate(&j, seconds: 34, dt: jitter)
    check("SW3 six swings per form on jittered 50–70 fps frames (three forms)",
          jit.swingsPerForm == [6, 6, 6], "got \(jit.swingsPerForm)")

    for (iv, want) in [(0.25, 12), (0.75, 4), (0.375, 8)] {
        var r = RedSmileState(tuning: tuning)
        let run = simulate(&r, seconds: 13.5, interval: { _, _ in iv })
        check("SW4 interval \(iv)s → \(want) swings (the shared rate, read as-is)",
              run.swingsPerForm == [want], "got \(run.swingsPerForm)")
    }

    // The interval is read LIVE: Frenzy lands 1.25s into the form (0.5 → 0.25).
    var live = RedSmileState(tuning: tuning)
    let fz = simulate(&live, seconds: 13.5, interval: { _, since in (since ?? 0) >= 1.25 - 1e-9 ? 0.25 : 0.5 })
    check("SW5 a mid-form attack-speed change is read at once (0,.5,1,1.25…2.75 = 10 swings)",
          fz.swingsPerForm == [10], "got \(fz.swingsPerForm)")

    // No minimum interval (CL-42): 3/64s swings every 3 frames → 64 in the form.
    var fast = RedSmileState(tuning: tuning)
    let quick = simulate(&fast, seconds: 13.5, interval: { _, _ in 3.0 / 64 })
    check("SW6 no swing floor in A4c: a 0.047s interval really swings 64 times (a 0.10s floor would give 30)",
          quick.swingsPerForm == [64], "got \(quick.swingsPerForm)")

    // Bounded remainder: a 0.1s hitch (the scene's dt clamp) releases ONE swing.
    var hitch = RedSmileState(tuning: tuning)
    let tr2 = simulate(&hitch, seconds: 10.2)                  // form started at 10
    let before = tr2.swings.count
    let out = hitch.tick(0.1, inCombat: true, kaijuActive: false, swingInterval: 0.02)
    check("SW7 a long frame releases at most one swing — no volley", out.swings == 1 && before == 1,
          "before=\(before) out=\(out.swings)")

    // Negative control: a naive loop that swings BEFORE checking the end would
    // add a 7th swing on the 3.0s boundary — the ordering SW1 protects.
    var naiveSwings = 1, formLeft: TimeInterval = 3, clock: TimeInterval = 0
    while formLeft > 0 {
        clock += exact
        if clock >= 0.5 { clock -= 0.5; naiveSwings += 1 }
        formLeft -= exact
    }
    check("SW8 negative control: swing-then-end ordering yields 7 (so SW1's 6 is a real check)",
          naiveSwings == 7, "naive=\(naiveSwings)")
}

// ─────────────────────────────────────────────────────────────────────────────
// KJ — kaiju priority (CL-44).
do {
    // Kaiju during a form: the scene calls interrupt() at once.
    var s = RedSmileState(tuning: tuning)
    _ = simulate(&s, seconds: 11)                                // form live since 10
    let cycleBefore = s.cycleElapsed
    check("KJ1 interrupt() ends a live form at once and leaves the cycle alone",
          s.interrupt() && !s.formActive && s.cycleElapsed == cycleBefore && !s.interrupt())

    // While the kaiju is up: cycle paused, nothing begins, banks or queues.
    var k = RedSmileState(tuning: tuning)
    let tr = simulate(&k, seconds: 30, kaiju: { t in t > 9 && t <= 19 })
    check("KJ2 the cycle pauses under the kaiju, then resumes from what's left (9s + kaiju 10s + 1s → 20s)",
          tr.starts.first.map { abs($0 - 20) < 1e-9 } ?? false, "starts=\(tr.starts)")

    var q = RedSmileState(tuning: tuning)
    let queued = simulate(&q, seconds: 26,
                          combat: { t in t <= 9.5 || t > 25 },
                          kaiju: { t in t > 9.5 && t <= 20 })
    check("KJ3 nothing is banked or queued: a kaiju then a lull, and the form waits for 0.5s more combat",
          queued.starts.first.map { abs($0 - 25.5) < 1e-9 } ?? false, "starts=\(queued.starts)")

    var belt = RedSmileState(tuning: tuning)
    _ = simulate(&belt, seconds: 11)
    let step = belt.tick(exact, inCombat: true, kaijuActive: true, swingInterval: 0.5)
    check("KJ4 belt and braces: a tick under the kaiju ends a live form and swings nothing",
          step.formEnded && step.swings == 0 && !step.formStarted && !belt.formActive)
}

// ─────────────────────────────────────────────────────────────────────────────
// GF — the gun during the form (CL-43): the scene simply doesn't advance its
// FireClock while the form holds. Freezing preserves the remainder, builds no
// debt, and the gun resumes from exactly there.
do {
    var gun = FireClock()
    _ = gun.advance(0.25, interval: 0.5, hasTarget: { true })    // 0.25 banked when the form begins
    // …3s of form: never advanced…
    let first = gun.advance(0.125, interval: 0.5, hasTarget: { true })
    let second = gun.advance(0.125, interval: 0.5, hasTarget: { true })
    check("GF1 FireClock: frozen, not reset: 0.25 banked + 0.25 after the form = exactly one shot, on time",
          !first && second && gun.elapsed == 0, "elapsed=\(gun.elapsed)")
    var thaw = FireClock()
    _ = thaw.advance(0.25, interval: 0.5, hasTarget: { true })
    // …3s frozen…
    let fired = thaw.advance(exact, interval: 0.5, hasTarget: { true })
    check("GF2 FireClock: no debt: the frozen 3s never counted — one frame later only 0.25 + 1/64 is banked",
          !fired && thaw.elapsed == 0.25 + exact, "elapsed=\(thaw.elapsed)")
}

// ─────────────────────────────────────────────────────────────────────────────
// MS — body-radius-aware sector overlap (CL-41).
do {
    let o = CGPoint.zero, up = CGPoint(x: 0, y: 1)
    func hit(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, facing: CGPoint = up) -> Bool {
        MeleeSector.overlaps(origin: o, facing: facing, halfAngle: half, reach: reach,
                             center: CGPoint(x: x, y: y), radius: r)
    }
    func polar(_ deg: CGFloat, _ d: CGFloat) -> (CGFloat, CGFloat) {   // degrees off the facing (up)
        let a = (90 - deg) * .pi / 180
        return (cos(a) * d, sin(a) * d)
    }
    check("MS1 reach is measured to the BODY: surface at 79pt hits, surface at 83pt misses",
          hit(0, 91, 12) && !hit(0, 95, 12))
    let (ax, ay) = polar(54, 50), (bx, by) = polar(56, 50), (cx, cy) = polar(60, 50)
    check("MS2 the arc is ±55°: a point body at 54° hits, at 56° misses",
          hit(ax, ay, 0) && !hit(bx, by, 0))
    check("MS3 a body whose centre sits outside the arc still counts when it overlaps an edge (60°, r 12 hits; r 3 misses)",
          hit(cx, cy, 12) && !hit(cx, cy, 3))
    let (lx, ly) = polar(-60, 50)
    check("MS4 both edges behave the same (mirror of MS3)", hit(lx, ly, 12) && !hit(lx, ly, 3))
    check("MS5 behind Spark misses; a body swallowing the apex hits",
          !hit(0, -30, 12) && hit(0, -8, 12))
    let (gx, gy) = polar(56, 90)
    check("MS6 a body grazing the arc's corner (56°, 90pt, r 12) hits", hit(gx, gy, 12))
    check("MS7 a zero facing falls back to straight up",
          MeleeSector.overlaps(origin: o, facing: .zero, halfAngle: half, reach: reach,
                               center: CGPoint(x: 0, y: 50), radius: 0)
            && MeleeSector.unit(.zero) == up)

    // The Unmade Star (surface radius ≈ 335): hit when its footprint genuinely
    // overlaps, with no special case.
    let star: CGFloat = 335
    let (sx, sy) = polar(70, 380)
    let starAhead = hit(0, 400, star), starFar = hit(0, 420, star), starSide = hit(sx, sy, star)
    check("MS8 the Unmade Star: surface 65pt ahead hits, 85pt misses, and its flank at 70° (surface 45pt) hits",
          starAhead && !starFar && starSide)
    // Negative control: a centre-only test (centre within reach and arc) misses
    // every Star case above — which is why the body test exists.
    func centreOnly(_ x: CGFloat, _ y: CGFloat) -> Bool {
        let d = (x * x + y * y).squareRoot()
        return d <= reach && acos(max(-1, min(1, y / max(d, 1e-9)))) <= half
    }
    check("MS9 negative control: a centre-only test would miss the Star entirely",
          !centreOnly(0, 400) && !centreOnly(sx, sy))

    // Oracle: brute-force distance from the body's centre to a dense polar
    // sampling of the sector; overlap ⇔ that distance ≤ radius. Cases within
    // the sampling error of the boundary are skipped.
    var rng: UInt64 = 0xA4C
    func unitRand() -> CGFloat {
        rng = rng &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(rng >> 11) / CGFloat(1 << 53)
    }
    var samples: [CGPoint] = []
    var rr: CGFloat = 0
    while rr <= reach { var a = -half; while a <= half + 1e-9 {
        samples.append(CGPoint(x: -sin(a) * rr, y: cos(a) * rr)); a += 0.5 * .pi / 180 }; rr += 0.5 }
    var agree = 0, disagree: [String] = [], skipped = 0
    for i in 0..<1500 {
        let big = i % 5 == 0
        let span: CGFloat = big ? 700 : 180
        let c = CGPoint(x: (unitRand() * 2 - 1) * span, y: (unitRand() * 2 - 1) * span)
        let r = big ? 200 + unitRand() * 200 : unitRand() * 40
        let face = MeleeSector.unit(CGPoint(x: unitRand() * 2 - 1, y: unitRand() * 2 - 1))
        // Rotate the case into the "up" frame so the samples stay fixed.
        let ang = atan2(face.x, face.y)
        let local = CGPoint(x: c.x * cos(ang) - c.y * sin(ang), y: c.x * sin(ang) + c.y * cos(ang))
        var best = CGFloat.greatestFiniteMagnitude
        for p in samples { let dx = p.x - local.x, dy = p.y - local.y; best = min(best, dx * dx + dy * dy) }
        best = best.squareRoot()
        if abs(best - r) < 1.0 { skipped += 1; continue }
        let truth = best <= r
        let got = MeleeSector.overlaps(origin: o, facing: face, halfAngle: half, reach: reach, center: c, radius: r)
        if got == truth { agree += 1 } else if disagree.count < 5 { disagree.append("c=\(c) r=\(r) face=\(face)") }
    }
    check("MS10 agrees with a brute-force oracle on \(agree) random bodies, big and small (\(skipped) boundary cases skipped)",
          disagree.isEmpty && agree > 1300, "\(disagree)")
}

// ─────────────────────────────────────────────────────────────────────────────
// TB — the Carrier blocks the sweep (CL-38), exactly. The Splitworks Carrier at
// its live radius (350 × 1.15): centre (0.10r, 0.04r), half-extents
// (0.16r, 0.34r), corner 0.06r, rotated −0.21.
do {
    let r: CGFloat = 350 * 1.15
    let center = CGPoint(x: 0.10 * r, y: 0.04 * r)
    let halfExt = CGSize(width: 0.16 * r, height: 0.34 * r)
    let corner: CGFloat = 0.06 * r, rot: CGFloat = -0.21, travel: CGFloat = 3
    func exact(_ a: CGPoint, _ b: CGPoint) -> Bool {
        MeleeSector.segmentCrossesRoundedBox(a, b, center: center, halfExtents: halfExt,
                                             cornerRadius: corner, rotation: rot, margin: travel)
    }
    // The footprint's own SDF (ArenaGeometry.Footprint.signedDistance), restated.
    func sdf(_ p: CGPoint) -> CGFloat {
        let x = p.x - center.x, y = p.y - center.y
        let c = cos(-rot), s = sin(-rot)
        let lx = x * c - y * s, ly = x * s + y * c
        let qx = abs(lx) - halfExt.width, qy = abs(ly) - halfExt.height
        return (max(qx, 0) * max(qx, 0) + max(qy, 0) * max(qy, 0)).squareRoot() + min(max(qx, qy), 0) - corner
    }
    // The legacy march `segmentBlocked` uses (step = min half-extent + corner).
    func legacy(_ a: CGPoint, _ b: CGPoint) -> Bool {
        let minHalf = max(4, min(halfExt.width, halfExt.height) + corner)
        let len = ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
        let steps = max(1, Int(ceil(len / minHalf)))
        return (0...steps).contains { i in
            let t = CGFloat(i) / CGFloat(steps)
            return sdf(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)) < travel
        }
    }
    // The review's counterexample: Spark 10pt off the north end, an enemy 14pt
    // off the east face, the line between them cutting the rounded corner.
    let spark = CGPoint(x: 129.7, y: 171.9), foe = CGPoint(x: 164.5, y: 107.2)
    check("TB1 a sweep past the Carrier's rounded corner is BLOCKED (the case the stepped test missed)",
          sdf(spark) > travel && sdf(foe) > travel && exact(spark, foe))
    check("TB2 negative control: the legacy stepped march lets that same segment through",
          !legacy(spark, foe))
    check("TB3 straight through the slab is blocked; a clear lane beside it is not",
          exact(CGPoint(x: -120, y: 16), CGPoint(x: 200, y: 16))
            && !exact(CGPoint(x: -150, y: -60), CGPoint(x: -150, y: 60)))

    // Oracle: march every random short segment at 0.1pt with the SDF itself.
    var rng: UInt64 = 0xCA221E5
    func unit() -> CGFloat {
        rng = rng &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(rng >> 11) / CGFloat(1 << 53)
    }
    var agree = 0, skipped = 0, wrong: [String] = []
    for _ in 0..<3000 {
        let a = CGPoint(x: center.x + (unit() * 2 - 1) * 260, y: center.y + (unit() * 2 - 1) * 260)
        let ang = unit() * 2 * .pi, len = 10 + unit() * 110
        let b = CGPoint(x: a.x + cos(ang) * len, y: a.y + sin(ang) * len)
        var minD = CGFloat.greatestFiniteMagnitude
        let n = Int(len / 0.1)
        for i in 0...n { let t = CGFloat(i) / CGFloat(n); minD = min(minD, sdf(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))) }
        if abs(minD - travel) < 0.25 { skipped += 1; continue }
        if exact(a, b) == (minD < travel) { agree += 1 } else if wrong.count < 5 { wrong.append("a=\(a) b=\(b)") }
    }
    check("TB4 agrees with a 0.1pt SDF march on \(agree) random short segments around the Carrier (\(skipped) boundary cases skipped)",
          wrong.isEmpty && agree > 2900, "\(wrong)")
}

// ─────────────────────────────────────────────────────────────────────────────
// RC — the card (CL-45 tree identity, CL-48 copy, the dual signature gate).
do {
    let um = UpgradeManager()
    guard let red = um.allCards.first(where: { $0.id == "v18_red_smile" }) else { fatalError("Red Smile missing") }
    check("RC1 Red Smile is Bleed with a Void secondary tag, requiring BOTH signatures",
          red.tag == .bleed && red.secondaryTag == .voidT
            && red.requires == [.bleedUnlocked, .voidUnlocked] && red.provides.isEmpty && !red.isCapstone)
    check("RC2 card face is the ruled line, verbatim (CL-48)",
          red.description == "Every 10s: 3s of Void melee. 2× damage + Bleed.")
    let approved = "Every 10s in combat, become the Thing From Below for 3s. Replace projectile attacks with sweeping melee attacks that deal 200% of projectile damage as Void damage and always inflict Bleed. Requires both Bleed and Void signatures. Existing projectiles remain active during transformation."
    let added = "Sweeps strike in your last move direction. They count as primary hits, not shots or projectiles."
    check("RC3 detail = the approved copy, then the ruled addition — and never 'carry your on-hit effects'",
          red.detail == approved + " " + added && !(red.detail ?? "").contains("on-hit"))
    func lines(_ text: String) -> Int {
        var n = 0, cur = 0
        for w in text.split(separator: " ") {
            if cur == 0 { cur = w.count; n += 1 } else if cur + 1 + w.count <= 17 { cur += 1 + w.count } else { cur = w.count; n += 1 }
        }
        return n
    }
    check("RC4 the face fits 3 lines of 17 beside the MORE chip", lines(red.description) <= 3,
          "lines=\(lines(red.description))")
    check("RC5 still one card, one pool entry: Bleed 13 (by primary tag), pool 80 (A6: −Mass Tax +Void Horror +Shadow Edge, CL-83)",
          um.allCards.filter { $0.tag == .bleed }.count == 13 && um.allCards.count == 80,
          "bleed=\(um.allCards.filter { $0.tag == .bleed }.count) pool=\(um.allCards.count)")

    // The dual gate through the REAL draw: a run with both colours active.
    func runWithBoth() -> UpgradeManager {
        for _ in 0..<500 {
            let run = UpgradeManager()
            if run.activeFamilies.contains(.bleed) && run.activeFamilies.contains(.voidT) { return run }
        }
        fatalError("500 palette rolls never activated Bleed and Void together")
    }
    func offered(_ run: UpgradeManager, draws: Int) -> Bool {
        for level in 0..<draws where run.drawCards(count: 3, level: 2 + level % 20).contains(where: { $0.id == "v18_red_smile" }) {
            return true
        }
        return false
    }
    var bleedOnlyLeaks = 0, voidOnlyLeaks = 0, bothOffered = 0
    for _ in 0..<12 {
        let a = runWithBoth(), sa = PlayerStats()
        a.pickCard(card("v21_bloodthirsty", a), stats: sa, level: 1)
        if offered(a, draws: 150) { bleedOnlyLeaks += 1 }
        let b = runWithBoth(), sb = PlayerStats()
        b.pickCard(card("void_3", b), stats: sb, level: 1)
        if offered(b, draws: 150) { voidOnlyLeaks += 1 }
        a.pickCard(card("void_3", a), stats: sa, level: 2)
        if offered(a, draws: 400) { bothOffered += 1 }
    }
    check("RC6 never offered with only the Bleed signature, or only the Void signature",
          bleedOnlyLeaks == 0 && voidOnlyLeaks == 0, "bleedOnly=\(bleedOnlyLeaks) voidOnly=\(voidOnlyLeaks)")
    check("RC7 offered once both signatures are held (12 of 12 runs)", bothOffered == 12, "got \(bothOffered)")

    // CL-45: one pick feeds BOTH ladders; apply / reset own the flag.
    let run = runWithBoth(), stats = PlayerStats()
    run.pickCard(card("v21_bloodthirsty", run), stats: stats, level: 1)
    run.pickCard(card("void_3", run), stats: stats, level: 2)
    let bleedBefore = run.tagCounts[.bleed] ?? 0, voidBefore = run.tagCounts[.voidT] ?? 0
    run.pickCard(card("v18_red_smile", run), stats: stats, level: 3)
    check("RC8 picking it counts once toward Bleed AND once toward Void",
          run.tagCounts[.bleed] == bleedBefore + 1 && run.tagCounts[.voidT] == voidBefore + 1)
    check("RC9 its apply owns the form; reset clears it", {
        let owned = stats.redSmileOwned
        stats.reset()
        return owned && !stats.redSmileOwned
    }())
}
// ─────────────────────────────────────────────────────────────────────────────
// MC — corrective F1/F2 (CL-39): every LANDED contact — an ordinary enemy hit,
// a Shatter, or the boss — gives each hit meter ONE registration opportunity,
// through the production method `RedSmileContact.chargeHitMeters` (the scene
// routes all three contact sites through it, then into the meters' existing
// methods). The meters' cooldown/capacity live in those methods; the in-engine
// proof of them on the real paths is the DEBUG ledger (return packet).
do {
    func asks(_ c: RedSmileContact) -> (apex: Int, erasure: Int) {
        var a = 0, e = 0
        c.chargeHitMeters(apex: { a += 1 }, erasure: { e += 1 })
        return (a, e)
    }
    check("MC1 three contact kinds, and each asks EACH meter exactly once — no duplicate registration",
          RedSmileContact.allCases == [.enemy, .shatter, .boss]
            && RedSmileContact.allCases.allSatisfy { asks($0) == (1, 1) })
    check("MC2 F1: a boss contact charges Apex (and Erasure) on its own — a boss-only swing needs no enemy contact",
          asks(.boss) == (1, 1))
    check("MC3 F2: a Shatter contact charges Apex and Erasure on its own — no other target needed",
          asks(.shatter) == (1, 1))

    // The meters decide: modelled with the production guard (active, cooldown
    // elapsed, below capacity; Apex 0.2s / 4, Erasure 0.15s / 4). The contact
    // plan never retries or forces a rejected charge.
    struct Meter { var stacks = 0, timer: TimeInterval = 0; let cap: Int, cooldown: TimeInterval
        mutating func register() { guard timer <= 0, stacks < cap else { return }; stacks += 1; timer = cooldown }
        mutating func tick(_ dt: TimeInterval) { timer -= dt } }
    var apex = Meter(cap: 4, cooldown: 0.2), erasure = Meter(cap: 4, cooldown: 0.15)
    // One swing striking the boss AND two enemies in the same frame: the
    // cooldown lets exactly one charge through per meter.
    for c in [RedSmileContact.boss, .enemy, .shatter] { c.chargeHitMeters(apex: { apex.register() }, erasure: { erasure.register() }) }
    let sameFrame = (apex.stacks, erasure.stacks)
    // Boss-only swings every 0.5s: one charge per swing until capacity, then none.
    for _ in 0..<8 { apex.tick(0.5); erasure.tick(0.5)
        RedSmileContact.boss.chargeHitMeters(apex: { apex.register() }, erasure: { erasure.register() }) }
    check("MC4 cooldown and capacity stay authoritative: a 3-contact swing gains 1 per meter; boss-only swings fill to 4 and stop",
          sameFrame == (1, 1) && apex.stacks == 4 && erasure.stacks == 4, "sameFrame=\(sameFrame) apex=\(apex.stacks) erasure=\(erasure.stacks)")
}

// ─────────────────────────────────────────────────────────────────────────────
// KS — kill credit.
check("KS1 a melee kill is FULL credit (on-kill effects, bestiary, gates); the prune stays reward-only",
      KillSource.melee.credit == .full && KillSource.sweep.credit == .rewardOnly
        && KillSource(rawValue: "melee") == .melee)

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
