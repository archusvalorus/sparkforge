// Stubs.swift — HUD proof harness (v2.1 abilities A4b corrective pass).
// The REAL HPBarNode.swift + BarrierTellState.swift + ColorExtensions.swift
// compile against this; only the config HPBarNode reads is mirrored.

import CoreGraphics
import Foundation

enum GameConfig {
    enum Player {
        static let baseMaxHP: Int = 100
    }
}
