import XCTest
final class SentryControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 var probe:XCUIElement{game.descendants(matching:.any).matching(identifier:"arena8-six-probe").firstMatch}
 override func tearDown(){game.terminate();super.tearDown()}
 func sample() throws -> [String:Any]{
  let text=try XCTUnwrap(probe.value as? String);let data=try XCTUnwrap(text.data(using:.utf8));let v=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
  XCTAssertEqual(v["safe"] as? Bool,true)
  let wells=try XCTUnwrap(v["sentryCoils"] as? [[String:Any]])
  XCTAssertTrue(wells.allSatisfy{($0["safe"] as? Bool)==true});return v
 }
 func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func testCoilPlacementPauseMovementAndLifecycle() throws {
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-sentry-input","--arena8-six-input","--arena8-six-traversal"]
  game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15))
  let ready=NSPredicate { element,_ in
   guard let e=element as? XCUIElement,let text=e.value as? String,let data=text.data(using:.utf8),let v=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false}
   return (v["sentryCoils"] as? [[String:Any]])?.count==3 && !(v["sentryEpoch"] as? String ?? "").isEmpty
  }
  expectation(for:ready,evaluatedWith:probe);waitForExpectations(timeout:15)
  let initial=try sample();let epoch=try XCTUnwrap(initial["sentryEpoch"] as? String);XCTAssertFalse(epoch.isEmpty)
  XCTAssertEqual((initial["sentryCoils"] as? [[String:Any]])?.count,3);shot("sentry-00-outer-room-coils")
  tap(game.frame.width-30,80)
  let held=try sample();XCTAssertEqual(held["state"] as? String,"paused")
  let wells=try XCTUnwrap(held["sentryCoils"] as? [[String:Any]]);XCTAssertFalse(wells.isEmpty,"Pause must retain a live coil")
  Thread.sleep(forTimeInterval:1.2);let still=try sample()
  XCTAssertTrue(NSArray(array:wells).isEqual(to:still["sentryCoils"] as? [[String:Any]] ?? []));shot("sentry-01-paused-live-coils")
  tap(game.frame.width/2,game.frame.height/2+124);let before=try sample();XCTAssertEqual(before["state"] as? String,"playing")
  let joy=game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75))
  joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:70,dy:0)),withVelocity:.fast,thenHoldForDuration:0.3)
  XCTAssertGreaterThan(try sample()["x"] as? Double ?? -999,before["x"] as? Double ?? 999);shot("sentry-02-movement")
  XCUIDevice.shared.press(.home);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15))
  XCTAssertEqual(try sample()["sentryEpoch"] as? String,epoch);shot("sentry-03-background-resume")
  game.terminate();game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15))
  let fresh=try sample();let newEpoch=try XCTUnwrap(fresh["sentryEpoch"] as? String);XCTAssertFalse(newEpoch.isEmpty);XCTAssertNotEqual(newEpoch,epoch)
  XCTAssertEqual((fresh["sentryCoils"] as? [[String:Any]])?.count,3);shot("sentry-04-fresh-run")
 }
}
