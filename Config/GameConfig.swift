// GameConfig.swift
// Sparkforge
//
// Single source of truth for all game tuning values.
// Tweak here, not scattered across files.

import CoreGraphics
import Foundation

enum GameConfig {
    
    // MARK: - Arena
    enum Arena {
        /// Radius of the circular arena in points
        static let radius: CGFloat = 350
        /// Color of the arena floor
        static let floorColorHex: UInt32 = 0x1A1A1A
        /// Color of the arena boundary ring
        static let boundaryColorHex: UInt32 = 0x3A1A0A
        /// Boundary ring line width
        static let boundaryLineWidth: CGFloat = 3.0
        /// How much beyond the boundary the player is pushed back
        static let boundaryPushback: CGFloat = 2.0
    }
    
    // MARK: - Player
    enum Player {
        /// Player movement speed in points per second
        static let speed: CGFloat = 250
        /// Visual radius of the player spark
        static let visualRadius: CGFloat = 16
        /// Collision radius — smaller than visual for forgiving hitbox
        static let collisionRadius: CGFloat = 10
        /// Base glow intensity (scales with level)
        static let baseGlowWidth: CGFloat = 8
        /// Core color
        static let coreColorHex: UInt32 = 0xFFAA33
        /// Glow color
        static let glowColorHex: UInt32 = 0xFF6600
    }
    
    // MARK: - Enemy
    enum Enemy {
        /// Base enemy speed — must be slower than player
        static let baseSpeed: CGFloat = 130
        /// Base enemy visual radius
        static let visualRadius: CGFloat = 14
        /// Base enemy collision radius
        static let collisionRadius: CGFloat = 12
        /// Base enemy health
        static let baseHealth: Int = 1
        /// Body color (darker for menacing look)
        static let bodyColorHex: UInt32 = 0x1A1A1A
        /// Rim glow color (subtle red)
        static let rimGlowColorHex: UInt32 = 0x661111
    }
    
    // MARK: - Projectile
    enum Projectile {
        /// Auto-attack fire rate (seconds between shots)
        static let fireInterval: TimeInterval = 0.5
        /// Projectile speed
        static let speed: CGFloat = 400
        /// Projectile radius
        static let radius: CGFloat = 4
        /// Projectile color
        static let colorHex: UInt32 = 0xFFCC44
        /// Max range before despawn (in points)
        static let maxRange: CGFloat = 300
    }
    
    // MARK: - Joystick
    enum Joystick {
        /// Radius of the joystick base (touch zone)
        static let baseRadius: CGFloat = 60
        /// Radius of the joystick knob (thumb indicator)
        static let knobRadius: CGFloat = 25
        /// Dead zone — input below this normalized magnitude is ignored
        static let deadZone: CGFloat = 0.1
        /// Opacity of the joystick when active
        static let activeAlpha: CGFloat = 0.5
        /// Opacity when idle (hidden — appears on touch)
        static let idleAlpha: CGFloat = 0.0
        /// Base color
        static let baseColorHex: UInt32 = 0x444444
        /// Knob color
        static let knobColorHex: UInt32 = 0xAAAAAA
    }
    
    // MARK: - Wave / Pacing
    enum Wave {
        /// Time between enemy spawns at start (seconds)
        static let initialSpawnInterval: TimeInterval = 1.2
        /// Minimum spawn interval before late game kicks in
        static let minimumSpawnInterval: TimeInterval = 0.4
        /// How fast spawn interval decreases per second of game time
        static let spawnAcceleration: TimeInterval = 0.012
        /// Late game (90s+): faster acceleration
        static let lateGameAcceleration: TimeInterval = 0.02
        /// Late game minimum spawn interval
        static let lateGameMinInterval: TimeInterval = 0.2
        /// Mini-boss spawn time
        static let miniBossSpawnTime: TimeInterval = 90.0
        /// Spawn distance from arena center (just outside boundary)
        static let spawnDistance: CGFloat = Arena.radius + 40
    }
    
    // MARK: - XP & Leveling
    enum Leveling {
        /// XP required for level 2
        static let baseXPRequired: Int = 5
        /// XP scaling per level (multiplied by level)
        static let xpScalingFactor: Double = 1.4
        /// XP dropped by base enemy
        static let baseEnemyXP: Int = 1
        /// Number of upgrade choices presented
        static let upgradeChoiceCount: Int = 3
    }
    
    // MARK: - Physics Categories (bitmask)
    enum Physics {
        static let player:     UInt32 = 0x1 << 0  // 1
        static let enemy:      UInt32 = 0x1 << 1  // 2
        static let projectile: UInt32 = 0x1 << 2  // 4
        static let boundary:   UInt32 = 0x1 << 3  // 8
        static let xpOrb:      UInt32 = 0x1 << 4  // 16
    }
}
