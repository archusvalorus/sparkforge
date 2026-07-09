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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let skView = view as? SKView else { return }
        
        // Scene setup — start with title screen
        let scene = TitleScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)  // Center origin
        
        // Debug info (remove for release)
        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        // skView.showsPhysics = true  // Uncomment to debug hitboxes
        #endif
        
        skView.ignoresSiblingOrder = true  // Use zPosition for ordering
        skView.preferredFramesPerSecond = 60
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
