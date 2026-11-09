import XCTest
/// Only native touches and existing read-only probes; no injected HP/time/placement.
final class LockmarshalControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 override func tearDown(){game.terminate();super.tearDown()}
 func sample(_ id:String="arena8-six-probe")throws->[String:Any]{
  let probe=game.descendants(matching:.any).matching(identifier:id).firstMatch
  XCTAssertTrue(probe.waitForExistence(timeout:12))
  let text=try XCTUnwrap(probe.value as? String),data=try XCTUnwrap(text.data(using:.utf8))
  return try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
 }
 func boss(_ s:[String:Any])->[String:Any]{s["lockmarshal"] as? [String:Any] ?? [:]}
 func tap(_ x:Double,_ y:Double){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func control(_ name:String,_ s:[String:Any])throws{tap(try XCTUnwrap(s[name+"X"] as? Double),try XCTUnwrap(s[name+"Y"] as? Double))}
 func wait(_ title:String,timeout:TimeInterval=18,_ predicate:([String:Any])->Bool)throws->[String:Any]{
  let end=Date().addingTimeInterval(timeout);var s=try sample()
  while !predicate(s) && Date()<end {Thread.sleep(forTimeInterval:0.1);s=try sample()}
  XCTAssertTrue(predicate(s),title+" "+String(describing:s));return s
 }
 func record(_ name:String,_ s:[String:Any],screenshot:Bool=true)throws{
  let data=try JSONSerialization.data(withJSONObject:s,options:[.prettyPrinted,.sortedKeys]);let a=XCTAttachment(data:data,uniformTypeIdentifier:"public.json");a.name=name;a.lifetime = .keepAlways;add(a)
  if screenshot{let image=XCTAttachment(screenshot:game.screenshot());image.name=name;image.lifetime = .keepAlways;add(image)}
 }
 func start()throws->[String:Any]{
  game.launchArguments=["--arena8-six","--arena8-title","--arena8-lockmarshal","--arena8-title-input","--arena8-six-input"]
  game.launch();let t=try sample("arena8-title-probe");XCTAssertEqual(t["isolated"] as? Bool,true);XCTAssertEqual(t["registeredArenas"] as? Int,7)
  tap(try XCTUnwrap(t["playX"] as? Double),try XCTUnwrap(t["playY"] as? Double))
  let s=try wait("actualLockmarshalPlay") {self.boss($0)["id"] != nil && $0["state"] as? String=="playing"}
  XCTAssertEqual(s["safe"] as? Bool,true);XCTAssertEqual(s["enemies"] as? Int,0);XCTAssertEqual(boss(s)["safe"] as? Bool,true);return s
 }
 func fireOff()throws{let s=try sample();if s["lockmarshalFire"] as? Bool==true{try control("lockmarshalFire",s)};_=try wait("FIRE OFF"){$0["lockmarshalFire"] as? Bool==false}}
 func drag(_ dx:Double,_ dy:Double,_ hold:TimeInterval){let j=game.coordinate(withNormalizedOffset:CGVector(dx:0.24,dy:0.77));j.press(forDuration:0.05,thenDragTo:j.withOffset(CGVector(dx:dx,dy:dy)),withVelocity:.fast,thenHoldForDuration:hold)}
 func testRealShotsMovementHoldsAndPaintedStamp()throws{
  _=try start()
  let hit=try wait("ordinaryshotsdamageactualboss",timeout:8){(self.boss($0)["hp"] as? Int ?? 180)<180}
  try record("actual-shot-damage",hit);try fireOff()
  let y=try XCTUnwrap(hit["y"] as? Double);drag(0,-60,0.7)
  let moved=try sample();XCTAssertGreaterThan(abs((moved["y"] as? Double ?? y)-y),20);XCTAssertEqual(moved["safe"] as? Bool,true)
  tap(Double(game.frame.width)-30,80)
  let paused=try wait("pause"){$0["state"] as? String=="paused"};let held=boss(paused)
  Thread.sleep(forTimeInterval:0.7)
  let later=try sample();XCTAssertEqual(boss(later)["remaining"] as? Double,held["remaining"] as? Double);XCTAssertEqual(boss(later)["x"] as? Double,held["x"] as? Double);XCTAssertEqual(boss(later)["commits"] as? Int,held["commits"] as? Int)
  XCUIDevice.shared.press(.home);Thread.sleep(forTimeInterval:0.6);game.activate()
  let background=try sample();XCTAssertEqual(background["state"] as? String,"paused");XCTAssertEqual(boss(background)["remaining"] as? Double,held["remaining"] as? Double)
  try record("native-pause-background-hold",background);try control("resumeButton",background)
  _=try wait("resume"){$0["state"] as? String=="playing"}
  // A fresh real run makes the positive evade independent of earlier contact damage.
  // Do not inject HP, positions, time or attack phase; all movement is joystick input.
  game.terminate();let fresh=try start();let id=try XCTUnwrap(boss(fresh)["id"] as? String)
  XCTAssertEqual(fresh["hp"] as? Int,100);try fireOff()
  _=try wait("first-threshold-commit",timeout:10){self.boss($0)["commits"] as? Int==1 && $0["state"] as? String=="playing"}
  // Preposition after the first committed charge; waiting for a screenshot at the final tell frame
  // previously allowed a later death to satisfy the weak commit-only predicate.
  drag(60,0,0.3)
  let stamp=try wait("first-painted-stamp",timeout:8){self.boss($0)["commits"] as? Int==1 && self.boss($0)["phase"] as? String=="stampWarning" && self.boss($0)["tell"] as? Bool==true && $0["state"] as? String=="playing"}
  let hp=try XCTUnwrap(stamp["hp"] as? Int);XCTAssertGreaterThan(hp,0)
  try record("native-first-stamp-warning-probe",stamp,screenshot:false)
  drag(60,0,0.15)
  let committed=try wait("living-first-stamp-postcommit",timeout:5){self.boss($0)["commits"] as? Int==2 && $0["state"] as? String=="playing" && ($0["hp"] as? Int ?? 0)>0}
  XCTAssertEqual(committed["hp"] as? Int,hp,"A positive escape must survive without Stamp/contact damage")
  XCTAssertEqual(boss(committed)["id"] as? String,id);XCTAssertEqual(boss(committed)["safe"] as? Bool,true);XCTAssertEqual(committed["safe"] as? Bool,true)
  try record("native-living-first-stamp-postcommit",committed)
 }
 func testNaturalDeathRestartAndTitlePlayFreshBoss()throws{
  let s=try start();let old=try XCTUnwrap(boss(s)["id"] as? String);try fireOff()
  let dead=try wait("realbosscontactdeath",timeout:45){$0["state"] as? String=="dead"}
  XCTAssertEqual(boss(dead)["phase"] as? String,"pursuit");try record("native-death-old-attack-interrupted",dead)
  try control("restartButton",dead)
  let restarted=try wait("restartfreshboss"){$0["state"] as? String=="playing" && self.boss($0)["id"] as? String != old}
  XCTAssertEqual(restarted["enemies"] as? Int,0);XCTAssertEqual(restarted["lockmarshalDeaths"] as? Int,0);XCTAssertEqual(restarted["lockmarshalFire"] as? Bool,true);try record("native-fresh-restart",restarted)
  tap(Double(game.frame.width)-30,80)
  let paused=try wait("pause-for-title"){$0["state"] as? String=="paused"};try control("pauseMenuButton",paused)
  let confirm=try wait("quit-confirm"){$0["quitConfirmYesX"] != nil};try control("quitConfirmYes",confirm)
  let t=try sample("arena8-title-probe");XCTAssertEqual(t["registeredArenas"] as? Int,7)
  tap(try XCTUnwrap(t["playX"] as? Double),try XCTUnwrap(t["playY"] as? Double))
  let fresh=try wait("TitlePlayfreshboss"){$0["state"] as? String=="playing" && self.boss($0)["id"] != nil}
  XCTAssertNotEqual(boss(fresh)["id"] as? String,boss(restarted)["id"] as? String);XCTAssertEqual(fresh["enemies"] as? Int,0);try record("native-fresh-Title-Play",fresh)
 }
}
