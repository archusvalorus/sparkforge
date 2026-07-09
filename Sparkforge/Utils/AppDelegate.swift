// AppDelegate.swift
// Sparkforge

import UIKit
import GoogleMobileAds
import AppTrackingTransparency

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Request ATT permission, then initialize ads
        // Delay slightly to ensure the app's UI is ready (ATT requires a presented window)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.requestTrackingAndStartAds()
        }
        
        return true
    }
    
    private func requestTrackingAndStartAds() {
        ATTrackingManager.requestTrackingAuthorization { status in
            // Initialize Google Mobile Ads regardless of tracking permission
            // AdMob will serve non-personalized ads if tracking is denied
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
    
    // MARK: - UISceneSession Lifecycle
    
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
