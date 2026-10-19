// Expressive procedural Arena 7 boss; campaign and Boss Mode share this body.
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
    private(set) var ram = SwitchwardenRamState()
    private(set) var nextCrossing: SwitchwardenCrossing = .north
    private(set) var nextAttackIsRam = false
    private var pendingPlan: SwitchwardenPlan?
    private let mask = SKShapeNode()
    private let eyes = [SKShapeNode(), SKShapeNode()]
    private let brows = [SKShapeNode(), SKShapeNode()]
    private let mustache = [SKShapeNode(), SKShapeNode()]
    private let arms = [SKShapeNode(), SKShapeNode()]
    private let mouth = SKShapeNode()
    private let floor = SKShapeNode()
    private let ramFloor = SKShapeNode()
    private let ramArrow = SKShapeNode()
    private let ramLabel = SKLabelNode(fontNamed:"Menlo-Bold")
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
        let label=SKLabelNode(fontNamed:"Menlo-Bold");label.text="THE SWITCHWARDEN";label.fontSize=9;label.position=CGPoint(x:0,y:r+30);addChild(label)
        floor.zPosition = -2;floor.lineWidth=2;floor.strokeColor=SKColor(hex:0xC58BFF);floor.addChild(hatching);hatching.strokeColor=SKColor(hex:0xC58BFF,alpha:0.45);hatching.lineWidth=1;addChild(floor)
        ramFloor.zPosition = -2;ramFloor.strokeColor=SKColor(hex:0xF3B35C);ramFloor.lineWidth=3
        ramFloor.addChild(ramArrow);ramArrow.strokeColor=SKColor(hex:0xFFF0C7);ramArrow.lineWidth=3
        ramLabel.text="RAM";ramLabel.fontSize=12;ramLabel.fontColor=SKColor(hex:0xFFF0C7)
        ramFloor.addChild(ramLabel);addChild(ramFloor)
        let physics=SKPhysicsBody(circleOfRadius:hitBodyRadius);physics.isDynamic=true;physics.affectedByGravity=false;physics.allowsRotation=false
        physics.categoryBitMask=GameConfig.Physics.enemy;physics.contactTestBitMask=GameConfig.Physics.player|GameConfig.Physics.projectile;physics.collisionBitMask=0;physicsBody=physics
        syncVisual()
    }
    required init?(coder:NSCoder){fatalError("init(coder:) not implemented")}

    func cancelAttack() {
        attack.cancel();ram.cancel();pendingPlan=nil;schedule?.finish(.switchwarden)
        floor.isHidden=true;ramFloor.isHidden=true
    }
    func update(deltaTime dt:TimeInterval,playerPosition:CGPoint) {
        guard !isDead, dt.isFinite, dt >= 0 else{return}
        guard declarationValid() else{return}
        if ram.phase != .ready {
            attack.step(dt,disabled:false,atAnchor:false,candidate:nil)
            let wasArmed=ram.armed
            ram.step(dt,geometry:geometry,bodyRadius:geometryFootprintRadius,arenaRadius:GameConfig.Arena.radius)
            if wasArmed { position=ram.position }
            if wasArmed && !ram.armed { schedule?.finish(.switchwarden) }
        } else if attack.phase != .seek {
            let atAnchor=attack.plan.map{position.distance(to:$0.anchor)<=GameConfig.Switchwarden.arriveRadius} ?? false
            let wasArmed=attack.armed
            attack.step(dt,disabled:false,atAnchor:atAnchor,candidate:nil)
            if wasArmed && !attack.armed { schedule?.finish(.switchwarden) }
        } else {
            attack.step(dt,disabled:false,atAnchor:false,candidate:nil)
            if attack.cooldown > 0 {
                pursue(playerPosition,dt:dt)
            } else if nextAttackIsRam {
                if let plan=SwitchwardenRamPlan.choose(from:position,player:playerPosition,
                    playerRadius:playerHitRadius,moveSpeed:playerMoveSpeed,bodyRadius:geometryFootprintRadius,
                    geometry:geometry,arenaRadius:GameConfig.Arena.radius),
                   schedule?.request(.switchwarden) ?? true {
                    ram.commit(plan);attack.reserveRamCycle();nextAttackIsRam=false;pendingPlan=nil
                } else { pursue(playerPosition,dt:dt) }
            } else {
                pendingPlan=planProvider?(position)
                if let plan=pendingPlan {
                    if position.distance(to:plan.anchor)<=GameConfig.Switchwarden.arriveRadius {
                        if schedule?.request(.switchwarden) ?? true {
                            attack.step(0,disabled:false,atAnchor:true,candidate:plan)
                            if attack.phase == .warning { nextCrossing=nextCrossing.next;nextAttackIsRam=true }
                        } else { pursue(playerPosition,dt:dt) }
                    } else { pursue(playerPosition,dt:dt,toward:plan.anchor) }
                } else { pursue(playerPosition,dt:dt) }
            }
        }
        syncVisual()
    }
    private func pursue(_ player:CGPoint,dt:TimeInterval,toward target:CGPoint? = nil) {
        let standOff=geometryFootprintRadius+playerHitRadius+GameConfig.Switchwarden.standOff
        let distance=position.distance(to:player)
        let relocating=target != nil
        guard relocating || distance > standOff else { return }
        let target=target ?? player
        let goal:CGPoint
        if geometry.segmentBlockedExact(position,target,travelRadius:geometryFootprintRadius) {
            goal=geometry.graphWaypoint(from:position,toward:target,travelRadius:geometryFootprintRadius,
                arriveRadius:GameConfig.Switchwarden.arriveRadius)?.position ?? position
        } else { goal=target }
        let delta=goal-position
        let move=SwitchwardenMotion.advance(from:position,
            to:position+delta.normalized*min(delta.length,GameConfig.Switchwarden.pursuitSpeed*CGFloat(dt)),
            bodyRadius:geometryFootprintRadius,arenaRadius:GameConfig.Arena.radius,geometry:geometry,
            // A completed ram may end inside ordinary pursuit stand-off.
            // Repositioning for a safe cast may withdraw, never move closer.
            avoiding:player,standOff:relocating ? min(standOff,distance) : standOff)
        position=move.position
    }
    func consumeBodyContactAttempt() -> Bool {
        guard !isDead, declarationValid() else { return false }
        return ram.consumeContactAttempt()
    }
    func consumeRam(player:CGPoint) -> Bool {
        guard !isDead, declarationValid() else { return false }
        return ram.consumeSweep(player:player,radius:playerHitRadius,bodyRadius:hitBodyRadius)
    }
    func consumeSurge(player:CGPoint) -> Bool {
        guard !isDead else{return false}
        guard declarationValid() else{return false}
        guard attack.phase == .surge else{return false}
        return attack.consumeHit(player:player,radius:playerHitRadius)
    }
    func declarationValid() -> Bool {
        if ram.armed || ram.pendingSweep {
            guard let plan=ram.plan,plan.supports(playerRadius:playerHitRadius,moveSpeed:playerMoveSpeed),
                  position.distance(to:ram.position) <= 0.001,
                  position.length+geometryFootprintRadius <= GameConfig.Arena.radius+0.000001,
                  !geometry.isBlocked(position,margin:geometryFootprintRadius) else { cancelAttack();return false }
        }
        guard attack.armed else{return true}
        guard let plan=attack.plan,
              plan.supports(playerRadius:playerHitRadius,moveSpeed:playerMoveSpeed),
              position.distance(to:plan.anchor)<=GameConfig.Switchwarden.arriveRadius else{cancelAttack();return false}
        return true
    }
    /// Add the normal campaign/stage ramp before challenge multipliers.
    func applyHealthBonus(_ bonus: Int) {
        maxHealth = max(1, GameConfig.Marchwarden.baseHealth + bonus)
        health = maxHealth
        syncVisual()
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
        let warning=attack.phase == .warning || ram.phase == .warning
        let surge=attack.phase == .surge || ram.phase == .rushing
        let tired=attack.phase == .recovery || ram.phase == .recovery
        let warningTime=ram.phase == .warning ? GameConfig.Switchwarden.ramWarning : (attack.plan?.warning ?? GameConfig.Switchwarden.warning)
        let remaining=ram.phase == .warning ? ram.remaining : attack.remaining
        let charge:CGFloat=warning ? CGFloat(max(0,min(1,1-remaining/warningTime))) : 0
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
        ramFloor.isHidden=true
        if !isDead,ram.armed,let plan=ram.plan {
            let r=geometryFootprintRadius
            var transform=CGAffineTransform(translationX:plan.origin.x,y:plan.origin.y)
                .rotated(by:atan2(plan.direction.y,plan.direction.x))
            ramFloor.path=CGPath(roundedRect:CGRect(x:-r,y:-r,width:plan.distance+2*r,height:2*r),
                cornerWidth:r,cornerHeight:r,transform:&transform)
            ramFloor.position = .zero-position;ramFloor.isHidden=false
            ramFloor.fillColor=SKColor(hex:0xF3B35C,alpha:ram.phase == .rushing ? 0.40 : CGFloat(0.08+0.16*charge))
            let tip=plan.origin+plan.direction*min(plan.distance,r+45)
            let normal=CGPoint(x:-plan.direction.y,y:plan.direction.x)
            let arrow=CGMutablePath();arrow.move(to:plan.origin);arrow.addLine(to:tip)
            arrow.move(to:tip-plan.direction*12+normal*8);arrow.addLine(to:tip);arrow.addLine(to:tip-plan.direction*12-normal*8)
            ramArrow.path=arrow;ramLabel.position=plan.origin+CGPoint(x:0,y:r+16)
        }
        guard !isDead,attack.armed,let rect=attack.plan?.rect else{floor.isHidden=true;return}
        floor.path=CGPath(rect:rect,transform:nil);floor.position = .zero-position
        floor.fillColor=SKColor(hex:0xBB44FF,alpha:surge ? 0.50:CGFloat(0.08+0.14*charge));floor.isHidden=false
        floor.lineWidth=warning ? CGFloat(1+2*charge):2;hatching.alpha=warning ? CGFloat(0.35+0.65*charge):1
        let lines=CGMutablePath()
        for i in 0...12 {let x=rect.minX+rect.width*CGFloat(i)/12;lines.move(to:CGPoint(x:x,y:rect.minY));lines.addLine(to:CGPoint(x:x,y:rect.maxY))}
        hatching.path=lines
    }
}
