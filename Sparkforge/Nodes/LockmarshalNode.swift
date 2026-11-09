// DEBUG-only isolated Arena8 body/two-verb proof. Not a registered boss.
#if DEBUG
import SpriteKit

final class LockmarshalNode: SKNode, ArenaBossNode, PlayerReachHazards {
    private typealias C = GameConfig.LockmarshalFixture
    private(set) var health = C.health
    private(set) var maxHealth = C.health
    private(set) var isDead = false
    private(set) var retired = false
    let encounterID=UUID().uuidString
    var healthPercent: CGFloat { CGFloat(health) / CGFloat(maxHealth) }
    var vulnerability = VulnerabilityChannels()
    var challengeFlatReduction = 0
    var contactDamage: Int { C.damage }
    var targetingRadius: CGFloat { C.bodyRadius }
    var geometryFootprintRadius: CGFloat { C.bodyRadius }
    var hitBodyRadius: CGFloat { C.bodyRadius }
    var playerHitRadius: CGFloat = 14
    var onLethalHit: ((Int) -> Void)?
    var canAdvance: (() -> Bool)?
    var onHazardDamage: ((Int) -> Void)?
    var onDeath: (() -> Void)?
    private(set) var model: LockmarshalModel
    private(set) var hazardAttempts = 0
    private(set) var commitments = 0
    private let shell = SKShapeNode(circleOfRadius: C.bodyRadius)
    private let crown = SKShapeNode()
    private let tell = SKShapeNode()
    private let label = SKLabelNode(fontNamed: "Menlo-Bold")
    private let hp = SKShapeNode()
    var statusTellAnchor: CGPoint { CGPoint(x: 38, y: 38) }

    init(map: Arena8GameMap, at root: CGPoint) {
        model = LockmarshalModel(map: map, position: root)
        super.init()
        position = root; name = "lockmarshal-fixture"; zPosition = 6
        shell.fillColor = SKColor(hex: 0x292522); shell.strokeColor = SKColor(hex: 0xD4C49B); shell.lineWidth = 3
        addChild(shell)
        // Key/fork crown remains inside the declared26-point circular body.
        let p = CGMutablePath();p.move(to:CGPoint(x:-16,y:-12));p.addLine(to:CGPoint(x:16,y:-12));p.addLine(to:CGPoint(x:16,y:14));p.addLine(to:CGPoint(x:7,y:14));p.addLine(to:CGPoint(x:7,y:3));p.addLine(to:CGPoint(x:-7,y:3));p.addLine(to:CGPoint(x:-7,y:14));p.addLine(to:CGPoint(x:-16,y:14));p.closeSubpath()
        crown.path=p;crown.fillColor=SKColor(hex:0xBB994D);crown.strokeColor=SKColor(hex:0xF1DFAE);crown.lineWidth=1;addChild(crown)
        tell.name="lockmarshal-ground-tell";tell.zPosition = -1;tell.lineWidth=2;addChild(tell)
        label.text="LOCKMARSHAL · TEST";label.fontSize=10;label.fontColor=SKColor(hex:0xEEDCA4);label.position=CGPoint(x:0,y:50);addChild(label)
        hp.position=CGPoint(x:0,y:36);hp.fillColor=SKColor(hex:0xD4C49B);hp.strokeColor = .clear;addChild(hp)
        let body=SKPhysicsBody(circleOfRadius:C.bodyRadius);body.isDynamic=false
        body.categoryBitMask=GameConfig.Physics.enemy;body.contactTestBitMask=GameConfig.Physics.projectile | GameConfig.Physics.player;body.collisionBitMask=0;physicsBody=body
        render()
    }
    required init?(coder:NSCoder){return nil}
    func update(deltaTime: TimeInterval, playerPosition: CGPoint) {
        guard !isDead, !retired, parent != nil, canAdvance?() ?? true else{return}
        let frame=model.update(deltaTime,player:playerPosition,playerRadius:playerHitRadius)
        position=model.position
        if frame.committed { commitments += 1 }
        render()
        if frame.damage { hazardAttempts += 1;onHazardDamage?(C.damage) }
    }
    func paints(_ worldPoint:CGPoint)->Bool {!tell.isHidden && tell.path?.contains(worldPoint)==true}
    var hasPaintedTell:Bool { !tell.isHidden && tell.path?.isEmpty == false }
    func interruptAttack(){model.interrupt();render()}
    func cancelAttack(){retired=true;physicsBody?.categoryBitMask=0;physicsBody?.contactTestBitMask=0;model.cancel();tell.path=nil;tell.isHidden=true;onHazardDamage=nil;onLethalHit=nil;onDeath=nil;canAdvance=nil}
    func applyChallengeHealthScale(_ factor:CGFloat){
        guard factor.isFinite,factor>0,!isDead else{return}
        maxHealth=max(1,Int((CGFloat(maxHealth)*factor).rounded()));health=maxHealth;render()
    }
    @discardableResult
    func takeDamage(_ amount:Int,ignoresChallengeDEF:Bool,resolved:Int?)->Bool{
        guard !isDead,!retired else{return false}
        let scaled = resolved ?? (vulnerabilityMultiplier == 1.0 ? amount : Int((CGFloat(amount) * vulnerabilityMultiplier).rounded()))
        let dealt=max(0,challengedDamage(scaled,raw:amount,ignoresChallengeDEF:ignoresChallengeDEF))
        let before=health;health=max(0,health-dealt);render()
        guard health==0 else{return false}
        let lethal=onLethalHit,death=onDeath
        isDead=true;cancelAttack();physicsBody?.categoryBitMask=0
        lethal?(min(before,dealt));death?();removeFromParent();return true
    }
    private func render(){
        hp.path=CGPath(rect:CGRect(x:-30,y:0,width:60*healthPercent,height:4),transform:nil)
        tell.position=CGPoint(x:-position.x,y:-position.y)
        let path=CGMutablePath()
        switch model.phase {
        case .thresholdWarning,.advance:
            let delta=model.goal-model.start, length=delta.length
            let rectangle=CGRect(x:-C.bodyRadius,y:-C.bodyRadius,width:length+C.bodyRadius*2,height:C.bodyRadius*2)
            var transform=CGAffineTransform(rotationAngle:atan2(delta.y,delta.x))
            transform.tx=model.start.x;transform.ty=model.start.y
            path.addRoundedRect(in:rectangle,cornerWidth:C.bodyRadius,cornerHeight:C.bodyRadius,transform:transform)
        case .stampWarning:
            path.addPath(LockmarshalModel.stampPath(model.stamp))
        case .recovery where model.stampFlash>0:
            path.addPath(LockmarshalModel.stampPath(model.stamp))
        default:break
        }
        tell.path=path;tell.isHidden=path.isEmpty
        // Purple only for damaging attack footprint; recoveries are unpainted.
        tell.strokeColor=SKColor(hex:0xCA8BFF);tell.fillColor=SKColor(hex:0xAD55EB,alpha:model.phase == .advance || model.stampFlash>0 ? 0.38:0.16)
        label.text="LOCKMARSHAL · \(model.phase.rawValue.uppercased())"
    }
}
#endif
