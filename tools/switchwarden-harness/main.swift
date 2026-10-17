import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ n:String,_ ok:Bool){if ok{passed+=1;print("PASS \(n)")}else{failed+=1;print("FAIL \(n)")}}
let r=GameConfig.Arena.radius,geo=ArenaGeometry.twinChannels
func plan(_ player:CGPoint = .zero,_ radius:CGFloat=10,_ speed:CGFloat=250)->SwitchwardenPlan?{SwitchwardenState.choosePlan(from:CGPoint(x:-0.65*r,y:0),player:player,playerRadius:radius,moveSpeed:speed,geometry:geo,radius:r)}
guard let p=plan() else{fatalError("S0 safe central plan")}
check("S1 center crossing exact",abs(p.rect.minX+0.43*r)<0.001 && abs(p.rect.maxX-0.43*r)<0.001 && abs(p.rect.minY+0.18*r)<0.001 && abs(p.rect.maxY-0.18*r)<0.001)
check("S2 ends remain safe",[-0.78,0.78].allSatisfy{!TollkeeperState.overlaps(rect:p.rect,circle:CGPoint(x:0,y:CGFloat($0)*r),radius:10)})
check("S3 same-channel waiting safe",!TollkeeperState.overlaps(rect:p.rect,circle:CGPoint(x:-0.5*r,y:0),radius:10))
check("S4 safe anchor outside danger",!TollkeeperState.overlaps(rect:p.rect,circle:p.anchor,radius:r*0.08))
check("S4b safe deployment stand-off",p.anchor.distance(to:.zero)>0.35*r)
check("S5 no card assumed",p.warning>=1.5)
check("S6 slow warning grows",(plan(.zero,10,80)?.warning ?? 0)>p.warning)
check("S7 no zero speed assumption",plan(.zero,10,0)==nil)
check("S8 invalid speed inert",plan(.zero,10,.nan)==nil)
check("S9 huge body cannot escape",plan(.zero,200,250)==nil)
for x:CGFloat in [-0.3,0,0.3]{for y:CGFloat in [-0.08,0,0.08]{check("S10 withdrawal sample \(x) \(y)",plan(CGPoint(x:x*r,y:y*r)) != nil)}}
let anchorPlan=plan(CGPoint(x:-0.65*r,y:0));check("S11 boss never on Spark",(anchorPlan?.anchor.x ?? 0)>0)
let oldR=DeviceScale.arenaRadius;DeviceScale.arenaRadius=800
let big=GameConfig.Arena.radius
let scaled=SwitchwardenState.choosePlan(from:CGPoint(x:-0.65*big,y:0),player:.zero,playerRadius:10,moveSpeed:250,geometry:geo,radius:big)
check("S12 device warning accounts unscaled baseline movement",(scaled?.warning ?? 0)>1.5)
DeviceScale.arenaRadius=oldR
var s=SwitchwardenState();s.step(0,disabled:false,atAnchor:true,candidate:p)
check("S13 full warning starts",s.phase == .warning && s.remaining==p.warning && !s.consumeHit(player:.zero,radius:10))
s.step(1.499,disabled:false,atAnchor:true,candidate:p);check("S14 no early surge",s.phase == .warning)
s.step(0.002,disabled:false,atAnchor:true,candidate:p);check("S15 surge",s.phase == .surge)
check("S16 one attempt",s.consumeHit(player:.zero,radius:10) && !s.consumeHit(player:.zero,radius:10))
s.step(0.349,disabled:false,atAnchor:true,candidate:p);check("S17 surge duration",s.phase == .surge)
s.step(0.002,disabled:false,atAnchor:true,candidate:p);check("S18 recovery safe",s.phase == .recovery && s.plan==nil && !s.consumeHit(player:.zero,radius:10))
s.step(1.499,disabled:false,atAnchor:true,candidate:p);check("S19 recovery duration",s.phase == .recovery)
s.step(0.002,disabled:false,atAnchor:true,candidate:p);s.step(0,disabled:false,atAnchor:true,candidate:p);check("S20 minimum cycle",s.phase == .seek)
s.step(2,disabled:false,atAnchor:true,candidate:p);check("S21 rearm",s.phase == .warning)
let replacement=SwitchwardenPlan(anchor:.zero,rect:.zero,warning:0.001)
s.step(0.1,disabled:false,atAnchor:true,candidate:replacement);check("S22 locked warning and shape",s.plan==p)
s.step(0,disabled:true,atAnchor:true,candidate:p);check("S23 cancellation clears",s.phase == .recovery && s.plan==nil)
var long=SwitchwardenState();long.step(100,disabled:false,atAnchor:true,candidate:p);check("S24 long frame cannot skip tell",long.phase == .warning && !long.consumeHit(player:.zero,radius:10))
long.step(100,disabled:false,atAnchor:true,candidate:p);check("S25 surge not skipped",long.phase == .surge)
var invalid=SwitchwardenState();invalid.step(.nan,disabled:false,atAnchor:true,candidate:p);invalid.step(-1,disabled:false,atAnchor:true,candidate:p);check("S26 bad clock inert",invalid.phase == .seek)
func armed()->SwitchwardenNode{let n=SwitchwardenNode();n.position=p.anchor;n.planProvider={_ in p};n.update(deltaTime:0,playerPosition:.zero);return n}
let edge=CGPoint(x:p.rect.maxX+9,y:0)
let body=armed();body.update(deltaTime:1.51,playerPosition:.zero);body.playerHitRadius=5;check("S27 shrunk live body safe",!body.consumeSurge(player:edge));body.playerHitRadius=10;check("S28 live body edge hit",body.consumeSurge(player:edge))
let dead=armed();dead.update(deltaTime:1.51,playerPosition:.zero);_=dead.takeDamage(999);check("S29 late death cancels surge",dead.isDead && !dead.consumeSurge(player:.zero) && dead.attack.plan==nil)
let shove=armed();shove.update(deltaTime:1.51,playerPosition:.zero);shove.position.x+=20;check("S30 postphysics shove cancels",!shove.consumeSurge(player:.zero) && shove.attack.plan==nil)
let moving=armed();moving.update(deltaTime:0.2,playerPosition:CGPoint(x:r*0.7,y:0));check("S31 no tracking",moving.attack.plan==p)
let badNode=SwitchwardenNode();badNode.position=CGPoint(x:0.6*r,y:0);let beforeBad=badNode.position;badNode.planProvider={_ in p};badNode.update(deltaTime:-1,playerPosition:.zero);badNode.update(deltaTime:.nan,playerPosition:.zero);check("S31b invalid live-node clock inert",badNode.position==beforeBad && badNode.attack.phase == .seek)
let health=SwitchwardenNode();health.challengeFlatReduction=20
_=health.takeDirectHit(DirectHit(basis:1,dealt:0));check("S32 zero remains zero",health.health==140)
health.vulnerability.set(.marked,2);_=health.takeDamage(3);check("S33 shared vulnerability DEF chip",health.health==139)
_=health.takeDamage(3,ignoresChallengeDEF:true);check("S34 DOT bypass DEF",health.health==133)
_=health.takeDirectHit(DirectHit(basis:5,dealt:5),ignoresChallengeDEF:true);check("S35 resolved bypass second vulnerability",health.health==128)
var events:[String]=[];var finishing=0
health.onLethalHit={n in finishing=n;events.append(health.isDead ? "lethal-dead":"bad")};health.onDeath={events.append("death")}
_=health.takeDamage(999);_=health.takeDamage(999);check("S36 lethal once and before callback",events==["lethal-dead","death"] && finishing==128 && health.removed)
let hp=SwitchwardenNode();hp.applyChallengeHealthScale(2);check("S37 shared HP dial",hp.health==280 && hp.maxHealth==280)
let a=ChannelAttackSchedule();_=a.request(.switchwarden);a.beginFrame(0,railBolts:0,hostileBolts:1);check("S38 waits all hostile bolts",!a.request(.switchwarden));a.beginFrame(0,railBolts:0,hostileBolts:0);check("S39 boss lease",a.request(.switchwarden))
check("S40 suppress other specials",!a.request(.tollkeeper) && !a.request(.railspike));a.finish(.switchwarden);a.beginFrame(10,railBolts:0);check("S41 full release gap",a.owner==nil && a.gap==0.35)
let collision=ChannelAttackSchedule();_=collision.request(.railspike);collision.beginFrame(0,railBolts:0);_=collision.request(.railspike);_=collision.request(.switchwarden);collision.beginFrame(1,railBolts:1,hostileBolts:1);check("S42 respects earlier owner",!collision.request(.switchwarden) && collision.owner == .railspike)
let actual=SwitchwardenNode();actual.position=p.anchor;actual.planProvider={_ in p};actual.schedule=ChannelAttackSchedule();actual.update(deltaTime:0,playerPosition:.zero);check("S43 node cannot bypass coordinator",actual.attack.phase == .seek)
actual.schedule?.beginFrame(0,railBolts:0);actual.update(deltaTime:0,playerPosition:.zero);check("S44 node takes boss lease",actual.attack.phase == .warning && actual.schedule?.owner == .switchwarden)
actual.cancelAttack();actual.schedule?.beginFrame(0,railBolts:0);check("S45 cancellation releases",actual.schedule?.owner==nil)
let scene=GameScene();scene.waveManager.elapsedTime=74;scene.spawnSwitchwardenPreviewIfReady();check("S46 no early arrival",scene.boss==nil)
scene.waveManager.elapsedTime=75;scene.enemies=[EnemyNode(health:1,moveSpeed:130,xpValue:2)];scene.spawnSwitchwardenPreviewIfReady();check("S47 drains crowd",scene.boss==nil)
scene.enemies=[];let bolt=EnemyProjectileNode(direction:CGPoint(x:1,y:0),damage:1,speed:1,range:1,colorHex:0,elongated:false);scene.enemyProjectiles=[bolt];scene.spawnSwitchwardenPreviewIfReady();check("S48 drains bolts",scene.boss==nil)
scene.enemyProjectiles=[];scene.spawnSwitchwardenPreviewIfReady();check("S49 real arrival once",scene.boss is SwitchwardenNode && scene.channelSwitchwardenSpawned && scene.worldNode.bosses.count==1)
scene.spawnSwitchwardenPreviewIfReady();check("S50 no duplicate",scene.worldNode.bosses.count==1)
if let boss=scene.boss as? SwitchwardenNode {check("S51 shared schedule injected",boss.schedule === scene.channelAttacks);_=boss.takeDamage(999)}
check("S52 real death cleanup no respawn",scene.boss==nil && scene.creditChecks==1 && scene.channelSwitchwardenSpawned)
let normal=GameScene();normal.isTwinChannelsPreview=false;normal.waveManager.elapsedTime=100;normal.spawnSwitchwardenPreviewIfReady();check("S53 release/oldarena excluded",normal.boss==nil && !normal.channelPrototypeArrivalDue)
for phase:GameScene.State in [.paused,.levelUp,.dead]{let sc=GameScene();sc.gameState=phase;let b=armed();b.update(deltaTime:1.51,playerPosition:.zero);sc.boss=b;sc.processSwitchwardenSurge();check("S54 no paused damage \(phase)",sc.damages.isEmpty)}
let sc=GameScene();let b=armed();b.update(deltaTime:1.51,playerPosition:.zero);sc.boss=b;sc.processSwitchwardenSurge();sc.processSwitchwardenSurge();check("S55 shared boss hazard once",sc.damages.count==1 && sc.damages.first?.0==36 && sc.damages.first?.1==true)
let fresh=GameScene();let b2=armed();b2.update(deltaTime:1.51,playerPosition:.zero);fresh.boss=b2;fresh.player.position=edge;fresh.playerStats.effectiveCollisionRadius=5;fresh.processSwitchwardenSurge();check("S56 real live radius safe",fresh.damages.isEmpty);fresh.playerStats.effectiveCollisionRadius=10;fresh.processSwitchwardenSurge();check("S57 real live radius restored",fresh.damages.count==1)
let frame=GameScene();let late=armed();late.update(deltaTime:1.51,playerPosition:.zero);frame.boss=late;frame.onDrain={_=late.takeDamage(999)};frame.didFinishUpdate();check("S58 actual frame death wins over surge",late.isDead && frame.damages.isEmpty)
let growth=armed();growth.playerHitRadius=20;growth.update(deltaTime:0.1,playerPosition:.zero);check("S59 growth invalidates warning",growth.attack.phase == .recovery && growth.attack.plan==nil)
let slower=armed();slower.playerMoveSpeed=80;slower.update(deltaTime:0.1,playerPosition:.zero);check("S60 slowing invalidates warning",slower.attack.phase == .recovery && slower.attack.plan==nil)
let changedScene=GameScene();let changing=armed();changedScene.boss=changing;changedScene.playerStats.effectiveCollisionRadius=20;changedScene.processSwitchwardenSurge();check("S61 actual scene fresh growth cancels",changing.attack.phase == .recovery && changedScene.damages.isEmpty)
let speedScene=GameScene();let changingSpeed=armed();changingSpeed.update(deltaTime:1.51,playerPosition:.zero);speedScene.boss=changingSpeed;speedScene.playerStats.effectiveMoveSpeed=80;speedScene.processSwitchwardenSurge();check("S62 actual scene fresh slow cancels surge",changingSpeed.attack.phase == .recovery && speedScene.damages.isEmpty)
let safer=armed();safer.playerHitRadius=5;safer.playerMoveSpeed=400;safer.update(deltaTime:0.1,playerPosition:.zero);safer.playerMoveSpeed=250;safer.update(deltaTime:0.1,playerPosition:.zero);check("S63 shrink and ordinary boost expiry retain lock",safer.attack.phase == .warning && safer.attack.plan==p)
print("Switchwarden: \(passed) passed / \(failed) failed");exit(failed==0 ? 0 : 1)
