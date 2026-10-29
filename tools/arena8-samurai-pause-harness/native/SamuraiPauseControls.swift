import XCTest
final class SamuraiPauseControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 func probe(_ id:String)->XCUIElement{game.descendants(matching:.any).matching(identifier:id).firstMatch}
 override func tearDown(){game.terminate();super.tearDown()}
 func sample(_ id:String)throws->[String:Any]{let p=probe(id);XCTAssertTrue(p.waitForExistence(timeout:15));let text=try XCTUnwrap(p.value as? String),data=try XCTUnwrap(text.data(using:.utf8));return try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])}
 func title()throws->[String:Any]{let s=try sample("arena8-title-probe");XCTAssertEqual(s["isolated"] as? Bool,true);XCTAssertEqual(s["selectedFloor"] as? Int,6);return s}
 func gameplay()throws->[String:Any]{
  let s=try sample("arena8-six-probe");XCTAssertEqual(s["safe"] as? Bool,true);XCTAssertEqual(s["entryFromTitle"] as? Bool,true);XCTAssertEqual(s["roomCount"] as? Int,6)
return s
 }
 func ready()throws->[String:Any]{
  let e=probe("arena8-six-probe");XCTAssertTrue(e.waitForExistence(timeout:15))
  let pred=NSPredicate{obj,_ in guard let element=obj as? XCUIElement,let text=element.value as? String,let data=text.data(using:.utf8),let s=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false};return !(s["pauseEpoch"] as? String ?? "").isEmpty}
  expectation(for:pred,evaluatedWith:e);waitForExpectations(timeout:15);return try gameplay()
 }
 func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func play()throws->[String:Any]{let s=try title();tap(CGFloat(try XCTUnwrap(s["playX"] as? Double)),CGFloat(try XCTUnwrap(s["playY"] as? Double)));return try ready()}
 func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func armAndCheck()throws->[String:Any]{
  let s=try gameplay();tap(CGFloat(try XCTUnwrap(s["armX"] as? Double)),CGFloat(try XCTUnwrap(s["armY"] as? Double)))
  let paused=try gameplay();XCTAssertEqual(paused["state"] as? String,"paused")
  let strike=try XCTUnwrap(paused["pauseStrike"] as? [String:Any]);XCTAssertEqual(strike["pending"] as? Bool,true);XCTAssertEqual(strike["paused"] as? Bool,true);XCTAssertEqual(paused["pauseTargetDead"] as? Bool,false)
  return paused
 }
 func testSamuraiPauseAndTerminalLifecycle()throws{
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-title","--arena8-title-input","--arena8-samurai-pause-input","--arena8-six-input","--arena8-six-traversal","--arena8-pressure-kiting"]
  game.launch();let initialTitle=try title();shot("samurai-pause-00-title")
  let first=try play(),epoch=try XCTUnwrap(first["pauseEpoch"] as? String)
  let held=try armAndCheck(),hp=try XCTUnwrap(held["pauseTargetHP"] as? Int),visual=try XCTUnwrap(held["pauseStrike"] as? NSDictionary)
  Thread.sleep(forTimeInterval:0.7);let still=try gameplay();XCTAssertEqual(still["pauseTargetHP"] as? Int,hp);XCTAssertEqual(still["pauseStrike"] as? NSDictionary,visual);shot("samurai-pause-01-held-windup")
  XCUIDevice.shared.press(.home);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15));let foreground=try gameplay();XCTAssertEqual(foreground["state"] as? String,"paused");XCTAssertEqual(foreground["pauseTargetHP"] as? Int,hp);XCTAssertEqual(foreground["pauseEpoch"] as? String,epoch);shot("samurai-pause-02-background-held")
  tap(game.frame.width/2,game.frame.height/2+124);Thread.sleep(forTimeInterval:0.7)
  let hit=try gameplay();XCTAssertEqual(hit["pauseTargetDead"] as? Bool,true);XCTAssertEqual((hit["pauseStrike"] as? [String:Any])?["pending"] as? Bool,false);shot("samurai-pause-03-resumed-impact")
  tap(game.frame.width-30,80);XCTAssertEqual(try gameplay()["state"] as? String,"paused")
  tap(game.frame.width/2,game.frame.height/2+232);shot("samurai-pause-04-quit-confirmation");tap(game.frame.width/2,game.frame.height/2+59)
  let returned=try title();XCTAssertNotEqual(returned["titleEpoch"] as? String,initialTitle["titleEpoch"] as? String)
  let second=try play();XCTAssertNotEqual(second["pauseEpoch"] as? String,epoch)
  _ = try armAndCheck();Thread.sleep(forTimeInterval:0.6);XCTAssertEqual(try gameplay()["pauseTargetDead"] as? Bool,false);shot("samurai-pause-05-fresh-held-entry")
 }
}
