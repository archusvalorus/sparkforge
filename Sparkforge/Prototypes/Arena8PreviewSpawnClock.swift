// Preview-owned attempt scheduler. Does not own game time, stats or rewards.
import Foundation

struct Arena8PreviewSpawnClock {
    enum Profile: String, CaseIterable {
        case baseline, trial
        var intervalScale: TimeInterval { self == .trial ? 0.8 : 1 }
        var label: String { self == .trial ? "+25% TRIAL" : "BASELINE" }
    }
    let profile: Profile
    private(set) var accumulated: TimeInterval = 0
    private(set) var attempts = 0

    init(profile: Profile) { self.profile = profile }
    func interval(base: TimeInterval) -> TimeInterval? {
        guard base.isFinite, base > 0 else { return nil }
        let value = base * profile.intervalScale
        return value.isFinite && value > 0 ? value : nil
    }
    /// Same reset-to-zero, at-most-one-attempt semantics as WaveManager.
    /// Ability suppression consumes emitted attempts in the Scene; no queue.
    @discardableResult mutating func advance(dt: TimeInterval, baseInterval: TimeInterval,
                                             held: Bool = false) -> Bool {
        guard !held, dt.isFinite, dt >= 0,
              let interval = interval(base: baseInterval),
              (accumulated + dt).isFinite else { return false }
        accumulated += dt
        guard accumulated >= interval else { return false }
        accumulated = 0
        attempts += 1
        return true
    }
}
