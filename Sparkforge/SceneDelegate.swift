// SceneDelegate.swift
// Sparkforge

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

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
        guard !GameRunPreferences.isIsolated else { return }
        DispatchQueue.main.async { AdConsentCoordinator.shared.becameActive() }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        guard !GameRunPreferences.isIsolated else { return }
        AdConsentCoordinator.shared.becameInactive()
    }
}
