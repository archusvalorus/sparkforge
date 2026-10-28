import XCTest
final class PandaPickupControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 var probe:XCUIElement{game.descendants(matching:.any).matching(identifier:"arena8-six-probe").firstMatch}
 override func tearDown(){game.terminate();super.tearDown()}
 func sample() throws -> [String:Any]{
  let text=try XCTUnwrap(probe.value as? String),data=try XCTUnwrap(text.data(using:.utf8));let v=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
  XCTAssertEqual(v["safe"] as? Bool,true)
  for orb in try XCTUnwrap(v["pandaPickupOrbs"] as? [[String:Any]]) {XCTAssertEqual(orb["safe"] as? Bool,true)}
  return v
 }
 func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func testPickupRainMovementPauseAndLifecycle() throws {
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-panda-pickup-input","--arena8-six-input","--arena8-six-traversal"]
  game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15))
  let ready=NSPredicate{element,_ in
   guard let e=element as? XCUIElement,let text=e.value as? String,let data=text.data(using:.utf8),let v=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false}
   return (v["state"] as? String)=="paused" && !(v["pandaPickupEpoch"] as? String ?? "").isEmpty
  }
  expectation(for:ready,evaluatedWith:probe);waitForExpectations(timeout:15)
  let initial=try sample(),epoch=try XCTUnwrap(initial["pandaPickupEpoch"] as? String);shot("panda-pickup-00-real-rain-menu")
  let landed=NSPredicate{element,_ in
   guard let e=element as? XCUIElement,let text=e.value as? String,let data=text.data(using:.utf8),let v=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false}
   return (v["pandaPickupOrbs"] as? [[String:Any]])?.count==1
  }
  expectation(for:landed,evaluatedWith:probe);waitForExpectations(timeout:10)
  let after=try sample();XCTAssertEqual(after["state"] as? String,"paused")
  let orb=try XCTUnwrap((after["pandaPickupOrbs"] as? [[String:Any]])?.first),target=try XCTUnwrap(after["pandaPickupTarget"] as? [String:Any])
  XCTAssertLessThan(abs((orb["x"] as? Double ?? -999)-(target["x"] as? Double ?? 999)),0.001);XCTAssertLessThanOrEqual(abs((orb["y"] as? Double ?? -999)-(target["y"] as? Double ?? 999)),4.01);shot("panda-pickup-01-landed-on-safe-floor")
  tap(game.frame.width/2,game.frame.height/2+124);let before=try sample()
  let joy=game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75))
  joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:70,dy:0)),withVelocity:.fast,thenHoldForDuration:1.1)
  let collected=try sample()
  XCTAssertGreaterThan(collected["x"] as? Double ?? -999,before["x"] as? Double ?? 999)
  XCTAssertEqual((collected["pandaPickupOrbs"] as? [[String:Any]])?.count,0)
  XCTAssertEqual(collected["hp"] as? Int,(before["hp"] as? Int ?? -999)+20)
  tap(game.frame.width-30,80);XCTAssertEqual(try sample()["state"] as? String,"paused");shot("panda-pickup-02-menu-after-kiting")
  XCUIDevice.shared.press(.home);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15));XCTAssertEqual(try sample()["pandaPickupEpoch"] as? String,epoch);shot("panda-pickup-03-background-resume")
  game.terminate();game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15));expectation(for:ready,evaluatedWith:probe);waitForExpectations(timeout:15)
  XCTAssertNotEqual(try XCTUnwrap(try sample()["pandaPickupEpoch"] as? String),epoch);shot("panda-pickup-04-fresh-run")
 }
}
