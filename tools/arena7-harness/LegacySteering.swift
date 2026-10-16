// Frozen executable steering reference from fb680ef608ffc2c86cee862b18698f4d9bfd50a1.
import Foundation
import CoreGraphics
extension GameScene {
    func legacyRouteSteerTarget(for enemy: EnemyNode, toward goal: CGPoint,
                                  dt: TimeInterval) -> CGPoint {
        enemy.goalPosition = goal   // v2.1 (2c): the real goal, whatever we hand `chase`
        let geo = arenaGeometry
        guard geo.hasBlockedGeometry, !geo.routeNodes.isEmpty else { return goal }
        let r = enemy.geometryFootprintRadius
        guard r > 0 else { return goal }   // phased/flying actors steer themselves

        if enemy.routeRedecideCooldown > 0 { enemy.routeRedecideCooldown -= dt }
        let travel = r * 0.8   // slight forgiveness so brushing a corner isn't "blocked"

        // 1. Direct pursuit resumes the moment the line is clear.
        let occluded = geo.segmentBlocked(enemy.position, goal, travelRadius: travel)
        enemy.isOccludedFromGoal = occluded   // v2.1 (2b): published for subclasses
        if !occluded {
            if enemy.routeNodeID != nil {
                enemy.routePrevNodeID = enemy.routeNodeID
                enemy.routeNodeID = nil
                geometryDebug.routeDirectResumes += 1
            }
            return goal
        }

        // 3. Committed: arrive, invalidate, or keep walking.
        if let id = enemy.routeNodeID, let n = geo.node(id) {
            if enemy.position.distance(to: n.position) < GameConfig.Routing.arriveRadius {
                enemy.routePrevNodeID = id
                enemy.routeNodeID = nil        // fall through to re-decide
            } else if geo.segmentBlocked(enemy.position, n.position, travelRadius: travel) {
                enemy.routeNodeID = nil        // displaced behind cover — recover
                geometryDebug.routeRecoveries += 1
            } else {
                return n.position
            }
        }

        // 2. Decide (rate-limited so a confused frame can't thrash).
        if enemy.routeRedecideCooldown > 0 { return goal }
        enemy.routeRedecideCooldown = GameConfig.Routing.redecideCooldown

        var best: (id: Int, score: CGFloat)? = nil
        for n in geo.routeNodes {
            guard !geo.segmentBlocked(enemy.position, n.position, travelRadius: travel) else { continue }
            var score = enemy.position.distance(to: n.position) + n.position.distance(to: goal)
            if n.id == enemy.routePrevNodeID { score += GameConfig.Routing.backtrackPenalty }
            // v2.1 (2b): subclass opinion (flank preference, crowding). Zero
            // for every pre-2b enemy, so their routing is bit-identical to 1B.
            score += enemy.routeNodeBias(n, goal: goal, occupancy: routeOccupancy[n.id, default: 0])
            if best == nil || score < best!.score { best = (n.id, score) }
        }
        if let choice = best {
            enemy.routeNodeID = choice.id
            geometryDebug.routeDecisions += 1
            return geo.node(choice.id)?.position ?? goal
        }
        // 4. Nothing visible — beeline + slide, and say so in the counters.
        geometryDebug.routeFallbacks += 1
        return goal
    }

}
