//
//  ReviewMode.swift
//  Sparkforge
//
//  v2.0 (7) — App Review demonstration mode.
//
//  Why this exists: the Panda family is a secret behind a 9.27% run roll, and
//  the Flame Panda IAP lives inside that family. App Review (Guideline 2.1(a))
//  couldn't reach the purchase — there are no accounts to hand them, and no
//  deterministic steps exist. Apple's own suggested remedy is a demonstration
//  mode, so this is that: a hidden, documented-only-in-review-notes toggle.
//
//  What it does while active — and ONLY while active:
//    • The Panda family renders revealed at the skin hub (non-persistent; the
//      mask comes back when the mode goes off, unless something was bought).
//    • Every run is Panda-eligible, so a reviewer can actually draw the cards.
//
//  What it deliberately does NOT do: grant anything. The earned skin still
//  wants the capstone; the premium skin still goes through StoreKit. A player
//  who stumbles onto the trigger only spoils the secret for themselves.
//
//  This compiles into RELEASE on purpose (the #if DEBUG seams don't exist in
//  the reviewed binary — that's the whole bug). Per studio rule, an active
//  seam must announce itself: the title footer flips state and the run HUD
//  paints a badge whenever this is on.
//
import Foundation

enum ReviewMode {
    private static let key = "sf_review_mode_active"

    /// Taps required on the title-screen version label to flip the mode.
    /// Documented in the App Review notes; obscure enough that no one hits
    /// it by accident.
    static let tapsToToggle = 7

    static var isActive: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// Flip and report the new state (the caller shows the confirmation).
    @discardableResult
    static func toggle() -> Bool {
        isActive.toggle()
        return isActive
    }
}
