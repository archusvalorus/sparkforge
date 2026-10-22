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
            scene = TitleScene(size: skView.bounds.size)
        case .failure(let failure):
            NSLog("[CATALOG] %@", failure.report)
            scene = CatalogErrorScene(size: skView.bounds.size, failure: failure)
        }
        scene.scaleMode = .resizeFill
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)  // Center origin
        skView.presentScene(scene)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AdConsentPlatform.shared.presenter = self
        // UIKit may invoke appearance while applicationState still reports inactive.
        DispatchQueue.main.async { AdConsentCoordinator.shared.presenterBecameReady() }
        #if DEBUG
        if AdConsentPlatform.shared.systemATTTest || ProcessInfo.processInfo.arguments.contains("--privacy-debug-probe") { installPrivacyProbe() }
        #endif
    }

    #if DEBUG
    private var privacyProbeTimer: Timer?
    deinit { privacyProbeTimer?.invalidate() }
    private func installPrivacyProbe() {
        guard privacyProbeTimer == nil else { return }
        let label = UILabel(frame: CGRect(x: 12, y: 45, width: 780, height: 70))
        label.numberOfLines = 3
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.backgroundColor = .black
        label.textColor = .white
        label.accessibilityIdentifier = "privacy-state-probe"
        label.isUserInteractionEnabled = false
        view.addSubview(label)
        privacyProbeTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak label, weak self] _ in
            Task { @MainActor [weak label, weak self] in
                guard let self else { return }
                label?.text = "ATT=\(AdConsentPlatform.shared.trackingStatus) ready=\(AdConsentCoordinator.shared.ready) mode=\(AdConsentPlatform.shared.systemATTTest ? "OS TEST UMP/GMA STUBBED" : "REAL UMP") UMPerror=\(AdConsentPlatform.shared.updateErrorCode.map(String.init) ?? "none") \(AdConsentCoordinator.shared.diagnostic) StoreKit=\(ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--privacy-entitlement-test=") }) ? "STUBBED" : "REAL") scene=\(((self.view as? SKView)?.scene).map { String(describing: type(of: $0)) } ?? "none")"
            }
        }
    }
    #endif

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
