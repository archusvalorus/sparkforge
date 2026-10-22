// AppDelegate.swift
// Sparkforge

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Consent startup is deferred until an active app and visible presenter.
        return true
    }

    // The submitted v2.2 app also supports UIKit's legacy (storyboard) lifecycle.
    // Do not depend solely on scene callbacks: this build has no scene manifest.
    func applicationDidBecomeActive(_ application: UIApplication) {
        DispatchQueue.main.async { AdConsentCoordinator.shared.becameActive() }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        AdConsentCoordinator.shared.becameInactive()
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
