import Foundation
import SpriteKit
var passed=0,failed=0
func check(_ name:String,_ ok:Bool) {
    if ok { passed+=1 } else { failed+=1;print("FAIL \(name)") }
}
check("real registered radius",ArenaConfig.twinChannels.radiusScale == 1.30)
check("old arena radius preserved",ArenaConfig.splitworks.radiusScale == 1.15)
check("separate replacement intervals",GameConfig.Tollkeeper.spawnInterval == 8 && GameConfig.Railspike.spawnInterval == 10)
check("first arrivals preserved",GameConfig.Tollkeeper.firstSpawn == 15 && GameConfig.Railspike.firstSpawn == 45)
check("timings preserved",GameConfig.Switchwarden.warning == 1.5 && GameConfig.Switchwarden.surge == 0.35 && GameConfig.Switchwarden.recovery == 1.5 && GameConfig.Switchwarden.cycle == 4.5)
check("crossing rotation",SwitchwardenCrossing.north.next == .middle && SwitchwardenCrossing.middle.next == .south && SwitchwardenCrossing.south.next == .north)
for device:CGFloat in [280,350,512,800] {
    DeviceScale.arenaRadius=device
    let r=GameConfig.Arena.radius,g=ArenaGeometry.twinChannels
    let body=r*GameConfig.Switchwarden.bodyFraction
    for sign:CGFloat in [-1,1] {
        let from=CGPoint(x:-0.65*r,y:sign*0.43*r), to=CGPoint(x:0.65*r,y:sign*0.43*r)
        let move=SwitchwardenMotion.advance(from:from,to:to,bodyRadius:body,arenaRadius:r,geometry:g)
        check("first island stop",move.stopped && move.position.x < 0 && move.position.x > from.x)
        check("sweep does not tunnel",!g.segmentBlockedExact(from,move.position,travelRadius:body))
        check("grounded endpoint",!g.isBlocked(move.position,margin:body))
    }
    let rim=SwitchwardenMotion.advance(from:CGPoint(x:0.65*r,y:0),to:CGPoint(x:2*r,y:0),bodyRadius:body,arenaRadius:r,geometry:g)
    check("first perimeter stop",rim.stopped && abs(rim.position.x-(r-body)) < 0.001)
    let keepOut=body+10+24
    let chase=SwitchwardenMotion.advance(from:CGPoint(x:-0.65*r,y:0),to:CGPoint(x:0.65*r,y:0),bodyRadius:body,arenaRadius:r,geometry:g,avoiding:.zero,standOff:keepOut)
    check("swept stand-off cannot pass through Spark",chase.stopped && chase.position.x < 0 && abs(chase.position.length-keepOut)<0.001)
    let short=SwitchwardenMotion.advance(from:CGPoint(x:-0.65*r,y:0),to:CGPoint(x:-0.60*r,y:0),bodyRadius:body,arenaRadius:r,geometry:g)
    check("clear movement exact",!short.stopped && short.position == CGPoint(x:-0.60*r,y:0))
    for crossing in SwitchwardenCrossing.allCases {
        guard let rect=crossing.footprint(geometry:g,radius:r) else {fatalError("missing crossing")}
        for x in [rect.minX,rect.maxX] {for y in [rect.minY,rect.maxY] {
            check("fitted corner \(device) \(crossing)",CGPoint(x:x,y:y).length < r)
        }}
        for i in 0...12 {for j in 0...6 {
            let p=CGPoint(x:rect.minX+rect.width*CGFloat(i)/12,y:rect.minY+rect.height*CGFloat(j)/6)
            check("band excludes islands",g.blockedFootprints.allSatisfy { $0.signedDistance(to:p) >= -0.000001 })
        }}
        let plan=SwitchwardenState.choosePlan(from:CGPoint(x:-0.65*r,y:0),player:CGPoint(x:0,y:rect.midY),playerRadius:10,moveSpeed:250,geometry:g,radius:r,crossing:crossing)
        check("valid ordinary withdrawal \(device) \(crossing)",plan != nil)
        if let p=plan {
            check("correct band",p.rect == rect)
            check("anchor inside circle",p.anchor.length+r*GameConfig.Switchwarden.bodyFraction < r)
            check("anchor clear",!g.isBlocked(p.anchor,margin:r*GameConfig.Switchwarden.bodyFraction))
            check("anchor outside attack",!TollkeeperState.overlaps(rect:rect,circle:p.anchor,radius:r*GameConfig.Switchwarden.bodyFraction))
            check("no fast tell",p.warning >= 1.5)
        }
    }
}
DeviceScale.arenaRadius=350
let r=GameConfig.Arena.radius,g=ArenaGeometry.twinChannels,body=r*GameConfig.Switchwarden.bodyFraction
let origin=CGPoint(x:-0.45*r,y:0)
guard let rp=SwitchwardenRamPlan.choose(from:origin,player:.zero,playerRadius:10,moveSpeed:250,
    bodyRadius:body,geometry:g,arenaRadius:r) else { fatalError("ordinary ram must be fair") }
check("ram max length",rp.distance <= 240.000001 && rp.distance > 239.99)
check("zero distance rejected",SwitchwardenRamPlan.choose(from:origin,player:origin,playerRadius:10,moveSpeed:250,bodyRadius:body,geometry:g,arenaRadius:r) == nil)
check("slow fixed tell deferred",SwitchwardenRamPlan.choose(from:origin,player:.zero,playerRadius:10,moveSpeed:10,bodyRadius:body,geometry:g,arenaRadius:r) == nil)
var rs=SwitchwardenRamState();rs.commit(rp)
check("ram complete tell begins",rs.phase == .warning && rs.remaining == 1.2)
rs.step(1.199,geometry:g,bodyRadius:body,arenaRadius:r)
check("tell plants",rs.phase == .warning && rs.position == origin && !rs.pendingSweep)
rs.step(0.002,geometry:g,bodyRadius:body,arenaRadius:r)
check("rushing does not skip movement",rs.phase == .rushing && rs.position == origin)
rs.step(0.1,geometry:g,bodyRadius:body,arenaRadius:r)
check("literal 300 speed",abs(rs.position.distance(to:origin)-30) < 0.001)
rs.step(100,geometry:g,bodyRadius:body,arenaRadius:r)
check("long frame capped 240 with full recovery",rs.phase == .recovery && rs.remaining == 1.5 && rs.position.distance(to:origin) <= 240.000001)
check("final sweep hits once",rs.consumeSweep(player:.zero,radius:10,bodyRadius:body*0.85) && !rs.consumeSweep(player:.zero,radius:10,bodyRadius:body*0.85))
check("sweep contact share latch",!rs.consumeContactAttempt())
rs.step(1.499,geometry:g,bodyRadius:body,arenaRadius:r);check("full recovery retained",rs.phase == .recovery)
rs.step(0.002,geometry:g,bodyRadius:body,arenaRadius:r);check("recovery finishes",rs.phase == .ready)
var contactFirst=SwitchwardenRamState();contactFirst.commit(rp)
check("contact attempt counts during tell",contactFirst.consumeContactAttempt() && !contactFirst.consumeContactAttempt())
contactFirst.step(10,geometry:g,bodyRadius:body,arenaRadius:r)
contactFirst.step(10,geometry:g,bodyRadius:body,arenaRadius:r)
check("contact then sweep no extra hit",!contactFirst.consumeSweep(player:.zero,radius:10,bodyRadius:body))
var aborted=SwitchwardenRamState();aborted.commit(rp);aborted.step(100,geometry:g,bodyRadius:body,arenaRadius:r)
check("long frame never skips tell to travel",aborted.phase == .rushing && aborted.position == origin)
aborted.cancel();check("cancel disarms",aborted.plan == nil && !aborted.consumeContactAttempt() && !aborted.consumeSweep(player:.zero,radius:10,bodyRadius:body))
guard let signature=SwitchwardenState.choosePlan(from:CGPoint(x:-0.65*r,y:0),player:.zero,playerRadius:10,moveSpeed:250,geometry:g,radius:r) else {fatalError("signature")}
func ramNode()->SwitchwardenNode {
    let n=SwitchwardenNode();n.position=signature.anchor;n.planProvider={_ in signature}
    n.update(deltaTime:0,playerPosition:.zero)
    check("first signature advances only on commit",n.attack.phase == .warning && n.nextCrossing == .middle && n.nextAttackIsRam)
    n.update(deltaTime:signature.warning+0.001,playerPosition:.zero)
    n.update(deltaTime:0.351,playerPosition:.zero)
    n.update(deltaTime:1.501,playerPosition:.zero)
    n.update(deltaTime:10,playerPosition:CGPoint(x:-0.2*r,y:0))
    check("ram alternates after signature",n.ram.phase == .warning && !n.nextAttackIsRam && n.nextCrossing == .middle)
    return n
}
let n=ramNode(),locked=n.ram.plan!,start=n.position
n.update(deltaTime:0.6,playerPosition:CGPoint(x:0,y:r*0.7))
check("node planted tell and heading locked",n.position == start && n.ram.plan == locked)
check("ram capsule and label visible",n.children.compactMap{$0 as? SKShapeNode}.contains{!$0.isHidden && $0.path != nil && $0.children.contains{($0 as? SKLabelNode)?.text == "RAM"}})
n.update(deltaTime:0.601,playerPosition:.zero);n.update(deltaTime:0.8,playerPosition:.zero)
check("actual node capped",n.ram.phase == .recovery && n.position.distance(to:start) <= 240.000001)
check("actual node sweep once",n.consumeRam(player:CGPoint(x:-0.2*r,y:0)) && !n.consumeRam(player:CGPoint(x:-0.2*r,y:0)) && !n.consumeBodyContactAttempt())
let growth=ramNode();growth.playerHitRadius=20;growth.update(deltaTime:0,playerPosition:.zero)
check("live growth cancels ram",growth.ram.plan == nil && growth.ram.phase == .recovery)
let slow=ramNode();slow.playerMoveSpeed=30;slow.update(deltaTime:0,playerPosition:.zero)
check("live slow cancels ram",slow.ram.plan == nil)
let shoved=ramNode();shoved.position.x+=1;check("postphysics displacement cancels",!shoved.consumeRam(player:.zero) && shoved.ram.plan == nil)
let dead=ramNode();_=dead.takeDamage(999999);check("death disarms all",dead.isDead && dead.ram.plan == nil && !dead.consumeRam(player:.zero) && !dead.consumeBodyContactAttempt())
let scene=GameScene(),contactBoss=ramNode();scene.boss=contactBoss;scene.isInvulnerable=true
scene.handlePlayerEnemyContact(enemyBody:contactBoss.physicsBody!)
check("actual contact prefix consumes before iframe",contactBoss.ram.hitSpent && scene.contactDamageAttempts == 0 && scene.bounces == 1)
scene.isInvulnerable=false;scene.handlePlayerEnemyContact(enemyBody:contactBoss.physicsBody!)
check("repeat physics contact suppressed",scene.contactDamageAttempts == 0 && scene.bounces == 2)
let moving=SwitchwardenNode();moving.position=CGPoint(x:-0.65*r,y:0);moving.planProvider={_ in nil}
let old=moving.position;moving.update(deltaTime:0.5,playerPosition:.zero)
check("actual grounded 80 pursuit",abs(moving.position.distance(to:old)-40)<0.001)
moving.update(deltaTime:100,playerPosition:.zero)
check("actual chase stand-off",moving.position.distance(to:.zero) >= body+10+24 && moving.position.distance(to:.zero)<body+10+24.001)
let fresh=SwitchwardenNode();fresh.position=signature.anchor
fresh.planProvider={p in SwitchwardenState.choosePlan(from:p,player:.zero,playerRadius:10,moveSpeed:250,geometry:g,radius:r,crossing:fresh.nextCrossing,plantAtCurrentPosition:true)}
fresh.update(deltaTime:0,playerPosition:.zero)
let planted=fresh.position;fresh.update(deltaTime:0.5,playerPosition:CGPoint(x:r*0.5,y:0))
check("current safe caster planted",fresh.attack.phase == .warning && fresh.attack.plan?.anchor == planted && fresh.position == planted)
func launchedRam()->SwitchwardenNode {
    let n=ramNode();n.update(deltaTime:1.201,playerPosition:.zero);n.update(deltaTime:0.8,playerPosition:.zero);return n
}
let frame=GameScene(),swept=launchedRam();frame.boss=swept;frame.player.position=CGPoint(x:-0.2*r,y:0)
frame.didFinishUpdate();frame.didFinishUpdate()
check("real end-frame hazard uses existing damage once",frame.damages == [GameConfig.Marchwarden.contactDamage])
let race=GameScene(),raced=ramNode();race.boss=raced;race.player.position=CGPoint(x:-0.2*r,y:0)
race.isInvulnerable=true;race.handlePlayerEnemyContact(enemyBody:raced.physicsBody!)
raced.update(deltaTime:1.201,playerPosition:race.player.position);raced.update(deltaTime:0.8,playerPosition:race.player.position)
race.isInvulnerable=false;race.didFinishUpdate()
check("real iframe contact then end-frame cannot double",race.damages.isEmpty && race.contactDamageAttempts == 0)
let deathFrame=GameScene(),late=launchedRam();deathFrame.boss=late;deathFrame.player.position=CGPoint(x:-0.2*r,y:0)
deathFrame.onDrain={_=late.takeDamage(999999)};deathFrame.didFinishUpdate()
check("real end-frame death wins",late.isDead && deathFrame.damages.isEmpty)
for state:GameScene.State in [.paused,.levelUp,.dead] {
    let sc=GameScene();sc.gameState=state;sc.boss=launchedRam();sc.player.position=CGPoint(x:-0.2*r,y:0);sc.didFinishUpdate()
    check("inactive scene has no ram damage",sc.damages.isEmpty)
}
let contactGrowth=GameScene(),growing=ramNode();contactGrowth.boss=growing;contactGrowth.playerStats.effectiveCollisionRadius=30
contactGrowth.handlePlayerEnemyContact(enemyBody:growing.physicsBody!)
check("physics prefix refreshes live growth",growing.ram.plan == nil && contactGrowth.contactDamageAttempts == 0)
let lease=ChannelAttackSchedule(),leased=SwitchwardenNode();leased.position=signature.anchor;leased.planProvider={_ in signature};leased.schedule=lease
leased.update(deltaTime:0,playerPosition:.zero);check("no signature lease bypass",leased.attack.phase == .seek)
lease.beginFrame(0,railBolts:0);leased.update(deltaTime:0,playerPosition:.zero)
leased.update(deltaTime:signature.warning+0.001,playerPosition:.zero);leased.update(deltaTime:0.351,playerPosition:.zero)
lease.beginFrame(0,railBolts:0);leased.update(deltaTime:1.501,playerPosition:.zero)
leased.update(deltaTime:10,playerPosition:CGPoint(x:-0.2*r,y:0));check("ram cannot bypass grant",leased.ram.phase == .ready)
lease.beginFrame(1,railBolts:0,hostileBolts:1);leased.update(deltaTime:0,playerPosition:CGPoint(x:-0.2*r,y:0))
check("ram waits hostile bolt",leased.ram.phase == .ready)
lease.beginFrame(1,railBolts:0,hostileBolts:0);leased.update(deltaTime:0,playerPosition:CGPoint(x:-0.2*r,y:0))
check("ram acquires shared schedule",leased.ram.phase == .warning && lease.owner == .switchwarden)
leased.cancelAttack();lease.beginFrame(0,railBolts:0)
check("ram cancellation releases lease",lease.owner == nil && leased.ram.plan == nil)
let retreat=launchedRam();retreat.planProvider={p in
    SwitchwardenState.choosePlan(from:p,player:CGPoint(x:-0.2*r,y:0),playerRadius:10,moveSpeed:250,
        geometry:g,radius:r,crossing:retreat.nextCrossing,plantAtCurrentPosition:true)
    ?? SwitchwardenState.choosePlan(from:p,player:CGPoint(x:-0.2*r,y:0),playerRadius:10,moveSpeed:250,
        geometry:g,radius:r,crossing:retreat.nextCrossing)
}
retreat.update(deltaTime:1.501,playerPosition:CGPoint(x:-0.2*r,y:0))
retreat.update(deltaTime:0.6,playerPosition:CGPoint(x:-0.2*r,y:0))
let distanceBefore=retreat.position.distance(to:CGPoint(x:-0.2*r,y:0))
retreat.update(deltaTime:1,playerPosition:CGPoint(x:-0.2*r,y:0))
check("safe cast withdrawal can leave inner stand-off",retreat.position.distance(to:CGPoint(x:-0.2*r,y:0)) > distanceBefore+1)
print("Switchwarden rework: \(passed) passed / \(failed) failed")
exit(failed == 0 ? 0 : 1)
