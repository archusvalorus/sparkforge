#if DEBUG
import Foundation
import CoreGraphics

extension GameConfig {
    /// Explicitly provisional technical fixture, not authored release tuning.
    enum Arena9TraversalLab {
        static let world = CGRect(x: -500, y: -350, width: 3000, height: 700)
        static let start = CGPoint(x: -350, y: 0)
        static let entries: [(id: String, x: CGFloat)] = [("entry", 0), ("final", 1400)]
        static let goal = CGRect(x: 2350, y: -120, width: 100, height: 240)
        static let fixtureEnemyXP = 1
        static let controlledSparkHP = 1000
        static var map: Arena8GameMap? {
            guard let stage = try? definition() else { return nil }
            return .openStage(world: stage.world, start: stage.start)
        }
        static let packetOffsets = [CGPoint(x: 200, y: -90), CGPoint(x: 260, y: 90)]
        static func definition() throws -> Arena9StageDefinition {
            try Arena9StageDefinition(world: world, start: start,
                encounters: entries.map { .init(id: $0.id, triggerX: $0.x) })
        }
    }
}
#endif
