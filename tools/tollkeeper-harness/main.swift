import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ n:String,_ ok:Bool){if ok{passed+=1;print("PASS \(n)")}else{failed+=1;print("FAIL \(n)")}}
let r=GameConfig.Arena.radius,geo=ArenaGeometry.twinChannels
let a=CGPoint(x:0.43*r,y:0)
let candidate=TollkeeperState.choosePlan(from:a,player:a,bodyRadius:14,geometry:geo,radius:r)
check("T1 local plan",candidate != nil)
guard let p=candidate else{exit(1)}
let center=CGPoint(x:p.rect.midX,y:p.rect.midY),edge=CGPoint(x:p.rect.maxX+9,y:p.rect.midY)
check("T2 half-crossing size",abs(p.rect.width-r*0.3)<1e-6 && abs(p.rect.height-r*0.1)<1e-6 && p.rect.minX>0 && p.rect.maxX<0.43*r)
check("T3 opposite half safe",!TollkeeperState.overlaps(rect:p.rect,circle:CGPoint(x:-0.2*r,y:0),radius:10))
check("T4 occluded goal rejected",!TollkeeperState.valid(p,player:CGPoint(x:-0.16*r,y:0.25*r),bodyRadius:14,geometry:geo,radius:r))
check("T5 distant goal rejected",!TollkeeperState.valid(p,player:CGPoint(x:-0.8*r,y:-0.4*r),bodyRadius:14,geometry:geo,radius:r))
for y:CGFloat in [-0.78,0,0.78]{for sign:CGFloat in [-1,1]{let q=CGPoint(x:sign*0.43*r,y:y*r);let chosen=TollkeeperState.choosePlan(from:q,player:q,bodyRadius:14,geometry:geo,radius:r);check("T6 exact six crossing-side anchors",chosen?.anchor == q && chosen.map { abs($0.rect.midX-sign*0.2*r)<1e-6 && abs($0.rect.midY-y*r)<1e-6 && TollkeeperState.valid($0,player:q,bodyRadius:14,geometry:geo,radius:r) } == true)}}
var s=TollkeeperState();s.step(0,disabled:false,atAnchor:true,candidate:p)
check("T7 tell cannot damage",s.phase == .windup && !s.consumeHit(player:center,radius:10))
s.step(0.89,disabled:false,atAnchor:true,candidate:p);check("T8 full tell",s.phase == .windup)
s.step(0.011,disabled:false,atAnchor:true,candidate:p);check("T9 pulse",s.phase == .pulse)
check("T10 body edge reaches",s.consumeHit(player:edge,radius:10));check("T11 single hit",!s.consumeHit(player:edge,radius:10))
s.step(0.34,disabled:false,atAnchor:true,candidate:p);check("T12 full pulse",s.phase == .pulse)
s.step(0.011,disabled:false,atAnchor:true,candidate:p);check("T13 unarmed recovery",s.phase == .recovery && s.attackRect == nil)
s.step(1.19,disabled:false,atAnchor:true,candidate:p);check("T14 full recovery",s.phase == .recovery)
s.step(0.011,disabled:false,atAnchor:true,candidate:p);s.step(0,disabled:false,atAnchor:true,candidate:p);check("T15 minimum cycle",s.phase == .seek)
s.step(1.1,disabled:false,atAnchor:true,candidate:p);check("T16 rearm",s.phase == .windup)
s.step(1,disabled:false,atAnchor:true,candidate:p);let locked=s.attackRect
s.step(0.01,disabled:false,atAnchor:true,candidate:TollkeeperPlan(anchor:a,rect:.zero));check("T17 world lock",s.attackRect == locked)
s.step(0,disabled:true,atAnchor:true,candidate:p);check("T18 cancel",s.attackRect == nil && !s.consumeHit(player:center,radius:10))
check("T19 corner miss",!TollkeeperState.overlaps(rect:CGRect(x:0,y:0,width:10,height:10),circle:CGPoint(x:19,y:19),radius:10))
check("T20 tangency",TollkeeperState.overlaps(rect:CGRect(x:0,y:0,width:10,height:10),circle:CGPoint(x:20,y:5),radius:10))
check("T21 early spawn",!TollkeeperState.shouldSpawn(elapsed:14,lastSpawn: -.infinity,living:0))
check("T22 cap",!TollkeeperState.shouldSpawn(elapsed:100,lastSpawn:0,living:1))
check("T23 spacing",!TollkeeperState.shouldSpawn(elapsed:20,lastSpawn:15,living:0))
check("T24 eligible",TollkeeperState.shouldSpawn(elapsed:30,lastSpawn:15,living:0))
func armed()->TollkeeperNode{let k=TollkeeperNode();k.position=p.anchor;_=k.approachGoal(player:a,geometry:geo,radius:r,disabled:false);k.chase(target:a,deltaTime:0);k.chase(target:a,deltaTime:0.91);return k}
let k=armed();check("T25 actual AI pulse",k.attack.phase == .pulse);k.position += CGPoint(x:30,y:0)
check("T26 post-chase shove cancels",!k.consumePulse(player:center,radius:10) && k.attackRect == nil)
for flag in 0..<5{let n=armed();if flag==0{n.isDying=true};if flag==1{n.isFrozen=true};if flag==2{n.isStunned=true};if flag==3{n.isVoidTrapped=true};if flag==4{n.isFeared=true};check("T27 live disable \(flag)",!n.consumePulse(player:center,radius:10) && n.attackRect == nil)}
let sc=GameScene();sc.waveManager.elapsedTime=60;sc.player.position=center;let n=armed();sc.worldNode.children=[n]
sc.processTollkeeperPulses();sc.processTollkeeperPulses();check("T28 shared normal damage once",sc.damages.count == 1 && sc.damages[0].0 == 21 && !sc.damages[0].1)
for phase:GameScene.State in [.paused,.levelUp,.dead]{sc.gameState=phase;sc.damages=[];sc.worldNode.children=[armed()];sc.processTollkeeperPulses();check("T29 inactive scene",sc.damages.isEmpty)}
sc.gameState = .playing;sc.damages=[];let pin=armed();sc.worldNode.children=[pin];sc.repulseFlights[ObjectIdentifier(pin)]=true;sc.processTollkeeperPulses();check("T30 pinned",sc.damages.isEmpty && pin.attackRect == nil)
sc.repulseFlights=[:];sc.worldNode.children=[armed()];sc.player.position=edge;sc.playerStats.effectiveCollisionRadius=5;sc.processTollkeeperPulses();check("T31 live small body",sc.damages.isEmpty)
sc.playerStats.effectiveCollisionRadius=10;sc.processTollkeeperPulses();check("T32 restored body",sc.damages.count == 1)
let sp=GameScene();sp.waveManager.elapsedTime=15;for _ in 0..<50{sp.spawnTwinChannelsEnemy()}
check("T33 actual cap",sp.enemies.filter{$0 is TollkeeperNode}.count == 1);check("T34 health",sp.enemies.first(where:{$0 is TollkeeperNode})?.health == 1)
check("T35 last spawn",sp.channelTollkeeperLastSpawn == 15)
let walking=TollkeeperNode();walking.position=CGPoint(x:0.43*r,y:-0.1*r);let orig=walking.position;_=walking.approachGoal(player:a,geometry:geo,radius:r,disabled:false);walking.chase(target:a,deltaTime:0.1,globalSlow:0.5)
check("T36 slowed movement",abs(walking.position.distance(to:orig)-6.5)<1e-6)
let walkingScene=GameScene();walkingScene.worldNode.children=[walking];walkingScene.processTollkeeperPulses();check("T37 collision poll cannot cancel seek",walking.attack.phase == .seek)
let tell=TollkeeperNode();tell.position=a;_=tell.approachGoal(player:a,geometry:geo,radius:r,disabled:false);tell.chase(target:a,deltaTime:0);let oldRect=tell.attackRect;_=tell.consumePulse(player:center,radius:10);check("T38 collision poll cannot cancel tell",tell.attackRect == oldRect && tell.attack.phase == .windup)
print("Tollkeeper: \(passed) passed / \(failed) failed");exit(failed == 0 ? 0 : 1)
