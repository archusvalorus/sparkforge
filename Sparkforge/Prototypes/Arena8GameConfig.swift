#if DEBUG
import CoreGraphics
extension GameConfig {
    enum Arena8Game {
        static let spawnClearance: CGFloat = 160
        static let roomSide: CGFloat = 360
        static let columnCenters: [CGFloat] = [-520, 0, 520]
        static let rowCenters: [CGFloat] = [280, -280]
        static let doorwayWidth: CGFloat = 120
        static let spawnAnchorOffset: CGFloat = 100
        static let mapArrival: CGFloat = 5
        static let echoEdgeFraction: CGFloat = 0.85
        static let echoOriginClearance: CGFloat = 12
    }
}
#endif
