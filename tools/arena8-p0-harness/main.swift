import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ value:Bool){if value{passed+=1;print("PASS \(name)")}else{failed+=1;print("FAIL \(name)")}}
func near(_ a:CGFloat,_ b:CGFloat)->Bool{abs(a-b)<0.001}
let stage=Arena8P0Model()
let rect=Arena8P0Bounds.rectangle(CGRect(x:-420,y:-240,width:840,height:480))
check("B01 default proof bounds remain circle",Arena8P0Bounds().contains(CGPoint(x:420,y:0)) && !Arena8P0Bounds().contains(CGPoint(x:420,y:420)))
check("B02 rectangle admits room corners outside circle",rect.contains(CGPoint(x:400,y:220),bodyRadius:14) && !Arena8P0Bounds().contains(CGPoint(x:400,y:220),bodyRadius:14))
check("B03 body inset respects all rectangle edges",rect.clamped(CGPoint(x:900,y:-900),bodyRadius:40)==CGPoint(x:380,y:-200))
check("B04 translated circle clamps relative to center",Arena8P0Bounds.circle(center:CGPoint(x:100,y:100),radius:50).clamped(CGPoint(x:200,y:100),bodyRadius:10)==CGPoint(x:140,y:100))
check("B05 oversized body refuses bounds",rect.clamped(.zero,bodyRadius:500)==nil)
check("B06 invalid inputs refused",rect.clamped(CGPoint(x:CGFloat.nan,y:0),bodyRadius:14)==nil && rect.clamped(.zero,bodyRadius:-1)==nil && rect.clamped(.zero,bodyRadius:CGFloat.infinity)==nil)
check("F01 two wall blocks leave permanent open corridor",stage.geometry.blockedFootprints.count==2 && !stage.geometry.isBlocked(.zero,margin:40))
check("F02 top and bottom central voids are solid",stage.geometry.isBlocked(CGPoint(x:0,y:160)) && stage.geometry.isBlocked(CGPoint(x:0,y:-160)))
check("F03 room anchors safe for largest declared footprint",stage.geometry.safeAnchors.allSatisfy{stage.valid($0.position,radius:40)})
check("F04 no radial rejection of building corner",stage.valid(CGPoint(x:380,y:190),radius:40))
for radius:CGFloat in [14,26,40] {
 let from=CGPoint(x:-280,y:0),to=CGPoint(x:280,y:0)
 check("M01 radius\(radius) passes open corridor",stage.move(from:from,toward:to,radius:radius)==to)
 let blocked=stage.move(from:CGPoint(x:-280,y:160),toward:CGPoint(x:280,y:160),radius:radius)
 check("M02 radius\(radius) highspeed shove cannot tunnel wall",blocked.map{$0.x < -100 && stage.valid($0,radius:radius)} == true)
 let corner=stage.move(from:CGPoint(x:-280,y:160),toward:CGPoint(x:0,y:0),radius:radius)
 check("M03 radius\(radius) axis sliding stays clear",corner.map{stage.valid($0,radius:radius) && $0.y==0} == true)
 let boundary=stage.move(from:CGPoint(x:-280,y:0),toward:CGPoint(x:-999,y:-999),radius:radius)
 check("M04 radius\(radius) outward displacement stays in rectangle",boundary.map{rect.contains($0,bodyRadius:radius) && stage.valid($0,radius:radius)} == true)
}
for radius:CGFloat in [14,26,40] {
 let start=CGPoint(x:-280,y:160),goal=CGPoint(x:280,y:-160)
 let stopped=stage.shove(from:start,toward:goal,radius:radius)
 check("M08 direct diagonal shove stops on its original chord \(radius)",stopped.map{stage.valid($0,radius:radius) && $0.x < -100 && near(($0.x-start.x)*(-320),($0.y-start.y)*560)} == true)
 check("M09 direct doorway shove remains clear \(radius)",stage.shove(from:CGPoint(x:-280,y:0),toward:CGPoint(x:280,y:0),radius:radius)==CGPoint(x:280,y:0))
}
for radius:CGFloat in [14,26,40] {
 let near=60-radius-0.5,beyond=60-radius+0.5
 check("M10 body-clear doorway jamb passes \(radius)",stage.move(from:CGPoint(x:-280,y:near),toward:CGPoint(x:280,y:near),radius:radius)==CGPoint(x:280,y:near))
 check("M11 too-close doorway jamb stops \(radius)",stage.move(from:CGPoint(x:-280,y:beyond),toward:CGPoint(x:280,y:beyond),radius:radius).map{$0.x < -100} == true)
 let touch=CGPoint(x:-100-radius,y:160)
 check("M12 wall-touch walking can move away \(radius)",stage.move(from:touch,toward:CGPoint(x:touch.x-20,y:160),radius:radius)==CGPoint(x:touch.x-20,y:160))
 check("M13 wall-touch walking can slide along \(radius)",stage.move(from:touch,toward:CGPoint(x:touch.x,y:120),radius:radius)==CGPoint(x:touch.x,y:120))
 check("M14 wall-touch walking cannot enter solid \(radius)",stage.move(from:touch,toward:CGPoint(x:0,y:160),radius:radius)==touch)
}
check("M05 invalid wall start never teleports",stage.move(from:CGPoint(x:0,y:150),toward:.zero,radius:14)==nil)
check("M06 invalid huge actor never enters corridor",stage.move(from:CGPoint(x:-280,y:0),toward:CGPoint(x:280,y:0),radius:70).map{$0.x < -100} == true)
// Execute repeated corner approaches and displacement sequences using the actual move seam.
var seed:UInt64=8
func draw()->CGFloat{seed=seed &* 6364136223846793005 &+ 1;return CGFloat((seed>>32)%10001)/10000}
var safe=true,moved=0
for radius:CGFloat in [14,26,40]{
 var position=CGPoint(x:-280,y:0)
 for _ in 0..<1500 {
  let desired=position+CGPoint(x:(draw()-0.5)*180,y:(draw()-0.5)*180)
  if let p=stage.move(from:position,toward:desired,radius:radius){safe = stage.valid(p,radius:radius) && safe;if p != position{moved+=1};position=p}else{safe=false}
 }
}
check("M07 4500 seeded movement/displacement endpoints remain clear",safe && moved>3000)
for radius:CGFloat in [14,26,40] {
 for sign:CGFloat in [-1,1] {
  var position=CGPoint(x:sign * -280,y:160), goal=CGPoint(x:sign * 280,y:160)
  var safe=true,steps=0
  for _ in 0..<500 {
   guard let next=stage.chase(from:position,goal:goal,radius:radius,dt:0.1) else{safe=false;break}
   safe = stage.valid(next,radius:radius) && safe;position=next;steps+=1
   if position.distance(to:goal)<0.1{break}
  }
  check("R01 radius\(radius) direction\(sign) routes through door without sticking",safe && position.distance(to:goal)<0.1 && steps<300)
 }
}
for goal in [CGPoint(x:-114,y:150),CGPoint(x:-406,y:100)] {
 for radius:CGFloat in [26,40] {
  var position=CGPoint(x:280,y:150)
  let aim=stage.approach(goal,radius:radius)
  for _ in 0..<500 {if let next=stage.chase(from:position,goal:goal,radius:radius,dt:0.1){position=next}}
  check("R05 large body reaches safe approach to wall-adjacent Spark \(radius) \(goal.x)",aim.map{stage.valid(position,radius:radius) && position.distance(to:$0)<0.1} == true)
 }
}
check("R02 oversized enemy has no unsafe graph fallback",stage.chase(from:CGPoint(x:-280,y:160),goal:CGPoint(x:280,y:160),radius:70,dt:0.1)==nil)
check("R03 unreachable or invalid goal refused",stage.chase(from:CGPoint(x:-280,y:0),goal:CGPoint(x:0,y:150),radius:14,dt:0.1)==nil)
check("R04 route edge clearance is checked for actual body",stage.geometry.graphWaypoint(from:CGPoint(x:-280,y:160),toward:CGPoint(x:280,y:160),travelRadius:70,arriveRadius:5)==nil)
let candidates=[CGPoint(x:900,y:0),CGPoint(x:0,y:150),CGPoint(x:-280,y:0),CGPoint(x:280,y:0)]
check("S01 spawn filters outside walls and player clearance",stage.spawn(candidates:candidates,radius:40,avoiding:CGPoint(x:-280,y:0),clearance:80)==CGPoint(x:280,y:0))
check("S02 rejected candidates return nil not unsafe fallback",stage.spawn(candidates:Array(candidates.prefix(3)),radius:40,avoiding:CGPoint(x:-280,y:0),clearance:80)==nil)
check("W01 ordinary shot blocks on room wall",!stage.shotClear(from:CGPoint(x:-280,y:150),to:CGPoint(x:280,y:150),longShot:false))
check("W02 doorway sightline permits ordinary shot",stage.shotClear(from:CGPoint(x:-280,y:0),to:CGPoint(x:280,y:0),longShot:false))
check("W03 LongShot retains terrain passage",stage.shotClear(from:CGPoint(x:-280,y:150),to:CGPoint(x:280,y:150),longShot:true))
check("W04 LongShot does not invent offboard target",!stage.shotClear(from:.zero,to:CGPoint(x:900,y:0),longShot:true))
check("W05 rectangular projectile retirement admits room corner",stage.projectileAlive(CGPoint(x:410,y:230)))
check("W06 projectile margin bounded without radial cleanup",stage.projectileAlive(CGPoint(x:450,y:0)) && !stage.projectileAlive(CGPoint(x:461,y:0)))
var lab=Arena8P0Model();let initial=lab.player,enemy=lab.enemies;lab.held=true;lab.step(5,direction:CGPoint(x:1,y:0))
check("L01 hold freezes actors and fixture attacks",lab.player==initial && lab.enemies==enemy && lab.shotCount==0 && lab.elapsed==0)
lab.held=false;lab.step(100,direction:CGPoint(x:1,y:0));check("L02 hitch bounded to active step",near(CGFloat(lab.elapsed),0.1) && lab.player.x-initial.x<=16.001)
for _ in 0..<100{lab.step(0.1,direction:.zero)};check("L03 finite fixture actors remain valid",stage.valid(lab.player,radius:14) && lab.enemies.enumerated().allSatisfy{stage.valid($0.element,radius:GameConfig.Arena8Prototype.enemyRadii[$0.offset])})
let root=CommandLine.arguments[1]
let model=try String(contentsOfFile:root+"/Sparkforge/Prototypes/Arena8P0Model.swift",encoding:.utf8)
check("I01 no production activation or persistence calls",!["GameScene(","UpgradeManager(","PlayerStats(","UserDefaults","ProgressionManager.","ArenaConfig("].contains{model.contains($0)})
func rainbowHits(origin:CGPoint,points:[CGPoint],longShot:Bool)->[Int] {
 var rainbow=RainbowP1Model();rainbow.select();var attacker=RainbowP1Model.Attacker();attacker.longShotT4=longShot
 let targets=points.enumerated().map { RainbowP1Model.Target(id:$0.offset,previous:$0.element,position:$0.element) }
 var hits:[Int]=[]
 for _ in 0..<210 {
  let frame=rainbow.advance(0.1,fromViewport:GameConfig.Arena8Prototype.world,toViewport:GameConfig.Arena8Prototype.world,fromOrigin:origin,toOrigin:origin,board:GameConfig.Arena8Prototype.world,attacker:attacker,targets:targets,geometry:stage.geometry,random:{0.9})
  hits += frame.contacts.map(\.targetID)
 }
 return hits
}
check("X01 unchanged Rainbow lane crosses clear doorway",rainbowHits(origin:CGPoint(x:-280,y:0),points:[CGPoint(x:280,y:0),CGPoint(x:280,y:180)],longShot:false)==[0])
check("X02 unchanged Rainbow lane respects room wall",rainbowHits(origin:CGPoint(x:-280,y:150),points:[CGPoint(x:280,y:150)],longShot:false).isEmpty)
check("X03 unchanged Rainbow LongShot passes wall but not outside lane",rainbowHits(origin:CGPoint(x:-280,y:150),points:[CGPoint(x:280,y:150),CGPoint(x:280,y:-150)],longShot:true)==[0])
let scene=try String(contentsOfFile:root+"/Sparkforge/Prototypes/Arena8P0Scene.swift",encoding:.utf8)
let entry=try String(contentsOfFile:root+"/Sparkforge/GameViewController.swift",encoding:.utf8)
check("I02 DEBUG entry optin keeps Rainbow first and catalog gate",entry.contains("if ProcessInfo.processInfo.arguments.contains(\"--rainbow-p1\")") && entry.contains("else if ProcessInfo.processInfo.arguments.contains(\"--arena8-p0\")") && entry.contains("case .failure(let failure):"))
check("I03 prototype source guarded DEBUG",["Arena8P0Config","Arena8P0Bounds","Arena8P0Model","Arena8P0Scene"].allSatisfy{ name in (try? String(contentsOfFile:root+"/Sparkforge/Prototypes/"+name+".swift",encoding:.utf8).contains("#if DEBUG")) == true})
check("I04 no live systems in scene",!["GameScene(","UpgradeManager(","PlayerStats(","UserDefaults","ProgressionManager.","ArenaConfig("].contains{scene.contains($0)})
check("I05 overview scales world not joystick camera",scene.contains("world.setScale(") && !scene.contains("rig.setScale("))
check("I06 scene retirement clears graph holds and observers",scene.contains("NotificationCenter.default.removeObserver(self)") && scene.contains("world.removeAllChildren()") && scene.contains("manualPause = false; foreground = true; installed = false"))
check("I07 probe artwork uses capture not live moving origin",scene.contains("model.lastShotFrom") && scene.contains("model.lastShotEnd"))
var probeLab=Arena8P0Model();for _ in 0..<20{probeLab.step(0.1,direction:.zero)}
check("W07 ordinary probe snapshot stops before wall",probeLab.lastShotEnd.map{$0.x < -100} == true && probeLab.lastShotFrom==CGPoint(x:-280,y:150))
probeLab.longShot=true;for _ in 0..<20{probeLab.step(0.1,direction:.zero)}
check("W08 next LongShot probe captures complete clear ray",probeLab.lastShotEnd==CGPoint(x:280,y:150) && probeLab.lastShotClear)
print("Arena8 P0: \(passed) passed, \(failed) failed")
exit(failed==0 ? 0:1)
