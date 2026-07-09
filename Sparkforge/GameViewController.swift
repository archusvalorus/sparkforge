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

        let scene = TitleScene(size: skView.bounds.size)
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
