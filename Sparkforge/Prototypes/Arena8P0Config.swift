#if DEBUG
import Foundation
import CoreGraphics

extension GameConfig {
    enum Arena8Prototype {
        static let defaultCircleRadius: CGFloat = 420
        static let world = CGRect(x: -420, y: -240, width: 840, height: 480)
        static let roomHalfWidth: CGFloat = 100
        static let doorwayHalfHeight: CGFloat = 60
        static let playerRadius: CGFloat = 14
        static let enemyRadii: [CGFloat] = [14, 26, 40]
        static let playerSpeed: CGFloat = 160
        static let enemySpeed: CGFloat = 110
        static let maximumStep: TimeInterval = 0.1
        static let arrival: CGFloat = 5
        static let approachClearance: CGFloat = 0.5
        static let projectileMargin: CGFloat = 40
        static let shotEvery: TimeInterval = 2
    }
}
#endif
