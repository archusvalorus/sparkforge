// GameTimer.swift
// Sparkforge
//
// v2.1 Abilities A0: status and effect timers run on GAME time.
//
// GameScene's update hands every system a clamped dt and returns early unless
// the run is `.playing`, so anything ticked from there stops under the pause
// menu, the level-up screen and the boss reveal. SKAction waits do NOT: pause
// and level-up only change `gameState` — the world node keeps running — so an
// SKAction-timed debuff silently expires while the player is picking a card.
// Gameplay state uses these; SKActions stay for pure visuals.

import Foundation

/// A countdown that only moves when it is ticked.
struct GameTimer {
    private(set) var remaining: TimeInterval = 0

    var isActive: Bool { remaining > 0 }

    /// Start (or restart) at `duration`, replacing what is left.
    mutating func start(_ duration: TimeInterval) {
        remaining = max(0, duration)
    }

    /// Keep whichever is longer — the existing status convention
    /// (`slowTimer = max(slowTimer, duration)`).
    mutating func extend(atLeast duration: TimeInterval) {
        remaining = max(remaining, duration)
    }

    /// Float dust left by summing frame deltas (sixty 0.05s ticks don't quite
    /// make 3.0). Anything this close to zero has run out.
    private static let epsilon: TimeInterval = 1e-9

    /// Advance by `dt`. Returns true on the tick the timer runs out.
    @discardableResult
    mutating func tick(_ dt: TimeInterval) -> Bool {
        guard remaining > 0 else { return false }
        remaining -= dt
        if remaining <= Self.epsilon {
            remaining = 0
            return true
        }
        return false
    }

    mutating func cancel() {
        remaining = 0
    }
}

/// A window that opens after a delay and closes after its duration, both on
/// game time — e.g. Polar Vortex's Frostbite, which begins when the freeze
/// ends.
struct DelayedWindow {
    enum Event: Equatable { case none, opened, closed }
    private enum Phase { case idle, pending, open }

    private var phase = Phase.idle
    private var timer = GameTimer()
    private var duration: TimeInterval = 0

    var isOpen: Bool { phase == .open }
    var isPending: Bool { phase == .pending }

    /// Schedule, replacing whatever was pending or open. The window opens on
    /// the first tick at or after `delay`, then stays open for `duration`.
    mutating func schedule(after delay: TimeInterval, lasting duration: TimeInterval) {
        self.duration = max(0, duration)
        phase = .pending
        timer.start(delay)
    }

    /// Advance by `dt`; reports the edge crossed this tick (at most one).
    mutating func tick(_ dt: TimeInterval) -> Event {
        switch phase {
        case .idle:
            return .none
        case .pending:
            timer.tick(dt)
            guard !timer.isActive else { return .none }
            phase = .open
            timer.start(duration)
            return .opened
        case .open:
            timer.tick(dt)
            guard !timer.isActive else { return .none }
            phase = .idle
            return .closed
        }
    }

    mutating func cancel() {
        phase = .idle
        timer.cancel()
    }
}
