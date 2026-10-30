import Foundation

/// Immutable per-run omission, distinct from the player's stored ban. Only
/// the explicit Debug traversal entry opts in; production palettes unchanged.
enum Arena9DraftPolicy {
    typealias Tag = UpgradeManager.Tag
    static var launchExclusions: Set<Tag> {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--arena9-traversal") { return [.growth] }
        #endif
        return []
    }
}
