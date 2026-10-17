import Foundation
import CoreGraphics
// Stand-ins only for the scene/SDK objects; logic is extracted from live files.
enum GameConfig {
    enum Wave { static let miniBossSpawnTime: TimeInterval = 90 }
}
final class ProgressionManager {
    static let shared = ProgressionManager()
    var arenasUnlocked = 6
    var currentArena = 0
}
final class GeometryDebug {
    static let showOverlay = false
    var routeDirectResumes = 0
    var routeRecoveries = 0
    var routeDecisions = 0
    var routeFallbacks = 0
}
class EnemyNode {
    var position = CGPoint.zero
    var geometryFootprintRadius: CGFloat = 14
    var routeNodeID: Int?
    var routePrevNodeID: Int?
    var routeRedecideCooldown: TimeInterval = 0
    var isOccludedFromGoal = false
    var goalPosition = CGPoint.zero
    var moveSpeed: CGFloat
    var currentSlow: CGFloat = 0
    var isStunned = false
    var isFrozen = false
    init(health: Int, moveSpeed: CGFloat, xpValue: Int) { self.moveSpeed = moveSpeed }
    func routeNodeBias(_ node: RouteNode, goal: CGPoint, occupancy: Int) -> CGFloat { 0 }
}
final class TollkeeperNode: EnemyNode { var attackRect: CGRect? { nil } }
final class RailspikeNode: EnemyNode { var attackRect: CGRect? { nil } }
final class EnemyProjectileNode { var channelRailRect: CGRect? }
final class WorldNode { func addChild(_ node: EnemyNode) {} }
