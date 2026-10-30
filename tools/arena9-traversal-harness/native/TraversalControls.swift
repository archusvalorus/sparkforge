import XCTest
final class TraversalControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 func probe(_ id:String)->XCUIElement{game.descendants(matching:.any).matching(identifier:id).firstMatch}
 func sample(_ id:String="arena8-six-probe")throws->[String:Any]{
  let p=probe(id);XCTAssertTrue(p.waitForExistence(timeout:15));let text=try XCTUnwrap(p.value as? String),data=try XCTUnwrap(text.data(using:.utf8));return try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
 }
 func tap(_ x:Double,_ y:Double){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func shot(_ label:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=label;a.lifetime = .keepAlways;add(a)}
 func awaitState(_ label:String,_ timeout:TimeInterval=25,_ predicate:([String:Any])->Bool)throws->[String:Any]{
  let end=Date().addingTimeInterval(timeout);var value=try sample()
  while !predicate(value) && Date()<end{Thread.sleep(forTimeInterval:0.15);value=try sample()}
  XCTAssertTrue(predicate(value),label+" "+String(describing:value));return value
 }
 func move(_ axis:String,_ target:Double)throws {
  for _ in 0..<22 {
   let s=try sample();XCTAssertEqual(s["state"] as? String,"playing");XCTAssertEqual(s["safe"] as? Bool,true)
   let current=try XCTUnwrap(s[axis] as? Double),delta=target-current
   if abs(delta)<25{return}
   let joy=game.coordinate(withNormalizedOffset:CGVector(dx:0.24,dy:0.77))
   // Short corrections use partial stick deflection, not the same full-speed
   // minimum gesture that can oscillate across the target on a real device.
   let magnitude=CGFloat(max(12,min(75,abs(delta)*0.6)))
   let dx:CGFloat=axis=="x" ? (delta>0 ? magnitude:-magnitude):0
   let dy:CGFloat=axis=="y" ? (delta>0 ? -magnitude:magnitude):0
   joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:dx,dy:dy)),withVelocity:.fast,thenHoldForDuration:min(0.65,max(0.06,abs(delta)/270)))
  }
  XCTFail("Could not reach "+axis+" target "+String(target))
 }
 func fightUntil(_ label:String,_ predicate:([String:Any])->Bool)throws->[String:Any]{
  for _ in 0..<12 {
   let s=try sample();if predicate(s){return s}
   XCTAssertEqual(s["state"] as? String,"playing",label)
   let px=try XCTUnwrap(s["x"] as? Double),py=try XCTUnwrap(s["y"] as? Double)
   let roots=(s["enemyRoots"] as? [[String:Any]] ?? []).compactMap { v -> (Double,Double)? in
    guard let x=v["x"] as? Double,let y=v["y"] as? Double else{return nil};return (x,y)
   }
   guard let target=roots.min(by:{hypot($0.0-px,$0.1-py)<hypot($1.0-px,$1.1-py)}) else{Thread.sleep(forTimeInterval:0.2);continue}
   let dx=target.0-px,dy=target.1-py,length=max(1,hypot(dx,dy))
   let joy=game.coordinate(withNormalizedOffset:CGVector(dx:0.24,dy:0.77))
   // Closing on a scaled ranged enemy is actual counterplay: iPad standoff
   // may exceed the ordinary gun range. No model kill or range override.
   joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:75*dx/length,dy:-75*dy/length)),withVelocity:.fast,thenHoldForDuration:2.2)
  }
  let last=try sample();XCTAssertTrue(predicate(last),label+" "+String(describing:last));return last
 }
 func fire(_ enabled:Bool)throws{let s=try sample();if s["testFireEnabled"] as? Bool != enabled{tap(try XCTUnwrap(s["fireX"] as? Double),try XCTUnwrap(s["fireY"] as? Double))};XCTAssertEqual(try sample()["testFireEnabled"] as? Bool,enabled)}
 func start()throws->[String:Any]{
  game.launchArguments=["--arena9-traversal","--arena8-title","--arena8-title-input","--arena8-six-input","--arena9-controlled-loadout"]
  game.launch();let title=try sample("arena8-title-probe");XCTAssertEqual(title["isolated"] as? Bool,true)
  tap(try XCTUnwrap(title["playX"] as? Double),try XCTUnwrap(title["playY"] as? Double))
  let s=try sample();XCTAssertEqual(s["arena9Traversal"] as? Bool,true);XCTAssertEqual(s["controlledSwiftTier"] as? Int,1)
  XCTAssertFalse((s["activeFamilies"] as? [String] ?? []).contains("Growth"));return s
 }
 override func tearDown(){game.terminate();super.tearDown()}
 func testRealTraversalBothGoalOrdersPauseRetreat()throws {
  continueAfterFailure=false
  for goalFirst in [false,true] {
   let initial=try start(),epoch=try XCTUnwrap(initial["entryEpoch"] as? String)
   try fire(false);try move("y",250);try move("x",320)
   let activated=try awaitState("first packet registered"){($0["packetRegistrations"] as? [String:Int])?["entry"]==2}
   let ids=try XCTUnwrap(activated["liveMemberIDs"] as? [String]);XCTAssertEqual(ids.count,2)
   try move("x",-200);let retreated=try sample();XCTAssertEqual(retreated["liveMemberIDs"] as? [String],ids)
   try move("x",320);XCTAssertEqual((try sample()["packetRegistrations"] as? [String:Int])?["entry"],2)
   tap(Double(game.frame.width)-30,80);let paused=try awaitState("manual pause"){($0["state"] as? String)=="paused"}
   Thread.sleep(forTimeInterval:1);let held=try sample();XCTAssertEqual(paused["wave"] as? Double,held["wave"] as? Double);XCTAssertEqual(held["liveMemberIDs"] as? [String],ids)
   XCUIDevice.shared.press(.home);Thread.sleep(forTimeInterval:1);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15))
   let nested=try sample();XCTAssertEqual(nested["state"] as? String,"paused");XCTAssertEqual(nested["entryEpoch"] as? String,epoch);XCTAssertEqual(nested["wave"] as? Double,paused["wave"] as? Double)
   shot(goalFirst ? "A9-goal-first-paused-background":"A9-clear-first-paused-background")
   tap(Double(game.frame.width)/2,Double(game.frame.height)/2+124)
   _ = try awaitState("resume"){($0["state"] as? String)=="playing"}
   let beforeBackground=try sample();XCUIDevice.shared.press(.home);Thread.sleep(forTimeInterval:1);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15))
   let afterBackground=try sample();XCTAssertEqual(afterBackground["entryEpoch"] as? String,epoch)
   XCTAssertEqual(afterBackground["backgroundWave"] as? Double,afterBackground["foregroundWave"] as? Double)
   XCTAssertGreaterThan(afterBackground["backgroundCount"] as? Int ?? 0,beforeBackground["backgroundCount"] as? Int ?? 0)
   XCTAssertGreaterThan(afterBackground["foregroundCount"] as? Int ?? 0,beforeBackground["foregroundCount"] as? Int ?? 0)
   try move("x",1500)
   _ = try awaitState("final packet registered"){($0["packetRegistrations"] as? [String:Int])?["final"]==2}
   if goalFirst {
    try move("x",2400);try move("y",0)
    let reached=try awaitState("visible goal reached"){($0["goalReached"] as? Bool)==true}
    XCTAssertEqual(reached["successCount"] as? Int,0);try fire(true)
    _ = try fightUntil("ordinary projectile final clears after goal"){($0["successCount"] as? Int)==1}
   } else {
    try fire(true)
    let cleared=try fightUntil("ordinary projectile kills"){($0["kills"] as? Int ?? 0)>=4}
    XCTAssertEqual(cleared["successCount"] as? Int,0)
    try move("x",2400);try move("y",0)
    _ = try awaitState("goal completes after ordinary clear"){($0["successCount"] as? Int)==1}
   }
   let complete=try sample();XCTAssertGreaterThan(complete["kills"] as? Int ?? 0,1)
   shot(goalFirst ? "A9-goal-then-real-gun-clear":"A9-real-gun-clear-then-goal")
   try move("x",2200);try move("x",2400);XCTAssertEqual(try sample()["successCount"] as? Int,1)
   tap(Double(game.frame.width)-30,80);_ = try awaitState("pause before Title"){($0["state"] as? String)=="paused"}
   tap(Double(game.frame.width)/2,Double(game.frame.height)/2+232)
   tap(Double(game.frame.width)/2,Double(game.frame.height)/2+59)
   let returned=try sample("arena8-title-probe");XCTAssertEqual(returned["selectedFloor"] as? Int,9)
   tap(try XCTUnwrap(returned["playX"] as? Double),try XCTUnwrap(returned["playY"] as? Double))
   let fresh=try sample();XCTAssertNotEqual(fresh["entryEpoch"] as? String,epoch);XCTAssertEqual(fresh["successCount"] as? Int,0);XCTAssertEqual(fresh["kills"] as? Int,0)
   game.terminate()
  }
 }
}
