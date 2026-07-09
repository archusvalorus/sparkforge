// DeviceScale.swift
// Sparkforge
//
// Central device-aware scaling utility.
// Provides multipliers for UI, gameplay, and touch targets
// based on iPhone vs iPad.

import UIKit

enum DeviceScale {
    
    static let isIPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    
    static var screenShort: CGFloat {
        min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
    }
    
    /// UI scale — fonts, HUD, labels, bars
    static var ui: CGFloat {
        isIPad ? screenShort / 390.0 : 1.0
    }
    
    /// Gameplay scale — arena, player, enemies, projectiles
    static var gameplay: CGFloat {
        isIPad ? 1.0 + (screenShort / 390.0 - 1.0) * 0.7 : 1.0
    }
    
    /// Touch target scale — buttons, joystick, card tap areas
    static var touch: CGFloat {
        isIPad ? screenShort / 360.0 : 1.0
    }
    
    // MARK: - Specific Values
    
    static var arenaRadius: CGFloat { isIPad ? 350 * gameplay : 350 }
    static var cardWidth: CGFloat { isIPad ? 130 : 90 }
    static var cardHeight: CGFloat { isIPad ? 185 : 130 }
    static var cardSpacing: CGFloat { isIPad ? 150 : 105 }
    static var joystickBaseRadius: CGFloat { isIPad ? 85 : 60 }
    static var joystickKnobRadius: CGFloat { isIPad ? 35 : 25 }
    static var xpBarWidth: CGFloat { isIPad ? 180 : 120 }
    
    // MARK: - Font Sizes
    
    static var timerFontSize: CGFloat { isIPad ? 30 : 20 }
    static var levelFontSize: CGFloat { isIPad ? 20 : 13 }
    static var titleFontSize: CGFloat { isIPad ? 52 : 36 }
    static var subtitleFontSize: CGFloat { isIPad ? 16 : 11 }
    static var deathTitleFontSize: CGFloat { isIPad ? 38 : 26 }
    static var deathStatsFontSize: CGFloat { isIPad ? 24 : 16 }
    static var buttonFontSize: CGFloat { isIPad ? 18 : 13 }
    
    // MARK: - Button Sizes
    
    static var reviveButtonWidth: CGFloat { isIPad ? 260 : 180 }
    static var reviveButtonHeight: CGFloat { isIPad ? 50 : 36 }
    static var restartButtonWidth: CGFloat { isIPad ? 200 : 140 }
    static var restartButtonHeight: CGFloat { isIPad ? 44 : 32 }
    
    // MARK: - Safe Area
    
    static var safeTopOffset: CGFloat { isIPad ? 60 : 80 }
}
