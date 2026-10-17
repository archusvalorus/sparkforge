// A7-2: crossing controller. State owns time/hits; shape is render-only.
import SpriteKit

final class TollkeeperNode: EnemyNode {
    private(set) var attack = TollkeeperState()
    private var pendingPlan: TollkeeperPlan?
    private let attackVisual = SKShapeNode()
    var onAimStart: (() -> Void)?
    var schedule: ChannelAttackSchedule?
    var attackRect: CGRect? { attack.attackRect }

    init() {
        super.init(health: 1, moveSpeed: GameConfig.Enemy.baseSpeed, xpValue: 3)
        setBodyPalette(body: 0x28231F, rim: 0x82796D, eye: 0xC58BFF)
        let fork = CGMutablePath()
        let r = GameConfig.Enemy.visualRadius
        fork.move(to: CGPoint(x: -r*1.4, y: r*0.5))
        fork.addLine(to: CGPoint(x: r*1.4, y: r*0.5))
        for x: CGFloat in [-1.4, 1.4] {
            fork.move(to: CGPoint(x: x*r, y: r*0.5))
            fork.addLine(to: CGPoint(x: x*r, y: r*1.35))
        }
        let chassis = SKShapeNode(path: fork)
        chassis.strokeColor = SKColor(hex: 0xB6AC98); chassis.lineWidth = 3; chassis.zPosition = 7
        addChild(chassis)
        attackVisual.strokeColor = SKColor(hex: 0xC58BFF)
        attackVisual.lineWidth = 2; attackVisual.zPosition = -1
        attackVisual.isHidden = true
        addChild(attackVisual)
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    func cancelAttack() {
        attack.cancel(); pendingPlan = nil; attackVisual.isHidden = true
        schedule?.finish(.tollkeeper)
    }

    func approachGoal(player: CGPoint, geometry: ArenaGeometry, radius: CGFloat, disabled: Bool) -> CGPoint {
        if disabled || isDying || isFrozen || isStunned { cancelAttack(); return player }
        if attack.phase == .seek {
            if let plan = pendingPlan,
               !TollkeeperState.valid(plan, player: player, bodyRadius: geometryFootprintRadius,
                   geometry: geometry, radius: radius) { pendingPlan = nil }
            if pendingPlan == nil {
                pendingPlan = TollkeeperState.choosePlan(from: position, player: player,
                    bodyRadius: geometryFootprintRadius, geometry: geometry, radius: radius)
            }
        }
        return (attack.plan ?? pendingPlan)?.anchor ?? player
    }

    override func chase(target: CGPoint, deltaTime dt: TimeInterval, globalSlow: CGFloat = 0) {
        let disabled = isDying || isFrozen || isStunned || isVoidTrapped || isFeared
        let plan = attack.plan ?? pendingPlan
        let atAnchor = plan.map { position.distance(to: $0.anchor) <= GameConfig.Tollkeeper.arriveRadius } ?? false
        let before = attack.phase
        var candidate = pendingPlan
        if attack.phase == .seek, let schedule = schedule {
            if !atAnchor || attack.cooldown > 0 || !schedule.request(.tollkeeper) { candidate = nil }
        }
        attack.step(dt, disabled: disabled, atAnchor: atAnchor, candidate: candidate)
        if disabled || ((before == .windup || before == .pulse) && attack.phase == .recovery) {
            schedule?.finish(.tollkeeper)
        }
        if attack.phase == .windup && before != .windup { onAimStart?() }
        if attack.phase == .seek && !disabled {
            super.chase(target: target, deltaTime: dt, globalSlow: globalSlow)
        }
    }

    func consumePulse(player: CGPoint, radius: CGFloat) -> Bool {
        guard !isDying, !isFrozen, !isStunned, !isVoidTrapped, !isFeared else { cancelAttack(); return false }
        guard attack.phase == .pulse else { return false }
        guard let plan = attack.plan,
              position.distance(to: plan.anchor) <= GameConfig.Tollkeeper.arriveRadius else { cancelAttack(); return false }
        return attack.consumeHit(player: player, radius: radius)
    }

    /// Called after actions/physics: the locked rectangle does not follow a shove.
    func syncAttackVisual() {
        guard !isDying, let rect = attackRect else { attackVisual.isHidden = true; return }
        attackVisual.path = CGPath(rect: CGRect(origin: .zero, size: rect.size), transform: nil)
        attackVisual.position = rect.origin - position
        attackVisual.fillColor = SKColor(hex: 0xBB44FF, alpha: attack.phase == .pulse ? 0.55 : 0.12)
        attackVisual.isHidden = false
    }
}
