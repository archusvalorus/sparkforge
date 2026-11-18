// Shared authored six-room dimensions; this does not enable an arena route.
import CoreGraphics
extension GameConfig {
    enum Arena8Game {
        // Same clearance as the retained two-room proof; no tuning change.
        static let approachClearance: CGFloat = 0.5
        static let spawnClearance: CGFloat = 160
        static let roomSide: CGFloat = 540
        static let columnCenters: [CGFloat] = [-780, 0, 780]
        static let rowCenters: [CGFloat] = [420, -420]
        static let doorwayWidth: CGFloat = 120
        static let spawnAnchorOffset: CGFloat = 100
        static let mapArrival: CGFloat = 5
        static let echoEdgeFraction: CGFloat = 0.85
        static let echoOriginClearance: CGFloat = 12
    }
}
