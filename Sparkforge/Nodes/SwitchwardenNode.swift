// A7-4: expressive procedural DEBUG boss; no registry/unlock/reward integration.
import SpriteKit

final class SwitchwardenNode: SKNode, ArenaBossNode, PlayerReachHazards {
    private(set) var health = GameConfig.Marchwarden.baseHealth
    private(set) var maxHealth = GameConfig.Marchwarden.baseHealth
    private(set) var isDead = false
    var vulnerability = VulnerabilityChannels()
    var challengeFlatReduction = 0
    var healthPercent: CGFloat { maxHealth > 0 ? CGFloat(health)/CGFloat(maxHealth) : 0 }
    var contactDamage: Int { GameConfig.Marchwarden.contactDamage }
    var geometryFootprintRadius: CGFloat { GameConfig.Arena.radius*GameConfig.Switchwarden.bodyFraction }
    var hitBodyRadius: CGFloat { geometryFootprintRadius*0.85 }
    var targetingRadius: CGFloat { hitBodyRadius }
    var statusTellAnchor: CGPoint { CGPoint(x: geometryFootprintRadius+8, y: geometryFootprintRadius+20) }
    var playerHitRadius: CGFloat = GameConfig.Player.collisionRadius
    var playerMoveSpeed: CGFloat = GameConfig.Player.speed
    var onLethalHit: ((Int)->Void)?
    var onDeath: (()->Void)?
    var schedule: ChannelAttackSchedule?
    var planProvider: ((CGPoint)->SwitchwardenPlan?)?
    var geometry = ArenaGeometry.twinChannels
    private(set) var attack = SwitchwardenState()
    private var pendingPlan: SwitchwardenPlan?
    private let mask = SKShapeNode()
    private let eyes = [SKShapeNode(), SKShapeNode()]
    private let brows = [SKShapeNode(), SKShapeNode()]
    private let mustache = [SKShapeNode(), SKShapeNode()]
    private let arms = [SKShapeNode(), SKShapeNode()]
    private let mouth = SKShapeNode()
    private let floor = SKShapeNode()
    private let hatching = SKShapeNode()
    private let hp = SKShapeNode()

    override init() {
        super.init()
        let r = geometryFootprintRadius
        let body = SKShapeNode(rectOf: CGSize(width:r*1.7,height:r*1.6),cornerRadius:r*0.22)
        body.fillColor=SKColor(hex:0x28231F);body.strokeColor=SKColor(hex:0x82796D);body.lineWidth=3;addChild(body)
        for sign:CGFloat in [-1,1] {
            let boot=SKShapeNode(rectOf:CGSize(width:r*0.55,height:r*0.3),cornerRadius:3)
            boot.position=CGPoint(x:sign*r*0.4,y:-r*0.8);boot.fillColor=SKColor(hex:0x39332C);boot.strokeColor=SKColor(hex:0x82796D);addChild(boot)
        }
        mask.path=CGPath(roundedRect:CGRect(x:-r*0.6,y:-r*0.35,width:r*1.2,height:r*1.3),cornerWidth:r*0.2,cornerHeight:r*0.2,transform:nil)
        mask.fillColor=SKColor(hex:0xD9D2C4);mask.strokeColor=SKColor(hex:0x514A43);mask.zPosition=2;addChild(mask)
        for i in 0..<2 {
            let sign:CGFloat=i==0 ? -1:1
            eyes[i].path=CGPath(ellipseIn:CGRect(x:-r*0.14,y:-r*0.10,width:r*0.28,height:r*0.20),transform:nil)
            eyes[i].position=CGPoint(x:sign*r*0.25,y:r*0.5);eyes[i].fillColor=SKColor(hex:0x28231F);eyes[i].strokeColor = .clear;eyes[i].zPosition=3;addChild(eyes[i])
            brows[i].path=CGPath(rect:CGRect(x:-r*0.18,y:0,width:r*0.36,height:r*0.07),transform:nil)
            brows[i].position=CGPoint(x:sign*r*0.25,y:r*0.72);brows[i].fillColor=SKColor(hex:0x39332C);brows[i].strokeColor = .clear;brows[i].zPosition=4;addChild(brows[i])
            let curl=CGMutablePath();curl.move(to:.zero);curl.addCurve(to:CGPoint(x:sign*r*0.63,y:r*0.15),control1:CGPoint(x:sign*r*0.3,y:-r*0.2),control2:CGPoint(x:sign*r*0.7,y:-r*0.1))
            mustache[i].path=curl;mustache[i].position=CGPoint(x:0,y:r*0.17);mustache[i].strokeColor=SKColor(hex:0x1A1816);mustache[i].lineWidth=r*0.16;mustache[i].lineCap = .round;mustache[i].zPosition=5;addChild(mustache[i])
            arms[i].path=CGPath(roundedRect:CGRect(x:0,y:-r*0.1,width:r*(i==0 ? 1.1:0.75),height:r*(i==0 ? 0.35:0.2)),cornerWidth:3,cornerHeight:3,transform:nil)
            arms[i].position=CGPoint(x:sign*r*0.72,y:-r*0.15);arms[i].xScale=sign;arms[i].fillColor=SKColor(hex:0x514A43);arms[i].strokeColor=SKColor(hex:0xB6AC98);arms[i].zPosition=1;addChild(arms[i])
        }
        mouth.path=CGPath(rect:CGRect(x:-r*0.18,y:-r*0.22,width:r*0.36,height:r*0.16),transform:nil)
        mouth.fillColor=SKColor(hex:0x28231F);mouth.strokeColor = .clear;mouth.zPosition=3;addChild(mouth)
        hp.position=CGPoint(x:0,y:r+20);hp.fillColor=SKColor(hex:0xB6AC98);hp.strokeColor = .clear;addChild(hp)
        let label=SKLabelNode(fontNamed:"Menlo-Bold");label.text="THE SWITCHWARDEN · DEV";label.fontSize=9;label.position=CGPoint(x:0,y:r+30);addChild(label)
        floor.zPosition = -2;floor.lineWidth=2;floor.strokeColor=SKColor(hex:0xC58BFF);floor.addChild(hatching);hatching.strokeColor=SKColor(hex:0xC58BFF,alpha:0.45);hatching.lineWidth=1;addChild(floor)
        let physics=SKPhysicsBody(circleOfRadius:hitBodyRadius);physics.isDynamic=true;physics.affectedByGravity=false;physics.allowsRotation=false
        physics.categoryBitMask=GameConfig.Physics.enemy;physics.contactTestBitMask=GameConfig.Physics.player|GameConfig.Physics.projectile;physics.collisionBitMask=0;physicsBody=physics
        syncVisual()
    }
    required init?(coder:NSCoder){fatalError("init(coder:) not implemented")}

    func cancelAttack() {
        attack.cancel();pendingPlan=nil;schedule?.finish(.switchwarden);floor.isHidden=true
    }
    func update(deltaTime dt:TimeInterval,playerPosition:CGPoint) {
        guard !isDead, dt.isFinite, dt >= 0 else{return}
        guard declarationValid() else{return}
        if attack.phase == .seek {pendingPlan=planProvider?(position)}
        let plan=attack.plan ?? pendingPlan
        let atAnchor=plan.map{position.distance(to:$0.anchor)<=GameConfig.Switchwarden.arriveRadius} ?? false
        var candidate=pendingPlan
        if attack.phase == .seek {
            if !atAnchor || attack.cooldown>0 {candidate=nil}
            else if let schedule=schedule,!schedule.request(.switchwarden){candidate=nil}
        }
        let wasArmed=attack.armed
        attack.step(dt,disabled:false,atAnchor:atAnchor,candidate:candidate)
        if wasArmed && !attack.armed {schedule?.finish(.switchwarden)}
        if attack.phase == .seek,let plan=pendingPlan {
            let goal:CGPoint
            if geometry.segmentBlockedExact(position,plan.anchor,travelRadius:geometryFootprintRadius) {
                goal=geometry.graphWaypoint(from:position,toward:plan.anchor,travelRadius:geometryFootprintRadius,
                    arriveRadius:GameConfig.Switchwarden.arriveRadius)?.position ?? position
            }else{goal=plan.anchor}
            let delta=goal-position
            position += delta.normalized*min(delta.length,GameConfig.Marchwarden.idleSpeed*CGFloat(dt))
        }
        syncVisual()
    }
    func consumeSurge(player:CGPoint) -> Bool {
        guard !isDead else{return false}
        guard declarationValid() else{return false}
        guard attack.phase == .surge else{return false}
        return attack.consumeHit(player:player,radius:playerHitRadius)
    }
    func declarationValid() -> Bool {
        guard attack.armed else{return true}
        guard let plan=attack.plan,
              plan.supports(playerRadius:playerHitRadius,moveSpeed:playerMoveSpeed),
              position.distance(to:plan.anchor)<=GameConfig.Switchwarden.arriveRadius else{cancelAttack();return false}
        return true
    }
    func applyChallengeHealthScale(_ factor:CGFloat){guard factor.isFinite,factor>0 else{return};maxHealth=max(1,Int((CGFloat(maxHealth)*factor).rounded()));health=maxHealth}
    @discardableResult
    func takeDamage(_ amount:Int,ignoresChallengeDEF:Bool,resolved:Int?) -> Bool {
        guard !isDead else{return false}
        let scaled = resolved ?? (vulnerabilityMultiplier == 1.0 ? amount : Int((CGFloat(amount) * vulnerabilityMultiplier).rounded()))
        let dealt=challengedDamage(scaled,raw:amount,ignoresChallengeDEF:ignoresChallengeDEF)
        let before=health;health=max(0,health-dealt)
        if health==0 {
            isDead=true;cancelAttack();physicsBody?.categoryBitMask=0
            onLethalHit?(min(dealt,before));onDeath?();removeFromParent();return true
        }
        syncVisual();return false
    }
    func syncVisual() {
        let warning=attack.phase == .warning, surge=attack.phase == .surge, tired=attack.phase == .recovery
        let charge:CGFloat=warning ? CGFloat(max(0,min(1,1-attack.remaining/(attack.plan?.warning ?? GameConfig.Switchwarden.warning)))) : 0
        for i in 0..<2 {
            let sign:CGFloat=i==0 ? -1:1
            brows[i].zRotation=warning ? sign*0.25:(tired ? sign*0.1:0)
            eyes[i].yScale=surge ? 0.45:(tired ? 0.6:1)
            mustache[i].zRotation=tired ? -sign*0.22:(warning ? sign*0.1:0)
            arms[i].zRotation=warning ? sign*(0.35+0.45*charge):(surge ? sign*0.8:-sign*0.35)
            arms[i].fillColor=warning || surge ? SKColor(hex:0xC58BFF):SKColor(hex:0x514A43)
        }
        mouth.yScale=tired ? 1.5:(surge ? 0.5:1)
        hp.path=CGPath(rect:CGRect(x:-geometryFootprintRadius,y:-2,width:max(1,2*geometryFootprintRadius*healthPercent),height:4),transform:nil)
        guard !isDead,attack.armed,let rect=attack.plan?.rect else{floor.isHidden=true;return}
        floor.path=CGPath(rect:rect,transform:nil);floor.position = .zero-position
        floor.fillColor=SKColor(hex:0xBB44FF,alpha:surge ? 0.50:CGFloat(0.08+0.14*charge));floor.isHidden=false
        floor.lineWidth=warning ? CGFloat(1+2*charge):2;hatching.alpha=warning ? CGFloat(0.35+0.65*charge):1
        let lines=CGMutablePath()
        for i in 0...12 {let x=rect.minX+rect.width*CGFloat(i)/12;lines.move(to:CGPoint(x:x,y:rect.minY));lines.addLine(to:CGPoint(x:x,y:rect.maxY))}
        hatching.path=lines
    }
}
