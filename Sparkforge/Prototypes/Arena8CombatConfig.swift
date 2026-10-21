#if DEBUG
import Foundation
import CoreGraphics
extension GameConfig {
    enum Arena8Combat {
        static let playerStart = CGPoint(x: -280, y: 150)
        static let enemyStarts = [CGPoint(x: 280, y: 150), CGPoint(x: 280, y: -150), CGPoint(x: -280, y: -150)]
        static let spawnClearance: CGFloat = 100
        static let maximumStep: TimeInterval = 1.0 / 30
        static let shoveDistance: CGFloat = 600
        static let xpRadius: CGFloat = 4
    }
}
#endif
