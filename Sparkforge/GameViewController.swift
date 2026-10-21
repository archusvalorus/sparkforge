// GameViewController.swift
// Sparkforge
//
// Presents the GameScene in a SpriteKit view.
// Minimal — just wires up the view and scene.

import UIKit
import SpriteKit

class GameViewController: UIViewController {
    
    override func loadView() {
        self.view = SKView()
    }
    
    private var hasPresentedScene = false

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let skView = view as? SKView else { return }

        // Debug info (remove for release)
        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        // skView.showsPhysics = true  // Uncomment to debug hitboxes
        #endif

        skView.ignoresSiblingOrder = true  // Use zPosition for ordering
        skView.preferredFramesPerSecond = 60
    }

    // v1.6: present AFTER layout — at viewDidLoad the SKView's bounds are
    // still zero on a fresh launch, so any scene doing size-relative layout
    // in didMove (TitleScene's stretched stack) laid out against height 0.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard !hasPresentedScene,
              let skView = view as? SKView,
              skView.bounds.height > 0 else { return }
        hasPresentedScene = true

        // v2.2 J2 (ruling D1): the ability catalog is loaded once, before the
        // title. A catalog that fails to load blocks the game behind an error
        // screen; the full report goes to the log in every build.
        let scene: SKScene
        switch AbilityCatalog.installed {
        case .success(let catalog):
            #if DEBUG
            NSLog("[CATALOG] loaded %d cards, %d synergy tiers, %d retired ids (schema %d)",
                  catalog.cards.count, catalog.synergyEffects.count, catalog.retiredCardIDs.count, AbilityCatalog.supportedSchemaVersion)
            #endif
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--rainbow-p1") {
                scene = RainbowP1Scene(size: skView.bounds.size)
            } else if ProcessInfo.processInfo.arguments.contains("--arena8-p0") {
                scene = Arena8P0Scene(size: skView.bounds.size)
            } else if ProcessInfo.processInfo.arguments.contains("--arena8-combat") {
                scene = Arena8CombatScene(size: skView.bounds.size)
            } else {
                scene = TitleScene(size: skView.bounds.size)
            }
            #else
            scene = TitleScene(size: skView.bounds.size)
            #endif
        case .failure(let failure):
            NSLog("[CATALOG] %@", failure.report)
            scene = CatalogErrorScene(size: skView.bounds.size, failure: failure)
        }
        scene.scaleMode = .resizeFill
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)  // Center origin
        skView.presentScene(scene)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }
    
    override var prefersStatusBarHidden: Bool {
        true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }
}
