// BGMDeck.swift
// Sparkforge
//
// v2.1 geometry Unit 4 — the ONE shuffled BGM deck (Brandon approved the
// shuffled deck; Oct 1 settled the rest — docs/arena6-geometry-reconciliation.md
// §5 Unit 4, audio subunit). Pure and generic so tools/bgm-harness executes it
// with a seeded generator; MusicManager drives it with URLs.
//
//   • every eligible track plays once per cycle before the next reshuffle;
//   • the deck lives for the APP SESSION: nothing resets it (not a run, not the
//     title) and nothing persists it (a relaunch reshuffles);
//   • a new cycle never OPENS with the track that just played (no back-to-back
//     repeat across the boundary) — it is swapped deeper into the new cycle;
//   • a draw is consumed when its playback STARTS (`started`). A track that
//     can't be OPENED is dropped for the session (`failed`) so it can't spin,
//     double-advance, or be counted as played; a start the SESSION refuses
//     (an interruption race) puts the track back at the front (`refused` →
//     `restore`) and the next transport event retries it (independent review
//     m2) — but the same track refused twice in a row is dropped, so a file
//     that opens yet never plays can't wedge the deck (re-review).
//
// BGMPolicy is MusicManager's transport table — which event resumes, which
// draws, which does nothing — pure, so the harness executes it (review m3).

struct BGMDeck<Track: Hashable> {
    /// Every track still eligible this session, in discovery order.
    private(set) var eligible: [Track]
    /// What's left of the current cycle; the next draw is `remaining.first`.
    private(set) var remaining: [Track] = []
    /// The last track that actually STARTED playing.
    private(set) var lastStarted: Track?
    /// Cycles begun so far (a reshuffle starts one).
    private(set) var cyclesStarted = 0
    /// The track the session refused last, if no track has started since.
    private(set) var lastRefused: Track?

    init(_ tracks: [Track]) {
        var seen = Set<Track>()
        eligible = tracks.filter { seen.insert($0).inserted }
    }

    var isEmpty: Bool { eligible.isEmpty }

    /// The next track of the current cycle, reshuffling at the boundary.
    mutating func draw<G: RandomNumberGenerator>(using rng: inout G) -> Track? {
        guard !eligible.isEmpty else { return nil }
        if remaining.isEmpty { reshuffle(using: &rng) }
        return remaining.isEmpty ? nil : remaining.removeFirst()
    }

    /// The drawn track began playing — it is the one a new cycle must not open with.
    mutating func started(_ track: Track) { lastStarted = track; lastRefused = nil }

    /// The session refused to start the drawn track. Once is a session hiccup:
    /// it goes back to the front for the next transport event (`restore`).
    /// The SAME track refused twice in a row is the file's fault: it's dropped
    /// for the session, so the deck can't wedge on it. Returns true if dropped.
    mutating func refused(_ track: Track) -> Bool {
        if lastRefused == track {
            failed(track)
            lastRefused = nil
            return true
        }
        restore(track)
        lastRefused = track
        return false
    }

    /// The drawn track was refused by the session, not broken: it goes back to
    /// the front of this cycle, unplayed.
    mutating func restore(_ track: Track) {
        guard eligible.contains(track), !remaining.contains(track) else { return }
        remaining.insert(track, at: 0)
    }

    /// The drawn track could not be opened: drop it for the rest of the session.
    mutating func failed(_ track: Track) {
        eligible.removeAll { $0 == track }
        remaining.removeAll { $0 == track }
    }

    private mutating func reshuffle<G: RandomNumberGenerator>(using rng: inout G) {
        remaining = eligible.shuffled(using: &rng)
        cyclesStarted += 1
        if remaining.count > 1, let last = lastStarted, remaining.first == last {
            remaining.swapAt(0, Int.random(in: 1..<remaining.count, using: &rng))
        }
    }
}

/// v2.1 geometry Unit 4 — MusicManager's transport rules as one table
/// (Brandon's settled plan: continuous across contexts, resume after
/// interruptions, the toggle and the foreground; a new draw only when a track
/// ends — or when nothing has started yet). A HOLD (the app in the
/// background, the run's pause menu up) pauses the song in place; while any
/// hold stands nothing resumes, starts or draws (Brandon's playtest, Oct 1).
enum BGMPolicy {
    enum Event { case contextChanged, toggledOn, toggledOff, held, released, interruptionEnded, becameActive, trackFinished, trackBroken }
    enum Action: Equatable {
        case none
        case startDeck   // nothing is playing yet: draw and fade in
        case resume      // the same song carries on where it was
        case pause       // fade out and keep the position
        case playNext    // the song ended (or broke): straight segue to the next draw
    }

    static func action(for event: Event, enabled: Bool, deferring: Bool, held: Bool, hasPlayer: Bool) -> Action {
        if event == .toggledOff || event == .held { return hasPlayer ? .pause : .none }
        guard enabled, !deferring, !held else { return .none }
        switch event {
        case .contextChanged:
            return hasPlayer ? .none : .startDeck
        case .toggledOn, .interruptionEnded, .becameActive, .released:
            return hasPlayer ? .resume : .startDeck
        case .trackFinished, .trackBroken:
            return .playNext
        case .toggledOff, .held:
            return .none
        }
    }
}
