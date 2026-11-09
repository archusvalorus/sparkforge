#if DEBUG
import Foundation

/// Explicit isolated comparison. Conflicting controlled/traversal flags fail
/// closed to a visibly conflict-disabled preview, never a hidden swarm.
enum Arena8MixedPressureMode {
    static func enabled(arguments: [String], sixRoom: Bool, isolated: Bool, arena9: Bool) -> Bool {
        let args = Set(arguments)
        return sixRoom && isolated && !arena9 && args.contains("--arena8-mixed-pressure")
            && args.isDisjoint(with: ["--arena8-natural-waves", "--arena8-lockmarshal", "--arena8-carrier-fixture", "--arena8-signaler-fixture", "--arena8-six-traversal", "--arena8-pressure-kiting", "--arena8-pressure-late"])
    }
    static func profile(arguments: [String]) -> Arena8PreviewSpawnClock.Profile {
        arguments.contains("--arena8-pressure-trial") ? .trial : .baseline
    }
}
#endif
