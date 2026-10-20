import Foundation
import CoreGraphics

var passed = 0, failed = 0
func check(_ label: String, _ condition: @autoclosure () -> Bool) {
    if condition() { passed += 1; print("PASS \(label)") }
    else { failed += 1; print("FAIL \(label)") }
}
func near(_ a: Double, _ b: Double, _ tolerance: Double = 0.000001) -> Bool { abs(a-b) < tolerance }
struct Lab {
    var model = RainbowP1Model()
    var attacker = RainbowP1Model.Attacker()
    var geometry = ArenaGeometry.open
    var viewport = CGRect(x: 0, y: 0, width: 200, height: 200)
    var origin = CGPoint(x: 10, y: 100)
    var board = CGRect(x: -1000, y: -1000, width: 2000, height: 2000)
    var targets: [RainbowP1Model.Target] = []
    @discardableResult mutating func tick(_ dt: Double = 0.1, random: () -> CGFloat = { 0.9 }) -> RainbowP1Model.Frame {
        model.advance(dt, fromViewport: viewport, toViewport: viewport, fromOrigin: origin, toOrigin: origin,
                      board: board, attacker: attacker, targets: targets, geometry: geometry, random: random)
    }
    @discardableResult mutating func launch() -> RainbowP1Model.Frame {
        model.select()
        for _ in 0..<205 {
            let result = tick()
            if result.launched { return result }
        }
        return RainbowP1Model.Frame()
    }
    mutating func finish(random: () -> CGFloat = { 0.9 }) -> [RainbowP1Model.Contact] {
        var hits: [RainbowP1Model.Contact] = []
        for _ in 0..<10 { hits += tick(random: random).contacts }
        return hits
    }
}
func target(_ id: Int, _ x: CGFloat, _ y: CGFloat = 100, radius: CGFloat = 2,
            health: Int = 100) -> RainbowP1Model.Target {
    var t = RainbowP1Model.Target(id: id, previous: CGPoint(x: x, y: y), position: CGPoint(x: x, y: y))
    t.radius = radius; t.health = health
    return t
}
let wall = ArenaGeometry(blockedFootprints: [Footprint(center: CGPoint(x: 80, y: 100), halfExtents: CGSize(width: 4, height: 40), cornerRadius: 0)])

do {
    var lab = Lab()
    check("T01 unselected clock does not run", !lab.tick(100).launched && lab.model.remaining == 20)
    lab.model.select(); for _ in 0..<189 { lab.tick() }
    check("T02 first launch waits full cadence", lab.model.launches == 0 && near(lab.model.remaining, 1.1))
    lab.tick()
    check("T03 final-second warning", lab.model.warning && lab.model.launches == 0)
    for _ in 0..<10 { lab.tick() }
    check("T04 empty battlefield still launches at20", lab.model.launches == 1 && near(lab.model.remaining, 20))
    check("T05 front begins at captured left boundary", near(Double(lab.model.sweep?.frontX ?? -1), 0))
    for _ in 0..<7 { lab.tick() }
    check("T06 front remains for0.7 active seconds", lab.model.sweep != nil)
    lab.tick()
    check("T07 crossing finishes and clears hitset/visual owner", lab.model.sweep == nil)
    for _ in 0..<192 { lab.tick() }
    check("T08 next launch20 apart not20plusanimation", lab.model.launches == 2)
    let elapsed = lab.model.elapsed
    lab.model.select()
    check("T09 selecting owned form cannot reset cadence", lab.model.elapsed == elapsed)
    lab.tick(200)
    check("T10 hitch uses existing0.1 game-time bound not real catchup", near(lab.model.elapsed, elapsed + 0.1) && lab.model.launches == 2)
    check("T11 negative/nonfinite deltas rejected", lab.model.activeStep(-1) == 0 && lab.model.activeStep(.infinity) == 0 && lab.model.activeStep(.nan) == 0)
}
do {
    var lab = Lab(); lab.targets = [target(1, 100)]
    lab.launch(); lab.tick(); lab.tick()
    let saved = lab.model.sweep, remaining = lab.model.remaining
    for hold in [RainbowP1Model.Hold.pause, .levelUp, .placement, .reveal, .background] {
        lab.model.setHold(hold, true)
        var clean=true
        for _ in 0..<20 { clean = lab.tick(10).contacts.isEmpty && clean }
        check("H01 \(hold) emits no held contacts",clean)
        check("H02 \(hold) freezes age/footprint/clock", lab.model.sweep?.age == saved?.age && lab.model.sweep?.footprint == saved?.footprint && lab.model.remaining == remaining)
        lab.model.setHold(hold, false)
    }
    lab.model.setHold(.pause, true); lab.model.setHold(.background, true)
    lab.model.setHold(.background, false)
    check("H03 foreground does not erase independent pause", lab.model.activeStep(1) == 0 && lab.model.holds == [.pause])
    lab.model.setHold(.pause, false)
    let hits = lab.finish()
    check("H04 resume continues same cycle once per target", hits.count == 1 && hits.first?.cycle == 1)
    check("H05 pause caused no catchup launch", lab.model.launches == 1)
    lab.model.boardHandoff()
    check("H06 new BossMode board keeps ownership2x but resets clock/front", lab.model.owned && lab.model.primaryMultiplier == 2 && lab.model.sweep == nil && lab.model.remaining == 20)
    check("H07 no board-entry strike", !lab.tick().launched && lab.tick().contacts.isEmpty)
    lab.model.endRun()
    check("H08 death/title cancel ownership/front/callback opportunities", !lab.model.owned && lab.model.sweep == nil && lab.tick(100).contacts.isEmpty)
    lab.model.newRun()
    check("H09 fresh run clears holds/ownership/history", lab.model.holds.isEmpty && !lab.model.owned && lab.model.launches == 0 && lab.model.remaining == 20)
}
do {
    var lab = Lab(); lab.targets = [target(1, 100)]
    lab.launch()
    for _ in 0..<3 { check("C01 no early full-area hit", lab.tick().contacts.isEmpty) }
    let hits = lab.tick().contacts
    check("C02 damage occurs on front contact", hits.count == 1 && near(Double(hits.first?.position.x ?? -1),100))
    check("C03 lingering/trails cannot rehit", lab.finish().isEmpty)
    lab.model.boardHandoff(); lab.launch()
    check("C04 new cycle clears per-target hitset", lab.finish().count == 1)
}
do {
    var lab = Lab(); lab.launch()
    var moving = target(2, 40, radius: 1)
    moving.previous.x = 40; moving.position.x = -10
    lab.targets = [moving]
    let hits = lab.tick().contacts
    check("C05 moving body crosses front despite disjoint endpoints", hits.count == 1 && (hits.first?.position.x ?? -1) > 0)
    lab.targets = [target(3, 0)]
    check("C06 late entrant behind passed front gets no retrohit", lab.tick().contacts.isEmpty)
    var outside = Lab(); outside.targets = [target(1,100,205,radius:2), target(2,205,100,radius:2)]
    outside.launch()
    check("C07 off-viewport bodies excluded", outside.finish().isEmpty)
    var edge = Lab(); edge.origin.y = 200; edge.targets = [target(1,100,201,radius:2)]
    edge.launch()
    check("C08 visible body edge counts even if center just offscreen", edge.finish().count == 1)
    var dead = Lab(); var t = target(1,100); t.hittable = false
    dead.targets = [t, target(2,100,health:0)]
    dead.launch()
    check("C09 dead/unhittable contacts excluded", dead.finish().isEmpty)
    var duplicate = Lab(); duplicate.targets = [target(1,100),target(1,100)]
    duplicate.launch()
    check("C10 duplicate input identities still one hit", duplicate.finish().count == 1)
}
do {
    var lab = Lab(); lab.geometry = ArenaGeometry(blockedFootprints: [Footprint(center: CGPoint(x: 80, y: 100), halfExtents: CGSize(width: 4, height: 10), cornerRadius: 0)]); lab.targets = [target(1,140),target(2,140,130)]
    lab.launch()
    let hits = lab.finish()
    check("G01 wall blocks occluded target", !hits.contains { $0.targetID == 1 })
    check("G02 open sightline remains eligible", hits.contains { $0.targetID == 2 })
    var ls = Lab(); ls.geometry = wall; ls.attacker.longShotT4 = true; ls.targets = [target(1,140)]
    ls.launch(); ls.attacker.longShotT4 = false
    check("G03 LongShotT4 captured atfire permits wall passage", ls.finish().count == 1)
    var captured = Lab(); captured.geometry = wall; captured.targets = [target(1,140)]
    captured.launch(); captured.origin = CGPoint(x: 150,y:100); captured.attacker.longShotT4 = true
    check("G04 moving Spark/toggling LongShot cannot change launched wall rule", captured.finish().isEmpty)
    var pan = Lab(); pan.targets = [target(1,100), target(2,400)]
    pan.launch(); let rect = pan.model.sweep?.footprint
    pan.viewport.origin.x = 300
    check("G05 camera pan does not reset clock or drag footprint", pan.model.sweep?.footprint == rect && pan.model.launches == 1 && pan.finish().map(\.targetID) == [1])
    var clip = Lab(); clip.board = CGRect(x:0,y:0,width:100,height:200);clip.targets=[target(1,50),target(2,150)]
    clip.launch()
    check("G06 board clipping excludes invisible/retired terrain", clip.model.sweep?.footprint.width == 100 && clip.finish().map(\.targetID) == [1])
    var empty = Lab(); empty.board = CGRect(x:500,y:500,width:20,height:20)
    check("G07 no board overlap still consumes scheduled cycle safely", empty.launch().launched && empty.model.sweep == nil)
}
do {
    var lab=Lab();lab.viewport=CGRect(x:0,y:-100,width:750,height:200);lab.origin=CGPoint(x:-100,y:0)
    lab.geometry=ArenaGeometry(blockedFootprints:[Footprint(center:CGPoint(x:0,y:60),halfExtents:CGSize(width:2,height:55),cornerRadius:0)])
    lab.targets=[target(1,50,80,radius:13)];lab.launch()
    lab.targets[0].previous=CGPoint(x:50,y:80);lab.targets[0].position=CGPoint(x:50,y:-80)
    let hits=lab.tick().contacts
    check("G08 doorway exposure during same contact interval is not missed",hits.count == 1 && (hits.first?.position.y ?? 100)<15)
    check("G09 damage waits until captured-origin LOS is clear",hits.first.map{!lab.geometry.segmentBlockedExact(lab.origin,$0.position)} == true)
    var clear=Lab();clear.geometry=lab.geometry;clear.viewport=lab.viewport;clear.origin=lab.origin
    clear.targets=[target(1,50,-80,radius:13)];clear.launch()
    clear.targets[0].previous=CGPoint(x:50,y:-80);clear.targets[0].position=CGPoint(x:50,y:80)
    check("G10 early clear contact still hits before later occlusion",clear.tick().contacts.count == 1)
    var several=lab
    several.model.boardHandoff();several.targets=[];several.launch()
    several.geometry.blockedFootprints.append(Footprint(center:CGPoint(x:-20,y:45),halfExtents:CGSize(width:2,height:35),cornerRadius:2,rotation:0.1))
    several.targets=[target(1,50,-80,radius:13)];several.targets[0].previous=CGPoint(x:50,y:80)
    check("G11 overlapping convex shadows find later exposed contact",several.tick().contacts.count == 1)
}
do {
    var lab=Lab();lab.model.select();for _ in 0..<199{lab.tick()};lab.tick(0.05)
    let frame=lab.model.advance(0.1,fromViewport:lab.viewport,toViewport:lab.viewport.offsetBy(dx:20,dy:0),
        fromOrigin:.zero,toOrigin:CGPoint(x:20,y:0),board:lab.board,attacker:lab.attacker,targets:[],geometry:.open)
    check("G12 subframe launch captures interpolated origin/viewport",frame.launched && near(Double(lab.model.sweep?.origin.x ?? -1),10) && near(Double(lab.model.sweep?.footprint.minX ?? -1),10))
    check("G13 subframe only advances postlaunch part of frame",near(lab.model.sweep?.age ?? -1,0.05))
    var end=Lab();end.launch();for _ in 0..<7{end.tick()}
    var late=target(1,190);late.previous.x=240;end.targets=[late]
    check("G14 motion after crossing ends cannot receive a retrohit",end.tick().contacts.isEmpty && end.model.sweep == nil)
}
do {
    // Independent dense-time reference catches misses; exact contact outputs
    // are also checked for both body overlap and clear LOS. A finite sampler
    // is not used to reject legitimate contacts in narrower visibility gaps.
    var seed:UInt64=71
    func sample()->CGFloat {seed=seed &* 6364136223846793005 &+ 1;return CGFloat((seed>>32)%10001)/10000}
    var noMisses=true,sound=true,positive=0
    for _ in 0..<80 {
        var lab=Lab();lab.viewport=CGRect(x:0,y:-100,width:750,height:200);lab.origin=CGPoint(x:-100,y:0)
        let y=sample()*100-50
        lab.geometry=ArenaGeometry(blockedFootprints:[
            Footprint(center:CGPoint(x:0,y:y),halfExtents:CGSize(width:2,height:20+sample()*35),cornerRadius:sample()*4,rotation:sample()*0.4-0.2),
            Footprint(center:CGPoint(x:-20,y:-y),halfExtents:CGSize(width:2,height:12+sample()*20),cornerRadius:2)
        ])
        lab.launch()
        let a=CGPoint(x:40+sample()*30,y:sample()*200-100)
        let b=CGPoint(x:a.x+sample()*20-10,y:sample()*200-100)
        let radius:CGFloat=5+sample()*13
        var t=target(1,b.x,b.y,radius:radius);t.previous=a;lab.targets=[t]
        var visible=false
        for i in 0...2000 {
            let fraction=CGFloat(i)/2000,p=a.lerp(to:b,t:fraction)
            let dx=p.x-100*fraction,dy=max(abs(p.y)-200/6,0)
            if dx*dx+dy*dy<radius*radius && !lab.geometry.segmentBlockedExact(lab.origin,p) {visible=true;break}
        }
        let hits=lab.tick().contacts
        if visible {positive+=1;noMisses = !hits.isEmpty && noMisses}
        if let hit=hits.first {
            let fraction=abs(b.y-a.y)>0.00001 ? (hit.position.y-a.y)/(b.y-a.y) : (hit.position.x-a.x)/(b.x-a.x)
            let dx=hit.position.x-100*fraction,dy=max(abs(hit.position.y)-200/6,0)
            sound = dx*dx+dy*dy <= radius*radius+0.0001 && !lab.geometry.segmentBlockedExact(lab.origin,hit.position) && sound
        }
    }
    check("G15 rotated/rounded multi-shadow moving-body oracle has no sampled misses",positive>10 && noMisses)
    check("G16 solver outputs overlap the actual front with clear captured LOS",sound)
}
do {
    var lab = Lab(); lab.targets = [target(1,100)]
    lab.launch(); lab.attacker.ordinaryBasis = 999
    let hit = lab.finish().first
    check("D01 launch snapshot10 produces35 not70 or live999", hit?.hit.dealt == 35 && lab.model.primaryMultiplier == 2)
    var defense = Lab(); defense.targets = [target(1,100)]
    defense.launch(); defense.targets[0].vulnerability = 2; defense.targets[0].defenseFactor = 0.75
    check("D02 live target vulnerability and defense applied once atcontact", defense.finish().first?.hit.dealt == 52)
    var crit = Lab(); crit.attacker.critChance = 1; crit.targets = [target(1,100)]
    crit.launch(); crit.attacker.critChance = 0; crit.attacker.critMultiplier = 99
    let critical = crit.finish().first
    check("D03 crit chance/multiplier captured atlaunch", critical?.crit == true && critical?.hit.dealt == 70)
    var lucky = Lab(); lucky.attacker.critChance = 1; lucky.attacker.luckyBreak = true; lucky.targets = [target(1,100)]
    lucky.launch()
    check("D04 existing LuckyBreak rule on crit", lucky.finish(random:{0}).first?.hit.dealt == 105)
    var split = Lab(); split.attacker.critChance = 0.5; split.targets=[target(2,100),target(1,100)]
    split.launch();let rolls: [CGFloat] = [0,0.9,0.9,0.9];var roll=0
    let two = split.finish(random:{ defer {roll += 1}; return rolls[min(roll,rolls.count-1)] })
    check("D05 independent per-target crit in deterministic contact order", two.count == 2 && two[0].targetID == 1 && two[0].crit && !two[1].crit)
    var zero = Lab();zero.attacker.ordinaryBasis=0;var snow = target(1,100);snow.snowman=true;zero.targets=[snow]
    zero.launch();let z=zero.finish().first
    check("D06 true zero not raised bydamage floor or melt", z?.hit.dealt == 0 && z?.meltsSnowman == false)
    var melt=Lab();melt.attacker.ordinaryBasis=0.1;snow.vulnerability=10;melt.targets=[snow]
    melt.launch();let m=melt.finish(random:{0.9}).first
    check("D07 positive basis0/dealt1plus uses shared Whiteout target entry", m?.hit.basis == 0 && m?.entry.basis == 1 && (m?.entry.dealt ?? 0)>0 && m?.meltsSnowman == true)
    var rewards=Lab();rewards.targets=[target(1,80,health:10),target(2,120,health:10)];rewards.targets[1].arenaBoss=true
    rewards.launch();let deaths=rewards.finish()
    check("D08 full capstone credit once per killed fixture", deaths.count == 2 && deaths.allSatisfy {$0.killed && $0.source == .capstone && $0.source.credit == .full})
    var queue=ChainReaction.Queue()
    for death in deaths where death.emitsChainRoot {queue.enqueue(ChainReaction.Burst(origin:death.position,generation:0,emitter:nil))}
    check("D09 shared ChainReaction queue gets one nonboss root", queue.next()?.generation == 0 && queue.next() == nil)
}
do {
    var lab=Lab();lab.targets=[target(1,20)]
    var maximumHitIDs=0
    var clean=true
    for _ in 0..<150 {
        lab.model.boardHandoff();lab.launch();lab.tick();lab.model.setHold(.pause,true)
        maximumHitIDs=max(maximumHitIDs,lab.model.sweep?.hitIDs.count ?? 0)
        lab.model.endRun();clean = lab.model.sweep == nil && lab.tick(1).contacts.isEmpty && clean
        lab.model.newRun()
    }
    check("L01 repeated retirement clears populated pendingfront",clean)
    check("L02 populated state bounded and reset across150 cycles",maximumHitIDs==1 && lab.model.launches == 0)
    let root=CommandLine.arguments[1]
    let scene=try String(contentsOfFile:root+"/Sparkforge/Prototypes/RainbowP1Scene.swift",encoding:.utf8)
    let model=try String(contentsOfFile:root+"/Sparkforge/Prototypes/RainbowP1Model.swift",encoding:.utf8)
    let entry=try String(contentsOfFile:root+"/Sparkforge/GameViewController.swift",encoding:.utf8)
    check("S01 entry requires explicit debug launch argument",entry.contains("#if DEBUG\n            if ProcessInfo.processInfo.arguments.contains(\"--rainbow-p1\")"))
    check("S02 prototype scene/model compile only under DEBUG",scene.contains("#if DEBUG") && model.contains("#if DEBUG"))
    let executable=(scene+"\n"+model).split(separator:"\n").filter { !$0.trimmingCharacters(in:.whitespaces).hasPrefix("//") }.joined(separator:"\n")
    check("S03 no production combat/reward/save call sites",!["GameScene(","UpgradeManager(","PlayerStats(","UserDefaults","ProgressionManager.","CodexManager.","SKAction",".run("].contains {executable.contains($0)})
    check("S04 existing joystick and timer HUD reused",scene.contains("VirtualJoystick()") && scene.contains("CapstoneTimerHUD()"))
    check("S05 renderer tracks model contact line and snapshot",scene.contains("sweep.frontX") && scene.contains("captured?.origin ?? spark.position") && scene.contains("captured?.attacker.longShotT4 ?? attacker.longShotT4"))
    check("S06 lifecycle removes observers and fixture graph",scene.contains("NotificationCenter.default.removeObserver(self)") && scene.contains("world.removeAllChildren()") && scene.contains("timerHUD.clearAll()"))
}
do {
    let field = CGRect(x:0,y:0,width:200,height:200)
    let board = CGRect(x:-1000,y:-1000,width:2000,height:2000)
    func lane(_ y:CGFloat)->CGRect { RainbowP1Model.laneFootprint(viewport:field,origin:CGPoint(x:10,y:y),board:board) }
    check("N01 lane is one third visible height centered on Spark",near(Double(lane(100).height),200/3) && near(Double(lane(100).midY),100) && lane(100).width==200)
    check("N02 proposed aim follows Spark before firing",near(Double(lane(140).midY-lane(100).midY),40))
    check("N03 top clipping trims rather than shifting center",near(Double(lane(200).minY),200-200/6) && lane(200).maxY==200 && near(Double(lane(200).height),200/6))
    check("N04 bottom clipping trims rather than shifting center",lane(0).minY==0 && near(Double(lane(0).maxY),200/6))
    let clipped = RainbowP1Model.laneFootprint(viewport:field,origin:CGPoint(x:10,y:100),board:CGRect(x:0,y:40,width:200,height:120))
    check("N05 one third uses actual captured visible battlefield",clipped==CGRect(x:0,y:80,width:200,height:40))
    check("N06 no overlap yields no lane",RainbowP1Model.laneFootprint(viewport:field,origin:.zero,board:CGRect(x:500,y:500,width:20,height:20)).isNull)
    var aimed=Lab();aimed.targets=[target(1,100,100),target(2,100,160),target(3,100,40)];aimed.launch()
    let captured=aimed.model.sweep?.footprint;aimed.origin.y=180;aimed.viewport.origin.y=200
    check("N07 Spark movement and vertical camera pan cannot drag fired lane",aimed.finish().map(\.targetID)==[1] && captured==lane(100))
    var edge=Lab();edge.targets=[target(1,100,135,radius:2),target(2,100,136,radius:2)];edge.launch()
    check("N08 actual body edge touching lane counts; wholly outside spared",edge.finish().map(\.targetID)==[1])
    var entering=Lab();entering.launch();for _ in 0..<3 {entering.tick()}
    var t=target(1,100,100);t.previous.y=190;entering.targets=[t]
    let entry=entering.tick().contacts
    check("N09 entering target hits at traveling contact within lane",entry.count==1 && (entry.first?.position.y ?? 999)<136)
    check("N10 target remains one hit despite staying in lane",entering.finish().isEmpty)
    var crossing=Lab();crossing.launch();for _ in 0..<3{crossing.tick()};t=target(1,100,20);t.previous.y=180;crossing.targets=[t]
    check("N11 target crossing entire lane within frame is not missed",crossing.tick().contacts.count==1)
    var leaving=Lab();leaving.launch();for _ in 0..<3{leaving.tick()};t=target(1,100,190);t.previous.y=100;leaving.targets=[t]
    check("N12 target leaving lane before front arrives is unharmed",leaving.tick().contacts.isEmpty)
    var outside=Lab();outside.attacker.longShotT4=true;outside.geometry=wall;outside.targets=[target(1,100,180)];outside.launch()
    check("N13 LongShot permits walls but never widens lane",outside.finish().isEmpty)
    var held=Lab();held.model.select();for _ in 0..<195{held.tick()};held.model.setHold(.pause,true)
    let remaining=held.model.remaining, aim=lane(held.origin.y)
    for _ in 0..<20{held.tick(10)}
    check("N14 paused warning retains clock and proposed aim",held.model.warning && held.model.remaining==remaining && lane(held.origin.y)==aim && held.model.sweep==nil)
    held.model.setHold(.pause,false);for _ in 0..<5{held.tick()};let saved=held.model.sweep
    held.model.setHold(.pause,true);held.origin.y=170;held.tick(10)
    check("N15 paused sweep retains captured lane and contact age",held.model.sweep?.footprint==saved?.footprint && held.model.sweep?.age==saved?.age)
    held.model.setHold(.pause,false);held.model.boardHandoff();held.targets=[target(1,100,170),target(2,100,100)];held.launch()
    check("N16 board clears old lane and captures new Spark aim",held.finish().map(\.targetID)==[1])
    held.model.newRun();check("N17 fresh run clears lane ownership and warning",held.model.sweep==nil && !held.model.warning && !held.model.owned)
    var launch=Lab();launch.model.select();for _ in 0..<199{launch.tick()};launch.tick(0.05)
    let f=launch.model.advance(0.1,fromViewport:field,toViewport:CGRect(x:20,y:0,width:200,height:400),fromOrigin:CGPoint(x:10,y:20),toOrigin:CGPoint(x:30,y:180),board:board,attacker:launch.attacker,targets:[],geometry:.open)
    check("N18 exact subframe captures interpolated Spark Y and visible height",f.launched && near(Double(launch.model.sweep?.origin.y ?? -1),100) && near(Double(launch.model.sweep?.footprint.height ?? -1),100) && near(Double(launch.model.sweep?.footprint.minY ?? -1),50))
    var top=Lab();top.origin.y=200;top.targets=[target(1,100,190),target(2,100,210),target(3,100,160)];top.launch()
    check("N21 clipped lane contact cannot leak above viewport or below proposed lane",top.finish().map(\.targetID)==[1])
    let root=CommandLine.arguments[1]
    let scene=try String(contentsOfFile:root+"/Sparkforge/Prototypes/RainbowP1Scene.swift",encoding:.utf8)
    check("N19 warning and launch use shared lane geometry",scene.contains("RainbowP1Model.laneFootprint(viewport: viewport, origin: spark.position, board: board)") && scene.contains("warningGuide.fillColor"))
    check("N20 visible front and bands use exact captured hit rectangle",scene.contains("sweep.footprint.minY") && scene.contains("sweep.footprint.maxY") && scene.contains("sweep.footprint.height / CGFloat(bands.count)"))
}
print("Rainbow P1: \(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
