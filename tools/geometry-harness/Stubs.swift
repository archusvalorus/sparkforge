// Stubs.swift — geometry proof harness (v2.1 abilities Unit A7b, seam S0b;
// corrective 2). ArenaGeometry reads `GameConfig.Arena.radius`. That block is
// EXTRACTED from GameConfig.swift by run.sh (the app's own formula,
// `DeviceScale.arenaRadius × ArenaConfig.current.radiusScale`, executed as
// shipped), and so is `GameConfig.Geometry`. This file supplies only the two
// INPUTS the formula reads, which main.swift sets from the app's own source
// (DeviceScale.swift's phone radius, the Splitworks' radiusScale in
// ArenaConfig.swift). No radius formula is maintained here.

import CoreGraphics
import Foundation

enum DeviceScale {
    static var gameplay: CGFloat { 1 }
    /// Set by main.swift from DeviceScale.swift (the phone value).
    static var arenaRadius: CGFloat = 0
}

/// The one field the extracted `GameConfig.Arena.radius` reads.
struct ArenaConfig {
    let radiusScale: CGFloat
    /// Set by main.swift from ArenaConfig.swift (the Splitworks entry).
    static var current = ArenaConfig(radiusScale: 0)
}

enum GameConfig {}
