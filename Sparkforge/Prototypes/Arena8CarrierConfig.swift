#if DEBUG
import Foundation
import CoreGraphics

extension GameConfig {
    /// Owner-approved controlled test values, not natural encounter balance.
    enum Arena8CarrierFixture {
        static let geometryRadius: CGFloat = 14
        static let hitRadius: CGFloat = 12
        static let moveSpeed: CGFloat = 104
        static let warningDuration: TimeInterval = 1
        static let arrivalTolerance: CGFloat = 12
        static let maxPackets = 1
        static let escortCount = 2
    }
}
#endif
