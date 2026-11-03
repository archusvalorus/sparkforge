#if DEBUG
import CoreGraphics
import Foundation
extension GameConfig {
    /// Controlled provisional baseline. Body/speed reuse the carrier fixture;
    /// these are not finalized Signaler encounter stats.
    enum Arena8SignalerFixture {
        static let geometryRadius: CGFloat = 14
        static let hitRadius: CGFloat = 12
        static let moveSpeed: CGFloat = 104
        static let warningDuration: TimeInterval = 1
    }
}
#endif
