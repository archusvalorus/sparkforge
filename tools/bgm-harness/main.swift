// main.swift — the BGM deck harness (v2.1 geometry Unit 4).
//
// Executes the REAL BGMDeck with seeded generators against the settled rules
// (docs/arena6-geometry-reconciliation.md §5 Unit 4, audio subunit), then checks
// the bundled tracks against the verified import map (tools/bgm-harness/
// import-map.csv, the Codex handoff's map with its SHA-256s):
//   BD1  every track exactly once per cycle;
//   BD2  the refill happens only at the boundary;
//   BD3  a new cycle never opens with the track that just played (and a
//        one-track deck still plays);
//   BD4  a failed start drops that track for the session — never drawn again,
//        never counted as played — and draws stay bounded; an empty deck is nil;
//   BD5  the opening track of a cycle is spread across the deck (no bias
//        beyond the one excluded repeat);
//   BD6  a start the session refuses keeps the track (review m2);
//   BP   MusicManager's transport table (BGMPolicy): continuous across contexts,
//        resume after the toggle / an interruption / the foreground, a new draw
//        only when a track ends, the retry after a refused start (review m3);
//        BP7 a hold (background, pause menu) pauses in place and keeps the
//        song silent until it lifts (Brandon's release playtest, Oct 1);
//   BA1  the bundle holds exactly the 20 mapped generic bgm_*.mp3 files, byte
//        for byte.
// Each validator prints PASS/FAIL; exit 1 on any FAIL.

import CryptoKit
import Foundation

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("PASS  \(name)") }
    else { failed += 1; print("FAIL  \(name)  \(detail())") }
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Play `cycles` full cycles of a fresh deck, every draw starting successfully.
func play(tracks: [Int], cycles: Int, seed: UInt64) -> (order: [Int], cyclesAt: [Int]) {
    var deck = BGMDeck(tracks), rng = SplitMix64(state: seed)
    var order: [Int] = [], cyclesAt: [Int] = []
    for _ in 0..<(cycles * tracks.count) {
        guard let t = deck.draw(using: &rng) else { break }
        deck.started(t)
        order.append(t)
        cyclesAt.append(deck.cyclesStarted)
    }
    return (order, cyclesAt)
}

let twenty = Array(0..<20)

// BD1 + BD2 + BD3 over many seeds.
do {
    var notPermutation = 0, boundaryWrong = 0, repeats = 0
    for seed in 1...300 as ClosedRange<UInt64> {
        let run = play(tracks: twenty, cycles: 25, seed: seed)
        for c in 0..<25 {
            let cycle = Array(run.order[(c * 20)..<((c + 1) * 20)])
            if Set(cycle) != Set(twenty) || cycle.count != 20 { notPermutation += 1 }
            if Set(run.cyclesAt[(c * 20)..<((c + 1) * 20)]) != [c + 1] { boundaryWrong += 1 }
            if c > 0, run.order[c * 20] == run.order[c * 20 - 1] { repeats += 1 }
        }
    }
    check("BD1 every track plays exactly once per cycle (300 seeds × 25 cycles of 20)", notPermutation == 0, "\(notPermutation) bad cycles")
    check("BD2 the deck refills only at the cycle boundary (every 20 draws, never mid-cycle)", boundaryWrong == 0, "\(boundaryWrong)")
    check("BD3 a new cycle never opens with the track that just played (7,200 boundaries)", repeats == 0, "\(repeats) repeats")
    let solo = play(tracks: [42], cycles: 5, seed: 9)
    check("BD3b a one-track deck still plays every cycle (nothing to swap with)", solo.order == [42, 42, 42, 42, 42], "\(solo.order)")
}

// BD4 — a failed start.
do {
    var deck = BGMDeck(twenty), rng = SplitMix64(state: 77)
    var drawn: [Int] = []
    var failedTrack: Int?
    var lastBeforeFail: Int?
    for i in 0..<(20 * 3) {
        guard let t = deck.draw(using: &rng) else { break }
        if i == 7 {
            lastBeforeFail = deck.lastStarted
            deck.failed(t)          // it never started
            failedTrack = t
            continue
        }
        deck.started(t)
        drawn.append(t)
    }
    let ft = failedTrack ?? -1
    let firstCycle = Array(drawn.prefix(19))
    check("BD4 a track that can't be opened is dropped for the session: never drawn again, never counted as played, the rest of its cycle intact",
          !drawn.contains(ft) && deck.eligible.count == 19 && !deck.eligible.contains(ft)
            && Set(firstCycle).count == 19 && Set(firstCycle) == Set(twenty).subtracting([ft])
            && lastBeforeFail != ft && drawn.count == 59,   // 60 draws, one failed start
          "failed=\(ft) drawn=\(drawn.count) eligible=\(deck.eligible.count)")
    var empty = BGMDeck<Int>([]), solo = BGMDeck([5])
    var r2 = SplitMix64(state: 1)
    let soloFirst = solo.draw(using: &r2)
    if let s = soloFirst { solo.failed(s) }
    check("BD4b an empty deck, or one whose only track failed, draws nil (no spin)",
          empty.draw(using: &r2) == nil && soloFirst == 5 && solo.draw(using: &r2) == nil && solo.isEmpty)
    let dup = BGMDeck([1, 2, 2, 3, 1])
    check("BD4c a duplicate asset is one track", dup.eligible == [1, 2, 3])
}

// BD5 — the cycle's opening track is spread across the deck.
do {
    var firsts = [Int](repeating: 0, count: 20)
    let run = play(tracks: twenty, cycles: 20_000, seed: 2026)
    for c in 0..<20_000 { firsts[run.order[c * 20]] += 1 }
    let shares = firsts.map { Double($0) / 20_000 }
    check("BD5 each track opens about 1/20 of cycles (every share within 0.03–0.07 over 20,000 cycles)",
          shares.allSatisfy { $0 > 0.03 && $0 < 0.07 }, "\(shares.map { String(format: "%.3f", $0) })")
}

// BD6 — a start the session REFUSES (not a broken file) puts the track back,
// unplayed and still eligible; the next draw is that same track (review m2).
do {
    var deck = BGMDeck(twenty), rng = SplitMix64(state: 5)
    let first = deck.draw(using: &rng) ?? -1
    deck.restore(first)                       // refused: not started, not failed
    let again = deck.draw(using: &rng) ?? -2
    deck.started(again)
    var rest: [Int] = []
    while rest.count < 19, let t = deck.draw(using: &rng) { deck.started(t); rest.append(t) }
    var noop = BGMDeck([1, 2]); var r = SplitMix64(state: 1)
    let n1 = noop.draw(using: &r) ?? 0
    noop.restore(n1); noop.restore(n1)        // twice: still one copy
    check("BD6 a refused start keeps the track: it's drawn next, the cycle still plays every track once, nothing is dropped, and restoring twice is one copy",
          again == first && deck.eligible.count == 20 && Set([again] + rest) == Set(twenty) && rest.count == 19
            && noop.remaining.filter { $0 == n1 }.count == 1, "first=\(first) again=\(again) rest=\(rest.count)")
    // The refusal rule (re-review): once keeps it, the SAME track refused twice
    // in a row is dropped (a file that opens but never plays can't wedge the
    // deck), a start in between resets the count, and a dropped track can never
    // be restored.
    var w = BGMDeck(twenty), rw = SplitMix64(state: 11)
    let t1 = w.draw(using: &rw) ?? -1
    let firstRefusal = w.refused(t1)
    let t2 = w.draw(using: &rw) ?? -2
    let secondRefusal = w.refused(t2)
    let afterDrop = w.draw(using: &rw) ?? -3
    var v = BGMDeck(twenty), rv = SplitMix64(state: 12)
    let u1 = v.draw(using: &rv) ?? -1
    _ = v.refused(u1)
    let u2 = v.draw(using: &rv) ?? -2
    v.started(u2)                              // it played after all
    let u3 = v.draw(using: &rv) ?? -3
    let thenRefused = v.refused(u3)            // a fresh hiccup, not a second strike
    var g = BGMDeck([1, 2, 3]), rg = SplitMix64(state: 13)
    let gd = g.draw(using: &rg) ?? 0
    g.failed(gd); g.restore(gd)
    check("BD6b refused once → kept; the same track refused twice in a row → dropped and the next is drawn; a start in between resets it; a dropped track can't be restored",
          !firstRefusal && t2 == t1 && secondRefusal && !w.eligible.contains(t1) && afterDrop != t1 && w.eligible.count == 19
            && u2 == u1 && !thenRefused && v.eligible.count == 20
            && !g.eligible.contains(gd) && !g.remaining.contains(gd),
          "first=\(firstRefusal) second=\(secondRefusal) t1=\(t1) t2=\(t2) after=\(afterDrop)")
}

// BP — MusicManager's transport table (BGMPolicy), every event × state.
do {
    typealias E = BGMPolicy.Event
    let all: [E] = [.contextChanged, .toggledOn, .toggledOff, .held, .released, .interruptionEnded, .becameActive, .trackFinished, .trackBroken]
    func a(_ e: E, enabled: Bool = true, deferring: Bool = false, held: Bool = false, playing: Bool) -> BGMPolicy.Action {
        BGMPolicy.action(for: e, enabled: enabled, deferring: deferring, held: held, hasPlayer: playing)
    }
    check("BP1 continuous: a context change never touches a song in progress, and only starts the deck when nothing has started",
          a(.contextChanged, playing: true) == .none && a(.contextChanged, playing: false) == .startDeck)
    check("BP2 resume, never a new draw: BGM ON, an ended interruption, returning to the foreground and the last hold lifting all resume the current song",
          [E.toggledOn, .interruptionEnded, .becameActive, .released].allSatisfy { a($0, playing: true) == .resume })
    check("BP3 with nothing started (e.g. a refused start), those same events start the deck — the retry",
          [E.toggledOn, .interruptionEnded, .becameActive, .released].allSatisfy { a($0, playing: false) == .startDeck })
    check("BP4 a new track is drawn only when one ends (or breaks)",
          a(.trackFinished, playing: false) == .playNext && a(.trackBroken, playing: false) == .playNext
            && all.filter { a($0, playing: true) == .playNext } == [.trackFinished, .trackBroken])
    check("BP5 BGM OFF pauses (keeping the position) whatever else holds, and with nothing playing does nothing",
          a(.toggledOff, playing: true) == .pause && a(.toggledOff, enabled: false, playing: true) == .pause
            && a(.toggledOff, deferring: true, playing: true) == .pause && a(.toggledOff, playing: false) == .none)
    check("BP6 disabled or deferring to the player's own audio: nothing else ever plays",
          all.filter { $0 != .toggledOff && $0 != .held }.allSatisfy { e in
              [true, false].allSatisfy { p in a(e, enabled: false, playing: p) == .none && a(e, deferring: true, playing: p) == .none } })
    // BP7 — the playtest fix: the song played on in the background and under
    // the pause menu. A hold pauses in place (like BGM OFF, whatever else
    // holds); while held, no event resumes, starts or draws — not an ended
    // interruption, not the foreground, not a finished track.
    check("BP7 a hold pauses the song in place, and while held nothing resumes, starts or draws",
          a(.held, playing: true) == .pause && a(.held, playing: false) == .none
            && a(.held, enabled: false, playing: true) == .pause && a(.held, deferring: true, playing: true) == .pause
            && all.filter { $0 != .toggledOff && $0 != .held }.allSatisfy { e in
                [true, false].allSatisfy { p in a(e, held: true, playing: p) == .none } }
            && a(.toggledOff, held: true, playing: true) == .pause && a(.held, held: true, playing: true) == .pause)
}

// BA1 — the bundle.
do {
    let env = ProcessInfo.processInfo.environment
    let dir = env["BGM_DIR"] ?? "", mapPath = env["BGM_MAP"] ?? ""
    let files = ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).filter { $0.hasPrefix("bgm_") }.sorted()
    let rows = ((try? String(contentsOfFile: mapPath, encoding: .utf8)) ?? "").split(separator: "\n").dropFirst()
        .map { $0.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) } }
    let expected = Dictionary(uniqueKeysWithValues: rows.compactMap { r in r.count >= 6 ? (r[3], r[4]) : nil })
    var wrong: [String] = []
    for f in files {
        guard let want = expected[f] else { wrong.append("unmapped \(f)"); continue }
        let data = (try? Data(contentsOf: URL(fileURLWithPath: dir).appendingPathComponent(f))) ?? Data()
        let got = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if got != want { wrong.append("hash \(f)") }
    }
    let generic = files.allSatisfy { $0.hasSuffix(".mp3") && !$0.hasPrefix("bgm_title_") && !$0.hasPrefix("bgm_boss_") && !$0.hasPrefix("bgm_run_") }
    check("BA1 the bundle holds exactly the 20 mapped generic bgm_*.mp3 tracks, byte for byte (the verified import map)",
          files.count == 20 && expected.count == 20 && Set(files) == Set(expected.keys) && wrong.isEmpty && generic,
          "files=\(files.count) mapped=\(expected.count) wrong=\(wrong.prefix(3))")
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
