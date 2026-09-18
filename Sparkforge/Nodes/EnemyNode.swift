// EnemyNode.swift
// Sparkforge
//
// Visual overhaul: darker bodies with menacing faces.
// Randomized face expressions for variety.
// Status effects tint the face/body.

import SpriteKit

class EnemyNode: SKNode {
    
    // MARK: - State
    
    private(set) var health: Int
    private(set) var maxHealth: Int
    private(set) var moveSpeed: CGFloat
    private(set) var xpValue: Int
    /// v1.9: true once onDeath() has run — the node self-removes after a short
    /// death animation, so a dying enemy must be pruned from GameScene's
    /// `enemies` array to avoid becoming a phantom auto-aim target.
    private(set) var isDying = false
    /// v2.1 A0: set by GameScene.onEnemyKilled when this kill has been paid —
    /// the ledger that makes every death credit exactly once.
    var killCredited = false
    /// v2.1 A0: the killing blow's damage to REMAINING health (no overkill).
    /// Sanguinarian's Blood Barrier (A4) reads it.
    private(set) var finishingDamage: Int = 0
    /// v1.6: Mini-bosses deal their configured contact damage instead of generic melee
    var isMiniBoss: Bool = false

    /// v2.1 (Geometry 1A): the radius this enemy occupies for ARENA GEOMETRY —
    /// resolution against blocked footprints and (1B) route clearance. It is
    /// EXPLICIT and independent of both the contact physics body (which never
    /// tracks setScale — a 2.2× mini-boss still has a 12pt body) and the
    /// visual. Reconciliation §4/§7.2: geometry footprints must never silently
    /// replace combat hitboxes. Default = visual radius × current scale;
    /// subclasses that phase or fly set 0 to exempt themselves.
    var geometryFootprintRadius: CGFloat {
        geometryFootprintOverride ?? GameConfig.Enemy.visualRadius * xScale
    }
    var geometryFootprintOverride: CGFloat? = nil

    // v2.1 (Geometry 1B): route-guidance state. nil = pursuing directly.
    // The scene's steer pass owns these; enemies never read them.
    var routeNodeID: Int? = nil
    var routePrevNodeID: Int? = nil
    var routeRedecideCooldown: TimeInterval = 0

    // v2.1 (Geometry 2b): two facts the scene already computes, published so
    // a subclass can act on them without a second geometry query.
    /// True while the direct line to the pursuit goal is blocked (set by the
    /// steer pass each frame; always false on open arenas).
    var isOccludedFromGoal = false
    /// The real pursuit goal (Spark) this frame, even when the steer pass
    /// hands `chase` a route node instead. Anchor-seeking enemies need it.
    var goalPosition: CGPoint = .zero
    /// True when the post-move resolve pushed this body out of a footprint
    /// last frame — "you ran into the Carrier." A subclass that reads it
    /// should clear it.
    var geometryDisplacedThisFrame = false

    /// v2.1 (2b): route-scoring hook. Added to the 1B distance score for
    /// `node` (lower wins); `occupancy` = how many enemies are already
    /// committed to it. Default = no opinion.
    func routeNodeBias(_ node: RouteNode, goal: CGPoint, occupancy: Int) -> CGFloat { 0 }

    /// v2.1 (2b): the scene reports a landed contact hit on the player.
    /// Default = nothing; committed-attack enemies use it to end the attack.
    func didStrikePlayer() {}
    
    // MARK: - Status Effects
    
    private(set) var currentSlow: CGFloat = 0.0
    private var slowTimer: TimeInterval = 0
    /// v2.1 A1: Burn — Crucible's per-enemy stacks + dormant decay (CL-16).
    private(set) var burn = BurnState()
    /// Lazily built row of ember pips — only enemies that reach 2+ stacks pay for it.
    private var burnPips: [SKShapeNode] = []
    private var drawnBurnStacks = 0
    private var drawnBurnDormant = false
    private(set) var bleedDPS: CGFloat = 0.0
    private var bleedTimer: TimeInterval = 0
    /// v1.8 (Unit 14): situational bleed scaling set by GameScene each frame —
    /// Glass Blood (vs chilled/slowed) and Red Smile (player low HP). 1.0 = none.
    var bleedDamageMultiplier: CGFloat = 1.0
    /// v1.9: general vulnerability — scales ALL incoming damage (every source
    /// routes through takeDamage). 1.0 = none. Reusable temporary-vulnerability
    /// primitive: Skybeam "Called", later Apex "Marked", Polar Vortex "Frostbitten".
    var vulnerabilityMultiplier: CGFloat = 1.0
    var isVulnerable: Bool { vulnerabilityMultiplier > 1.0 }
    /// v2.0 Phase C (C1.4) — Seed Spore Shot. 0 = unseeded; 1 = a primary seed;
    /// 2 = a re-embedded (secondary) seed. The generation caps the chain: a
    /// gen-2 seed's fragments never re-embed, so reproduction can't run away.
    var seedGeneration: Int = 0
    var isSeeded: Bool { seedGeneration > 0 }
    /// v1.9 Polar Vortex — Windchill accumulates Chill; at the freeze threshold
    /// the enemy freezes (locked in place), then becomes Frostbitten.
    var chillStacks: Int = 0
    private var freezeTimer: TimeInterval = 0
    var isFrozen: Bool { freezeTimer > 0 }
    private var stunTimer: TimeInterval = 0
    private var dotAccumulator: CGFloat = 0.0
    /// v2.1 A0: timed vulnerability windows on GAME time. These were SKAction
    /// waits, which kept running under the pause menu and the level-up screen.
    /// They still share `vulnerabilityMultiplier` (last writer wins) as before.
    // v2.1 A2 Whiteout: the snowman. A transform is a stun with a costume —
    // every subclass already respects `isStunned`, so none of them need to
    // learn about snowmen. One transform per enemy per cooldown.
    private var snowman = SnowmanState()
    private var snowmanNode: SKNode?
    var isSnowman: Bool { snowman.isSnowman }
    private var fractureWindow = GameTimer()
    private var frostbiteWindow = DelayedWindow()
    private var frostbiteMultiplier: CGFloat = 1.0
    
    var isBurning: Bool { burn.isBurning }
    var burnStacks: Int { burn.stacks }
    var isSlowed: Bool { currentSlow > 0 && slowTimer > 0 }
    var isBleeding: Bool { bleedDPS > 0 && bleedTimer > 0 }
    var isStunned: Bool { stunTimer > 0 }
    
    var healthPercent: CGFloat {
        guard maxHealth > 0 else { return 0 }
        return CGFloat(health) / CGFloat(maxHealth)
    }
    
    // MARK: - Visual

    private let bodyNode: SKShapeNode
    private let rimGlowNode: SKShapeNode
    private let leftEye: SKShapeNode
    private let rightEye: SKShapeNode
    private let mouth: SKShapeNode

    // v2.0: themeable base palette so subclasses (Star Anvil family, future
    // biomes) aren't locked to the red-devil look. Status-effect reverts read
    // these instead of hardcoded hexes, so a themed enemy returns to ITS colors.
    private var baseBodyHex: UInt32 = 0x1A1A1A
    private var baseEyeHex: UInt32 = 0xFF2222
    
    // MARK: - Face Styles
    
    private enum FaceStyle: CaseIterable {
        case angry       // .\ _ /.   — angled brows, flat mouth
        case menacing    // V  V  ___  — V eyes, wide grin
        case glaring     // -  -  ^    — slit eyes, small frown
        case furious     // >  <  ~~~  — chevron eyes, zigzag mouth
    }
    
    // MARK: - Init
    
    /// Health is scaled by `GameConfig.Enemy.healthScale` HERE, centrally, so
    /// every arena's spawn table and every subclass inherits the dial without
    /// being edited. Signature deliberately unchanged — subclasses override this
    /// initializer, and adding a parameter breaks the override chain.
    init(health: Int = GameConfig.Enemy.baseHealth,
         moveSpeed: CGFloat = GameConfig.Enemy.baseSpeed,
         xpValue: Int = GameConfig.Leveling.baseEnemyXP) {

        let hp = GameConfig.Enemy.scaledHealth(health)
        self.health = hp
        self.maxHealth = hp
        self.moveSpeed = moveSpeed
        self.xpValue = xpValue
        
        let config = GameConfig.Enemy.self
        let r = config.visualRadius
        
        // Darker body
        bodyNode = SKShapeNode(circleOfRadius: r)
        bodyNode.fillColor = SKColor(hex: 0x1A1A1A)
        bodyNode.strokeColor = .clear
        bodyNode.zPosition = 5
        
        // Rim glow
        rimGlowNode = SKShapeNode(circleOfRadius: r + 2)
        rimGlowNode.fillColor = .clear
        rimGlowNode.strokeColor = SKColor(hex: 0x661111, alpha: 0.7)
        rimGlowNode.lineWidth = 2
        rimGlowNode.glowWidth = 4
        rimGlowNode.zPosition = 4
        
        // Eyes — small glowing red dots
        let eyeRadius: CGFloat = 1.8
        let eyeSpacing: CGFloat = r * 0.38
        let eyeY: CGFloat = r * 0.15
        
        leftEye = SKShapeNode(circleOfRadius: eyeRadius)
        leftEye.fillColor = SKColor(hex: 0xFF2222)
        leftEye.strokeColor = .clear
        leftEye.glowWidth = 3
        leftEye.position = CGPoint(x: -eyeSpacing, y: eyeY)
        leftEye.zPosition = 6
        
        rightEye = SKShapeNode(circleOfRadius: eyeRadius)
        rightEye.fillColor = SKColor(hex: 0xFF2222)
        rightEye.strokeColor = .clear
        rightEye.glowWidth = 3
        rightEye.position = CGPoint(x: eyeSpacing, y: eyeY)
        rightEye.zPosition = 6
        
        // Mouth — varies by style
        mouth = SKShapeNode()
        mouth.strokeColor = SKColor(hex: 0xCC1111, alpha: 0.8)
        mouth.lineWidth = 1.2
        mouth.zPosition = 6
        
        super.init()
        
        addChild(rimGlowNode)
        addChild(bodyNode)
        addChild(leftEye)
        addChild(rightEye)
        addChild(mouth)
        
        // Randomize face
        applyFaceStyle(FaceStyle.allCases.randomElement() ?? .angry)
        
        // Subtle idle eye pulse
        startEyePulse()
        
        setupPhysics()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Face Styles
    
    private func applyFaceStyle(_ style: FaceStyle) {
        let r = GameConfig.Enemy.visualRadius
        let mouthY: CGFloat = -r * 0.25
        
        switch style {
        case .angry:
            // Angled brow lines above eyes + flat mouth
            addBrowLine(from: CGPoint(x: -r * 0.55, y: r * 0.4),
                       to: CGPoint(x: -r * 0.2, y: r * 0.3))
            addBrowLine(from: CGPoint(x: r * 0.55, y: r * 0.4),
                       to: CGPoint(x: r * 0.2, y: r * 0.3))
            let mouthPath = CGMutablePath()
            mouthPath.move(to: CGPoint(x: -r * 0.3, y: mouthY))
            mouthPath.addLine(to: CGPoint(x: r * 0.3, y: mouthY))
            mouth.path = mouthPath
            
        case .menacing:
            // Slightly larger eyes, curved grin
            leftEye.setScale(1.2)
            rightEye.setScale(1.2)
            let mouthPath = CGMutablePath()
            mouthPath.move(to: CGPoint(x: -r * 0.35, y: mouthY + 2))
            mouthPath.addQuadCurve(to: CGPoint(x: r * 0.35, y: mouthY + 2),
                                    control: CGPoint(x: 0, y: mouthY - 3))
            mouth.path = mouthPath
            
        case .glaring:
            // Slit eyes (horizontal lines), small frown
            leftEye.path = CGPath(rect: CGRect(x: -3, y: -0.8, width: 6, height: 1.6), transform: nil)
            rightEye.path = CGPath(rect: CGRect(x: -3, y: -0.8, width: 6, height: 1.6), transform: nil)
            let mouthPath = CGMutablePath()
            mouthPath.move(to: CGPoint(x: -r * 0.2, y: mouthY))
            mouthPath.addQuadCurve(to: CGPoint(x: r * 0.2, y: mouthY),
                                    control: CGPoint(x: 0, y: mouthY + 3))
            mouth.path = mouthPath
            
        case .furious:
            // Chevron eyes, zigzag mouth
            let chevronL = CGMutablePath()
            chevronL.move(to: CGPoint(x: -r * 0.5, y: r * 0.25))
            chevronL.addLine(to: CGPoint(x: -r * 0.35, y: r * 0.1))
            chevronL.addLine(to: CGPoint(x: -r * 0.2, y: r * 0.25))
            leftEye.path = chevronL
            leftEye.fillColor = .clear
            leftEye.strokeColor = SKColor(hex: 0xFF2222)
            leftEye.lineWidth = 1.5
            
            let chevronR = CGMutablePath()
            chevronR.move(to: CGPoint(x: r * 0.2, y: r * 0.25))
            chevronR.addLine(to: CGPoint(x: r * 0.35, y: r * 0.1))
            chevronR.addLine(to: CGPoint(x: r * 0.5, y: r * 0.25))
            rightEye.path = chevronR
            rightEye.fillColor = .clear
            rightEye.strokeColor = SKColor(hex: 0xFF2222)
            rightEye.lineWidth = 1.5
            
            let mouthPath = CGMutablePath()
            mouthPath.move(to: CGPoint(x: -r * 0.35, y: mouthY))
            mouthPath.addLine(to: CGPoint(x: -r * 0.15, y: mouthY - 2))
            mouthPath.addLine(to: CGPoint(x: 0, y: mouthY))
            mouthPath.addLine(to: CGPoint(x: r * 0.15, y: mouthY - 2))
            mouthPath.addLine(to: CGPoint(x: r * 0.35, y: mouthY))
            mouth.path = mouthPath
        }
    }
    
    private func addBrowLine(from: CGPoint, to: CGPoint) {
        let brow = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        brow.path = path
        brow.strokeColor = SKColor(hex: 0xCC2222, alpha: 0.7)
        brow.lineWidth = 1.2
        brow.zPosition = 6
        addChild(brow)
    }
    
    // MARK: - Eye Pulse
    
    private func startEyePulse() {
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.8 + CGFloat.random(in: 0...0.4)),
            SKAction.fadeAlpha(to: 1.0, duration: 0.6 + CGFloat.random(in: 0...0.3))
        ])
        leftEye.run(SKAction.repeatForever(pulse))
        
        // Offset right eye slightly for asymmetry
        let pulseR = SKAction.sequence([
            SKAction.wait(forDuration: 0.2),
            SKAction.fadeAlpha(to: 0.5, duration: 0.7 + CGFloat.random(in: 0...0.4)),
            SKAction.fadeAlpha(to: 1.0, duration: 0.7 + CGFloat.random(in: 0...0.3))
        ])
        rightEye.run(SKAction.repeatForever(pulseR))
    }
    
    // MARK: - Physics
    
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: GameConfig.Enemy.collisionRadius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = GameConfig.Physics.enemy
        body.contactTestBitMask = GameConfig.Physics.player | GameConfig.Physics.projectile
        body.collisionBitMask = 0
        body.linearDamping = 0
        body.friction = 0
        physicsBody = body
    }
    
    // MARK: - Theming (v2.0)

    /// Recolor the base body/rim/eyes (Star Anvil enemies, future biomes). Stores
    /// body+eye as the new "base" so status-effect reverts return here, not to red.
    func setBodyPalette(body: UInt32, rim: UInt32, eye: UInt32) {
        baseBodyHex = body
        baseEyeHex = eye
        bodyNode.fillColor = SKColor(hex: body)
        rimGlowNode.strokeColor = SKColor(hex: rim, alpha: 0.8)
        leftEye.fillColor = SKColor(hex: eye)
        rightEye.fillColor = SKColor(hex: eye)
    }

    // MARK: - AI

    func chase(target: CGPoint, deltaTime: TimeInterval, globalSlow: CGFloat = 0) {
        // v1.6: stun ticks in updateStatusEffects (so ranged enemies respect it too)
        // v1.9: a frozen enemy is locked in place too.
        guard !isStunned && !isFrozen else { return }
        
        let effectiveSlow = min(currentSlow + globalSlow, 0.8)
        let effectiveSpeed = moveSpeed * (1.0 - effectiveSlow)
        
        let direction = (target - position).normalized
        let displacement = direction * effectiveSpeed * CGFloat(deltaTime)
        position += displacement
    }
    
    // MARK: - Status Effect Application
    
    func applySlow(_ amount: CGFloat, duration: TimeInterval) {
        currentSlow = max(currentSlow, amount)
        slowTimer = max(slowTimer, duration)
        bodyNode.fillColor = SKColor(hex: 0x112233)
        leftEye.fillColor = SKColor(hex: 0x4488FF)
        rightEye.fillColor = SKColor(hex: 0x4488FF)
    }
    
    /// Apply Burn. `source` decides whether this can add a Crucible stack
    /// (only a Kindle hit can); `stackCap` is the player's cap (1 = no
    /// stacking). Returns true when a stack was added.
    @discardableResult
    func applyBurn(_ dps: CGFloat, duration: TimeInterval,
                   source: BurnState.Source = .other, stackCap: Int = 1) -> Bool {
        let added = burn.ignite(dps: dps, duration: duration, source: source, stackCap: stackCap,
                                stackInterval: GameConfig.Fire.crucibleStackInterval)
        refreshBurnVisual()
        return added
    }

    /// v2.1 A1 placeholder tell: the rim burns hotter per stack, and from two
    /// stacks up a row of ember pips counts them. Dormant stacks (Burn ended,
    /// fading one by one) keep their pips, dimmed, with the rim gone cold.
    private func refreshBurnVisual() {
        let stacks = burn.stacks
        let dormant = burn.isDormant
        drawnBurnStacks = stacks
        drawnBurnDormant = dormant

        if burn.isBurning {
            rimGlowNode.strokeColor = SKColor(hex: 0xFF6633, alpha: 0.9)
            rimGlowNode.glowWidth = 6 + CGFloat(max(0, stacks - 1)) * 1.5
        } else {
            rimGlowNode.strokeColor = SKColor(hex: 0x661111, alpha: 0.7)
            rimGlowNode.glowWidth = 4
        }

        guard stacks >= 2 || !burnPips.isEmpty else { return }
        let r = GameConfig.Enemy.visualRadius
        while burnPips.count < stacks {
            let pip = SKShapeNode(circleOfRadius: 1.8)
            pip.strokeColor = .clear
            pip.zPosition = 7
            addChild(pip)
            burnPips.append(pip)
        }
        let shown = stacks >= 2 ? stacks : 0
        let spacing: CGFloat = 5
        let startX = -CGFloat(max(0, shown - 1)) * spacing / 2
        for (i, pip) in burnPips.enumerated() {
            pip.isHidden = i >= shown
            pip.position = CGPoint(x: startX + CGFloat(i) * spacing, y: r + 6)
            pip.fillColor = SKColor(hex: dormant ? 0x8A4A2A : 0xFFB84D, alpha: dormant ? 0.55 : 1.0)
            pip.glowWidth = dormant ? 0 : 2
        }
    }
    
    func applyBleed(_ dps: CGFloat, duration: TimeInterval) {
        bleedDPS = max(bleedDPS, dps)
        bleedTimer = max(bleedTimer, duration)
    }
    
    func applyStun(_ duration: TimeInterval) {
        stunTimer = max(stunTimer, duration)
    }

    /// v1.9 Polar Vortex: freeze the enemy in place with an icy tint.
    func applyFreeze(_ duration: TimeInterval) {
        freezeTimer = max(freezeTimer, duration)
        bodyNode.fillColor = SKColor(hex: 0x66CCFF)
    }

    /// v2.1 A2 Whiteout: become a snowman for `duration` (boss-class at the
    /// BossClass debuff scale). Returns false if this enemy transformed too
    /// recently or is already gone. `meltsOnDamage` = Whiteout T3.
    @discardableResult
    func becomeSnowman(duration: TimeInterval, meltsOnDamage: Bool) -> Bool {
        guard !isDying,
              let applied = snowman.begin(duration: duration, cooldown: GameConfig.Chill.snowmanCooldown,
                                          meltsOnDamage: meltsOnDamage, isBossClass: isMiniBoss,
                                          bossClassScale: GameConfig.BossClass.debuffScale) else { return false }
        stunTimer = max(stunTimer, applied)
        showSnowman()
        return true
    }

    /// Placeholder art (A9 replaces it): two snowballs, coal eyes, a carrot.
    private func showSnowman() {
        let r = GameConfig.Enemy.visualRadius
        let snow = SKNode()
        snow.zPosition = 8
        let body = SKShapeNode(circleOfRadius: r * 1.05)
        body.fillColor = SKColor(hex: 0xF2F8FF); body.strokeColor = SKColor(hex: 0xAADDFF); body.lineWidth = 1.5
        let head = SKShapeNode(circleOfRadius: r * 0.62)
        head.fillColor = SKColor(hex: 0xFFFFFF); head.strokeColor = SKColor(hex: 0xAADDFF); head.lineWidth = 1.2
        head.position = CGPoint(x: 0, y: r * 1.25)
        snow.addChild(body); snow.addChild(head)
        for dx: CGFloat in [-0.22, 0.22] {
            let eye = SKShapeNode(circleOfRadius: 1.3)
            eye.fillColor = SKColor(hex: 0x222222); eye.strokeColor = .clear
            eye.position = CGPoint(x: r * dx, y: r * 1.35)
            snow.addChild(eye)
        }
        let nose = SKShapeNode(rectOf: CGSize(width: 5, height: 2), cornerRadius: 1)
        nose.fillColor = SKColor(hex: 0xFF8833); nose.strokeColor = .clear
        nose.position = CGPoint(x: 2.5, y: r * 1.18)
        snow.addChild(nose)
        snow.setScale(0.2)
        snow.run(SKAction.scale(to: 1.0, duration: 0.12))
        addChild(snow)
        snowmanNode = snow
    }

    /// Drop the costume. `melted` = damage did it (T3): the blue smiling puddle.
    private func endSnowman(melted: Bool) {
        stunTimer = 0
        snowmanNode?.removeFromParent()
        snowmanNode = nil
        guard melted, let field = parent else { return }
        let r = GameConfig.Enemy.visualRadius * xScale
        let puddle = SKShapeNode(ellipseOf: CGSize(width: r * 2.6, height: r * 1.3))
        puddle.fillColor = SKColor(hex: 0x66B8FF, alpha: 0.55)
        puddle.strokeColor = SKColor(hex: 0xCCEEFF, alpha: 0.8)
        puddle.lineWidth = 1
        puddle.position = position
        puddle.zPosition = 2.5
        for dx: CGFloat in [-0.35, 0.35] {
            let eye = SKShapeNode(circleOfRadius: 1.4)
            eye.fillColor = SKColor(hex: 0x1A3A66); eye.strokeColor = .clear
            eye.position = CGPoint(x: r * dx, y: r * 0.12)
            puddle.addChild(eye)
        }
        let smile = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -r * 0.4, y: -r * 0.08))
        path.addQuadCurve(to: CGPoint(x: r * 0.4, y: -r * 0.08), control: CGPoint(x: 0, y: -r * 0.45))
        smile.path = path
        smile.strokeColor = SKColor(hex: 0x1A3A66); smile.lineWidth = 1.2
        puddle.addChild(smile)
        puddle.setScale(0.3)
        field.addChild(puddle)
        puddle.run(SKAction.sequence([
            SKAction.scale(to: 1.0, duration: 0.18),
            SKAction.wait(forDuration: 0.9),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }

    /// v1.9 Erasure Fracture: take more damage for a while. Re-applying
    /// restarts the window.
    func applyFracture(_ multiplier: CGFloat, duration: TimeInterval) {
        vulnerabilityMultiplier = multiplier
        fractureWindow.start(duration)
    }

    /// v1.9 Polar Vortex Frostbite: once the freeze ends, take more damage for
    /// a while. Re-applying replaces a pending or open window.
    func scheduleFrostbite(_ multiplier: CGFloat, after delay: TimeInterval, lasting duration: TimeInterval) {
        frostbiteMultiplier = multiplier
        frostbiteWindow.schedule(after: delay, lasting: duration)
    }
    
    // MARK: - Status Effect Update
    
    /// v1.9: seconds this enemy has been alive in the arena (Apex "Marked" uses it).
    private(set) var timeAlive: TimeInterval = 0

    func updateStatusEffects(deltaTime: TimeInterval) -> Bool {
        timeAlive += deltaTime
        var totalDOT: CGFloat = 0

        // v1.6: stun timer ticks here so ALL enemy types respect it
        if stunTimer > 0 {
            stunTimer -= deltaTime
        }

        // v1.9 Polar Vortex: freeze ticks here too; on thaw, clear Chill + tint.
        if freezeTimer > 0 {
            freezeTimer -= deltaTime
            if freezeTimer <= 0 {
                chillStacks = 0
                bodyNode.fillColor = SKColor(hex: baseBodyHex)
            }
        }

        if snowman.tick(deltaTime) { endSnowman(melted: false) }
        if fractureWindow.tick(deltaTime) { vulnerabilityMultiplier = 1.0 }
        switch frostbiteWindow.tick(deltaTime) {
        case .opened: vulnerabilityMultiplier = frostbiteMultiplier
        case .closed: vulnerabilityMultiplier = 1.0
        case .none: break
        }

        if burn.stacks > 0 {
            totalDOT += burn.tick(deltaTime, decayInterval: GameConfig.Fire.burnStackDecayInterval)
            if burn.stacks != drawnBurnStacks || burn.isDormant != drawnBurnDormant {
                refreshBurnVisual()
            }
        }
        
        if bleedTimer > 0 {
            bleedTimer -= deltaTime
            totalDOT += bleedDPS * bleedDamageMultiplier
            if bleedTimer <= 0 { bleedDPS = 0 }
        }
        
        if slowTimer > 0 {
            slowTimer -= deltaTime
            if slowTimer <= 0 {
                currentSlow = 0
                bodyNode.fillColor = SKColor(hex: baseBodyHex)
                leftEye.fillColor = SKColor(hex: baseEyeHex)
                rightEye.fillColor = SKColor(hex: baseEyeHex)
            }
        }
        
        if totalDOT > 0 {
            dotAccumulator += totalDOT * CGFloat(deltaTime)
            if dotAccumulator >= 1.0 {
                let dmg = Int(dotAccumulator)
                dotAccumulator -= CGFloat(dmg)
                return takeDamage(dmg)
            }
        }
        
        return false
    }
    
    // MARK: - Damage
    
    @discardableResult
    func takeDamage(_ amount: Int) -> Bool {
        // v2.1 A0: a dying enemy can't die again. Re-hits used to return
        // "killed" a second time — the root of every duplicate kill credit.
        guard !isDying else { return false }

        // v2.1 A2 Whiteout T3 (CL-7): damaging a snowman MELTS it. The form is
        // consumed FIRST, so the extra damage below can never re-trigger it.
        // Normals die outright; an elite takes the hit, then an additional
        // 20% of its max HP — and may die to either.
        switch snowman.onDamage(amount, isBossClass: isMiniBoss, maxHealth: maxHealth,
                                eliteFraction: GameConfig.Chill.snowmanEliteMeltFraction) {
        case .none:
            break
        case .dies:
            endSnowman(melted: true)
            finishingDamage = max(0, health)
            health = 0
            onDeath()
            return true
        case .elite(let extra):
            endSnowman(melted: true)
            if takeDamage(amount) { return true }
            return takeDamage(extra)
        }

        // v1.9: general vulnerability scales every incoming hit (1.0 = no change).
        let scaled = vulnerabilityMultiplier == 1.0
            ? amount
            : Int((CGFloat(amount) * vulnerabilityMultiplier).rounded())
        let healthBefore = health
        health -= scaled

        if health <= 0 {
            finishingDamage = max(0, min(scaled, healthBefore))
            onDeath()
            return true
        }
        
        // Hit flash — eyes flare bright
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.bodyNode.fillColor = SKColor(hex: 0x333333)
                self?.leftEye.fillColor = .white
                self?.rightEye.fillColor = .white
            },
            SKAction.wait(forDuration: 0.06),
            SKAction.run { [weak self] in
                guard let self else { return }
                self.bodyNode.fillColor = SKColor(hex: self.baseBodyHex)
                self.leftEye.fillColor = SKColor(hex: self.baseEyeHex)
                self.rightEye.fillColor = SKColor(hex: self.baseEyeHex)
            }
        ])
        run(flash)
        
        return false
    }
    
    // MARK: - Knockback
    
    func applyKnockback(from sourcePosition: CGPoint, force: CGFloat) {
        let direction = (position - sourcePosition).normalized
        position += direction * force
    }
    
    // MARK: - Death
    
    private func onDeath() {
        isDying = true
        physicsBody?.categoryBitMask = 0

        // Eyes flare out, body shrinks
        let deathAnim = SKAction.group([
            SKAction.scale(to: 0.0, duration: 0.2),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.run { [weak self] in
                self?.leftEye.run(SKAction.scale(to: 2.0, duration: 0.15))
                self?.rightEye.run(SKAction.scale(to: 2.0, duration: 0.15))
            }
        ])
        run(SKAction.sequence([deathAnim, SKAction.removeFromParent()]))
    }
    
    // MARK: - Spawn
    
    static func spawnPosition() -> CGPoint {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = GameConfig.Wave.spawnDistance
        return CGPoint(
            x: cos(angle) * distance,
            y: sin(angle) * distance
        )
    }
}
