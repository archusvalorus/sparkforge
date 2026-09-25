// ProjectileNode.swift
// Sparkforge
//
// Phase 3: Supports pierce, variable speed/range, carries stat snapshot.

import SpriteKit

final class ProjectileNode: SKNode {
    
    private let bulletNode: SKShapeNode
    private let direction: CGPoint
    private var distanceTraveled: CGFloat = 0
    
    /// Max range for this specific projectile
    let maxRange: CGFloat
    /// Speed for this projectile
    let projectileSpeed: CGFloat
    /// How many enemies this can still pierce through
    var remainingPierces: Int
    /// Damage multiplier snapshot
    let damageMultiplier: CGFloat
    /// Crit check snapshot
    let isCrit: Bool
    /// Whether to spawn gravity well on expire
    let spawnsGravityWell: Bool
    /// v1.9 Polar Vortex (T4): a condensed icicle that shatters into shards on hit
    let isIcicle: Bool
    /// v2.0 Phase C (C1.4): Seed Spore Shot generation carried by a FRAGMENT.
    /// 0 = a normal shot; ≥1 = a burst fragment, used to cap re-embedding.
    var seedGeneration: Int = 0
    /// v2.1 A0: what a kill by this projectile credits as. Set at spawn.
    var killSource: KillSource = .primary
    /// v2.1 A4a (Brandon, Sep 21): does this hit count as a PRIMARY hit for
    /// primary-hit riders (Bloodthirsty)? Polar Vortex's icicle replaces
    /// Spark's primary shot, so it inherits the eligibility — its kill still
    /// credits as `.capstone` — while the shards it shatters into do not.
    var isPrimaryHit: Bool { killSource == .primary || isIcicle }
    /// v2.1 A4b Glass Blood (CL-27/28): > 0 marks a Glass Blood fragment and is
    /// the Bleed generation it inflicts. Fragments deal plain damage — no crit,
    /// no pierce, no other on-hit procs — and always Bleed a survivor.
    var glassBloodGeneration = 0
    /// v2.1 A2 (CL-3): whether this projectile applies Frost Touch's slow.
    /// True for everything EXCEPT Iceburst shards and icicle fragments, which
    /// earn it at Frost Touch T3 — opted in specifically, not by a blanket flag.
    var appliesFrostTouch = true
    /// v2.1 A2: an Iceburst shard's generation. A kill by a gen-2 shard (one
    /// born from a shard's own kill) doesn't burst again — the cascade cap.
    var iceburstGeneration = 0

    // MARK: v2.1 A6 — Void

    /// A6's own secondary Void attacks take a separate, named-effects-only hit
    /// path (CL-4, CL-75/QB): never crit, never a primary hit, no riders.
    var voidKind: VoidSecondaryKind = .none
    /// CL-70 (independent review F3): ONE probabilistic-rounding threshold per
    /// projectile, drawn at launch and shared by every A6 fractional damage it
    /// resolves — so a falling exact sequence (Warp over flight, Riftline per
    /// body) can never realize a rise, while each projectile stays unbiased.
    let a6Rounding = A6Rounding()
    /// The A6 fraction a secondary Void attack applies to the shot's legacy
    /// damage (Shadow Edge 1.25; a returned shot 1.0) — CL-70 rounds only this.
    var voidDamageFraction: CGFloat = 1
    /// What this hit carries from the Void (CL-71/72).
    var voidHit: VoidHit = .none
    /// Warp Shot (CL-14): primary shots only. nil = a normal shot.
    private(set) var warp: WarpCurve?
    /// Game time since launch — Warp reads its speed and damage from it.
    private(set) var age: TimeInterval = 0
    /// ×3 Blackhole (CL-76): this volley's lead shot opens a black hole
    /// wherever it finally stops.
    var seedsBlackhole = false
    /// Bodies this shot has already struck — Riftline's falloff (CL-81).
    private(set) var bodiesStruck = 0
    private var warpTrail: SKShapeNode?

    init(direction: CGPoint,
         speed: CGFloat = GameConfig.Projectile.speed,
         range: CGFloat = GameConfig.Projectile.maxRange,
         pierces: Int = 0,
         damageMultiplier: CGFloat = 1.0,
         isCrit: Bool = false,
         spawnsGravityWell: Bool = false,
         voidStyle: Bool = false,
         isIcicle: Bool = false,
         frostStyle: Bool = false,
         seedStyle: Bool = false,
         bloodStyle: Bool = false,
         bladeStyle: Bool = false,
         returnedStyle: Bool = false,
         bodyRadius: CGFloat? = nil) {
        self.isIcicle = isIcicle

        self.direction = direction.normalized
        self.projectileSpeed = speed
        self.maxRange = range
        self.remainingPierces = pierces
        self.damageMultiplier = damageMultiplier
        self.isCrit = isCrit
        self.spawnsGravityWell = spawnsGravityWell

        let config = GameConfig.Projectile.self
        let radius = isCrit ? config.radius * 1.5 : config.radius

        if isIcicle {
            // v1.9 Polar Vortex (T4): a big icy shard oriented along travel.
            bulletNode = SKShapeNode(ellipseOf: CGSize(width: radius * 5.0, height: radius * 2.2))
            bulletNode.fillColor = SKColor(hex: 0xCCF2FF)
            bulletNode.strokeColor = SKColor(hex: 0x66CCFF, alpha: 0.95)
            bulletNode.lineWidth = 1.5
            bulletNode.glowWidth = 7
            bulletNode.zRotation = atan2(direction.y, direction.x)
        } else if bladeStyle {
            // v2.1 A6 Shadow Edge (CL-86 placeholder): a long dark crescent with
            // an indigo rim, broadside to travel — wide, like the blade it is.
            let r = bodyRadius ?? radius * 7
            let path = CGMutablePath()
            path.addArc(center: CGPoint(x: -r * 0.55, y: 0), radius: r,
                        startAngle: -.pi / 3, endAngle: .pi / 3, clockwise: false)
            path.addArc(center: CGPoint(x: -r * 0.85, y: 0), radius: r * 0.92,
                        startAngle: .pi / 3.2, endAngle: -.pi / 3.2, clockwise: true)
            path.closeSubpath()
            bulletNode = SKShapeNode(path: path)
            bulletNode.fillColor = SKColor(hex: 0x0E0B1C, alpha: 0.95)
            bulletNode.strokeColor = SKColor(hex: GameConfig.VoidTree.indigoLightHex, alpha: 0.95)
            bulletNode.lineWidth = 1.5
            bulletNode.glowWidth = 5
            bulletNode.zRotation = atan2(direction.y, direction.x)
        } else if returnedStyle {
            // v2.1 A6 returned shot (CL-86): indigo with a white core.
            bulletNode = SKShapeNode(circleOfRadius: radius * 1.2)
            bulletNode.fillColor = SKColor(hex: 0xFFFFFF)
            bulletNode.strokeColor = SKColor(hex: GameConfig.VoidTree.indigoHex, alpha: 0.95)
            bulletNode.lineWidth = 2
            bulletNode.glowWidth = 5
        } else if voidStyle {
            // v1.9 Erasure Void-Touched (T2): an empowered, elongated bolt
            // oriented along travel — reads as "these shots pierce reality."
            // v2.1 A6 (CL-86): player-Void indigo, never the danger purple.
            bulletNode = SKShapeNode(ellipseOf: CGSize(width: radius * 3.6, height: radius * 1.4))
            bulletNode.fillColor = isCrit ? SKColor(hex: 0x9FB4FF) : SKColor(hex: GameConfig.VoidTree.indigoLightHex)
            bulletNode.strokeColor = SKColor(hex: GameConfig.VoidTree.indigoDeepHex, alpha: 0.9)
            bulletNode.lineWidth = 1
            bulletNode.glowWidth = isCrit ? 7 : 5
            bulletNode.zRotation = atan2(direction.y, direction.x)
        } else if frostStyle {
            // v1.9 Polar Vortex (T1+): the storm chills your shots frost-blue.
            bulletNode = SKShapeNode(circleOfRadius: radius)
            bulletNode.fillColor = isCrit ? SKColor(hex: 0xAEE9FF) : SKColor(hex: 0x66CCFF)
            bulletNode.strokeColor = SKColor(hex: 0x2E9BD6, alpha: 0.8)
            bulletNode.lineWidth = 0.5
            bulletNode.glowWidth = isCrit ? 5 : 3
        } else if bloodStyle {
            // v2.1 A4b Glass Blood: a small blood-glass shard along travel.
            bulletNode = SKShapeNode(ellipseOf: CGSize(width: radius * 2.4, height: radius * 1.1))
            bulletNode.fillColor = SKColor(hex: 0xE0203A)
            bulletNode.strokeColor = SKColor(hex: 0xFF8A99, alpha: 0.85)
            bulletNode.lineWidth = 0.5
            bulletNode.glowWidth = 2
            bulletNode.zRotation = atan2(direction.y, direction.x)
        } else if seedStyle {
            // v2.0 Phase C: a spore — seed-gold, small, with a soft green glow.
            bulletNode = SKShapeNode(circleOfRadius: radius * 0.85)
            bulletNode.fillColor = SKColor(hex: 0xC9D96F)
            bulletNode.strokeColor = SKColor(hex: 0x5FCF62, alpha: 0.8)
            bulletNode.lineWidth = 0.5
            bulletNode.glowWidth = 3
        } else {
            bulletNode = SKShapeNode(circleOfRadius: radius)
            bulletNode.fillColor = isCrit ? SKColor(hex: 0xFF4444) : SKColor(hex: config.colorHex)
            bulletNode.strokeColor = .clear
            bulletNode.glowWidth = isCrit ? 5 : 3
        }

        super.init()

        addChild(bulletNode)
        setupPhysics(radius: bodyRadius ?? GameConfig.Projectile.radius)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    private func setupPhysics(radius: CGFloat) {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.categoryBitMask = GameConfig.Physics.projectile
        body.contactTestBitMask = GameConfig.Physics.enemy
        body.collisionBitMask = 0
        physicsBody = body
    }
    
    /// Call each frame. Returns true if projectile should be removed.
    /// v2.1 A6: a Warp shot moves at its curve's speed for its current age.
    func move(deltaTime: TimeInterval) -> Bool {
        let speedFraction = warp?.speedFraction(age: age) ?? 1
        let displacement = direction * projectileSpeed * speedFraction * CGFloat(deltaTime)
        position += displacement
        distanceTraveled += displacement.length
        age += deltaTime
        if let warp = warp, let trail = warpTrail {
            // The streak is the charge: long while slow (hitting harder),
            // gone once the shot reaches full speed.
            let left = 1 - warp.progress(age: age)
            trail.xScale = max(0.01, left)
            trail.alpha = 0.25 + 0.6 * left
        }
        return distanceTraveled >= maxRange
    }

    /// v2.1 A6 (CL-14): make this a Warp shot, with its placeholder tell.
    func enableWarp(_ curve: WarpCurve) {
        warp = curve
        let r = GameConfig.Projectile.radius
        let trail = SKShapeNode(rectOf: CGSize(width: r * 6, height: r * 1.2), cornerRadius: r * 0.6)
        trail.fillColor = SKColor(hex: GameConfig.VoidTree.indigoLightHex, alpha: 0.8)
        trail.strokeColor = .clear
        trail.position = CGPoint(x: -direction.x * r * 3, y: -direction.y * r * 3)
        trail.zRotation = atan2(direction.y, direction.x)
        trail.zPosition = -1
        addChild(trail)
        warpTrail = trail
    }

    /// Called when hitting an enemy. Returns true if projectile should be consumed.
    /// (v2.1 A6: also counts the bodies struck, for Riftline's falloff.)
    func onHitEnemy() -> Bool {
        bodiesStruck += 1
        if remainingPierces > 0 {
            remainingPierces -= 1
            // Brief flash to show pierce
            let flash = SKAction.sequence([
                SKAction.scale(to: 0.7, duration: 0.03),
                SKAction.scale(to: 1.0, duration: 0.03)
            ])
            run(flash)
            return false  // Don't consume
        }
        return true  // Consume projectile
    }
}

/// v2.1 A6 (CL-76): a ProjectileNode carries the ×3 Blackhole seed.
extension ProjectileNode: BlackholeSeedCarrier {}
