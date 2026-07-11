// SceneDelegate.swift
// Sparkforge

import UIKit
import AppTrackingTransparency
import GoogleMobileAds

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    /// v1.7 ATT fix: the prompt must be requested from an ACTIVE scene.
    /// Requesting on a launch timer raced scene activation — when it
    /// lost, iOS silently skipped the prompt (App Review flag on v1.6).
    private static var hasRequestedTracking = false

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard !Self.hasRequestedTracking else { return }
        Self.hasRequestedTracking = true

        ATTrackingManager.requestTrackingAuthorization { status in
            // Initialize Google Mobile Ads regardless of the choice —
            // AdMob serves non-personalized ads when tracking is denied.
            // The free path stays whole either way.
            DispatchQueue.main.async {
                MobileAds.shared.start(completionHandler: nil)
            }

            #if DEBUG
            switch status {
            case .authorized:    print("[ATT] Tracking authorized")
            case .denied:        print("[ATT] Tracking denied")
            case .restricted:    print("[ATT] Tracking restricted")
            case .notDetermined: print("[ATT] Tracking not determined")
            @unknown default:    print("[ATT] Unknown status")
            }
            #endif
        }
    }
}
