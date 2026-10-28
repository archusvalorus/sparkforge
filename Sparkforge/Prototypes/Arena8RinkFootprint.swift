// Render-only union of the already-authored room floor. No damage geometry.
#if DEBUG
import CoreGraphics

struct Arena8RinkFootprint {
    static func path(in map: Arena8GameMap) -> CGPath? {
        guard map.isSixRoom, let first = map.rooms.first else { return nil }
        var path = CGPath(rect: first.rect, transform: nil)
        for rect in map.rooms.dropFirst().map(\.rect) + map.connections.map(\.corridor) {
            path = path.union(CGPath(rect: rect, transform: nil), using: .winding)
        }
        return path.normalized(using: .winding)
    }
}
#endif
