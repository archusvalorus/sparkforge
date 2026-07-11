// AppDelegate.swift
// Sparkforge

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // v1.7 ATT fix: the tracking prompt + ads start moved to
        // SceneDelegate.sceneDidBecomeActive — the old launch-timer
        // request raced scene activation, and iOS silently skips the
        // prompt when the scene isn't active yet (App Review flag, v1.6).
        return true
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
