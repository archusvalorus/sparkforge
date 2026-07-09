// VirtualJoystick.swift
// Sparkforge
//
// Custom floating virtual joystick — camera-aware.
// Uses VIEW coordinates (not scene) for left-half detection.
// This ensures the joystick works regardless of camera position.
//
// v1.4: Dynamic base recentering — when thumb exceeds max radius,
// base smoothly follows so direction always tracks current intent.
// Fixes "stuck direction" when sliding along joystick edge.

import SpriteKit

final class VirtualJoystick: SKNode {
    
    // MARK: - Output
    
    /// Normalized direction vector. Zero when idle.
    private(set) var direction: CGPoint = .zero
    
    /// Whether the joystick is currently being touched
    private(set) var isActive: Bool = false
    
    // MARK: - Internal Nodes
    
    private let baseNode: SKShapeNode
    private let knobNode: SKShapeNode
    
    // MARK: - State
    
    /// We track by touch hash, not identity — more reliable across touch lifecycle
    private var trackingTouchHash: Int?
    private var baseCenter: CGPoint = .zero  // In scene coordinates
    
    // MARK: - Config
    
    private let baseRadius: CGFloat
    private let knobRadius: CGFloat
    private let deadZone: CGFloat
    
    // MARK: - Init
    
    override init() {
        let config = GameConfig.Joystick.self
        self.baseRadius = config.baseRadius
        self.knobRadius = config.knobRadius
        self.deadZone = config.deadZone
        
        baseNode = SKShapeNode(circleOfRadius: baseRadius)
        baseNode.fillColor = SKColor(hex: config.baseColorHex, alpha: 0.3)
        baseNode.strokeColor = SKColor(hex: config.knobColorHex, alpha: 0.4)
        baseNode.lineWidth = 2
        
        knobNode = SKShapeNode(circleOfRadius: knobRadius)
        knobNode.fillColor = SKColor(hex: config.knobColorHex, alpha: 0.5)
        knobNode.strokeColor = .clear
        
        super.init()
        
        addChild(baseNode)
        addChild(knobNode)
        
        alpha = GameConfig.Joystick.idleAlpha
        isUserInteractionEnabled = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Touch Handling
    
    /// Call from scene's touchesBegan.
    @discardableResult
    func handleTouchBegan(_ touch: UITouch, in scene: SKScene) -> Bool {
        guard let view = scene.view else { return false }
        
        // Use VIEW coordinates for left-half check (camera-independent)
        let viewLocation = touch.location(in: view)
        let isLeftHalf = viewLocation.x < view.bounds.width / 2
        
        guard isLeftHalf else { return false }
        
        // If already tracking, force release first
        if trackingTouchHash != nil {
            forceRelease()
        }
        
        trackingTouchHash = touch.hash
        isActive = true
        
        // Get scene-space location for positioning
        let sceneLocation = touch.location(in: scene)
        baseCenter = sceneLocation
        
        // Position joystick in parent (camera) space
        if let parentNode = parent {
            position = parentNode.convert(sceneLocation, from: scene)
        }
        
        knobNode.position = .zero
        alpha = GameConfig.Joystick.activeAlpha
        
        return true
    }
    
    /// Call from scene's touchesMoved
    func handleTouchMoved(_ touch: UITouch, in scene: SKScene) {
        guard touch.hash == trackingTouchHash else { return }
        
        let sceneLocation = touch.location(in: scene)
        let offset = sceneLocation - baseCenter
        let distance = offset.length
        
        if distance > baseRadius {
            // DYNAMIC RECENTERING: Move the base toward the touch so the knob
            // stays at max radius but the direction always reflects where the
            // thumb actually is. This prevents the "stuck direction" bug when
            // the thumb slides along the edge of the joystick circle.
            let overshoot = offset.normalized * (distance - baseRadius)
            baseCenter = baseCenter + overshoot
            
            // Reposition joystick base in parent (camera) space
            if let parentNode = parent, let scene = scene as? SKScene {
                position = parentNode.convert(baseCenter, from: scene)
            }
            
            // Knob sits at max radius in the direction of the touch
            knobNode.position = offset.normalized * baseRadius
            
            // Direction is simply where the touch is relative to the (moved) base
            direction = offset.normalized
        } else if distance / baseRadius < deadZone {
            knobNode.position = offset
            direction = .zero
        } else {
            knobNode.position = offset
            direction = offset.normalized
        }
    }
    
    /// Call from scene's touchesEnded
    func handleTouchEnded(_ touch: UITouch) {
        guard touch.hash == trackingTouchHash else { return }
        forceRelease()
    }
    
    /// Force-release — clears all state unconditionally
    func forceRelease() {
        trackingTouchHash = nil
        isActive = false
        direction = .zero
        knobNode.position = .zero
        alpha = GameConfig.Joystick.idleAlpha
    }
}
