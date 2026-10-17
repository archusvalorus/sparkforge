// A7-3: low planted rail gun. Presentation does not own launches or damage.
import SpriteKit

final class RailspikeNode: EnemyNode {
    private(set) var attack = RailspikeState()
    private var pendingPlan: RailspikePlan?
    var schedule: ChannelAttackSchedule?
    var canBeginTell = true
    var onAimStart: (() -> Void)?
    private let rail = SKShapeNode()
    private let charges = [SKShapeNode(circleOfRadius: 3), SKShapeNode(circleOfRadius: 3)]
    var attackRect: CGRect? { attack.plan?.rect }

    init() {
        super.init(health: 1, moveSpeed: GameConfig.Enemy.baseSpeed*0.8, xpValue: 3)
        setBodyPalette(body: 0x28231F, rim: 0x82796D, eye: 0xC58BFF)
        let r = GameConfig.Enemy.visualRadius
        let chassis = SKShapeNode(rectOf: CGSize(width: r*1.3, height: r*3.3), cornerRadius: 3)
        chassis.fillColor = SKColor(hex: 0x39332C); chassis.strokeColor = SKColor(hex: 0xB6AC98)
        chassis.lineWidth = 2; chassis.zPosition = 6; addChild(chassis)
        for (i, light) in charges.enumerated() {
            light.position = CGPoint(x: i == 0 ? -r*0.6 : r*0.6, y: 0)
            light.fillColor = SKColor(hex: 0xC58BFF); light.strokeColor = .clear
            light.zPosition = 8; addChild(light)
        }
        rail.strokeColor = SKColor(hex: 0xC58BFF); rail.fillColor = SKColor(hex: 0xBB44FF, alpha: 0.12)
        rail.lineWidth = 1; rail.zPosition = -1; rail.isHidden = true; addChild(rail)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    func cancelAttack() {
        attack.cancel(); pendingPlan = nil; rail.isHidden = true
        schedule?.finish(.railspike)
    }

    func approachGoal(player: CGPoint, geometry: ArenaGeometry, radius: CGFloat, disabled: Bool) -> CGPoint {
        if disabled || isDying || isFrozen || isStunned { cancelAttack(); return player }
        if attack.phase == .seek {
            // A pre-tell plan can move with Spark; the committed plan never does.
            pendingPlan = RailspikeState.choosePlan(from: position, player: player,
                bodyRadius: geometryFootprintRadius, geometry: geometry, radius: radius)
        }
        return (attack.plan ?? pendingPlan)?.anchor ?? player
    }

    override func chase(target: CGPoint, deltaTime dt: TimeInterval, globalSlow: CGFloat = 0) {
        let disabled = isDying || isFrozen || isStunned || isVoidTrapped || isFeared
        let plan = attack.plan ?? pendingPlan
        let atAnchor = plan.map { position.distance(to: $0.anchor) <= GameConfig.Railspike.arriveRadius } ?? false
        var candidate = pendingPlan
        if attack.phase == .seek {
            if !canBeginTell || !atAnchor || attack.cooldown > 0 { candidate = nil }
            else if let schedule = schedule, !schedule.request(.railspike) { candidate = nil }
        }
        let before = attack.phase
        attack.step(dt, disabled: disabled, atAnchor: atAnchor, candidate: candidate)
        if attack.phase == .windup && before != .windup { onAimStart?() }
        if disabled || ((before == .windup || before == .interval) && attack.phase == .recovery) {
            schedule?.finish(.railspike)
        }
        if attack.phase == .seek && !disabled {
            super.chase(target: target, deltaTime: dt, globalSlow: globalSlow)
        }
    }

    /// Scene calls after physics and all death cascades. Fresh status/position wins.
    func consumeLaunch() -> RailspikePlan? {
        guard !isDying, !isFrozen, !isStunned, !isVoidTrapped, !isFeared,
              let plan = attack.plan,
              position.distance(to: plan.anchor) <= GameConfig.Railspike.arriveRadius else {
            if attack.armed { cancelAttack() }; return nil
        }
        let launch = attack.consumeLaunch()
        if attack.phase == .recovery { schedule?.finish(.railspike) }
        return launch
    }

    func syncAttackVisual() {
        for (i, light) in charges.enumerated() { light.isHidden = !attack.armed || i < attack.shots }
        guard !isDying, let rect = attackRect else { rail.isHidden = true; return }
        rail.path = CGPath(rect: CGRect(origin: .zero, size: rect.size), transform: nil)
        rail.position = rect.origin-position; rail.isHidden = false
    }
}
