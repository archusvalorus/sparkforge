import XCTest
final class RiftControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 var probe:XCUIElement{game.descendants(matching:.any).matching(identifier:"arena8-six-probe").firstMatch}
 override func tearDown(){game.terminate();super.tearDown()}
 func sample() throws -> [String:Any]{
  let text=try XCTUnwrap(probe.value as? String),data=try XCTUnwrap(text.data(using:.utf8));let v=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
  XCTAssertEqual(v["safe"] as? Bool,true)
  let shot=try XCTUnwrap(v["riftLastShot"] as? [String:Any]);XCTAssertEqual(shot["safe"] as? Bool,true)
  return v
 }
 func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func testRiftRepeatPauseMovementAndLifecycle() throws {
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-rift-input","--arena8-six-input","--arena8-six-traversal"]
  game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15))
  let ready=NSPredicate{element,_ in
   guard let e=element as? XCUIElement,let text=e.value as? String,let data=text.data(using:.utf8),let v=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false}
   return (v["riftShots"] as? Int ?? 0)>0 && !(v["riftEpoch"] as? String ?? "").isEmpty
  }
  expectation(for:ready,evaluatedWith:probe);waitForExpectations(timeout:15)
  let initial=try sample(),epoch=try XCTUnwrap(initial["riftEpoch"] as? String);shot("rift-00-outer-room")
  tap(game.frame.width-30,80);let held=try sample();XCTAssertEqual(held["state"] as? String,"paused")
  Thread.sleep(forTimeInterval:1.2);let still=try sample();XCTAssertEqual(still["riftShots"] as? Int,held["riftShots"] as? Int)
  XCTAssertTrue(NSDictionary(dictionary:try XCTUnwrap(held["riftLastShot"] as? [String:Any])).isEqual(to:try XCTUnwrap(still["riftLastShot"] as? [String:Any])));shot("rift-01-paused")
  tap(game.frame.width/2,game.frame.height/2+124);let before=try sample();XCTAssertEqual(before["state"] as? String,"playing")
  let joy=game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75))
  joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:70,dy:0)),withVelocity:.fast,thenHoldForDuration:0.3)
  XCTAssertGreaterThan(try sample()["x"] as? Double ?? -999,before["x"] as? Double ?? 999);shot("rift-02-movement")
  let advance=NSPredicate{element,_ in
   guard let e=element as? XCUIElement,let text=e.value as? String,let data=text.data(using:.utf8),let v=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false}
   return (v["riftShots"] as? Int ?? 0)>(held["riftShots"] as? Int ?? 0)
  }
  expectation(for:advance,evaluatedWith:probe);waitForExpectations(timeout:15);_=try sample()
  XCUIDevice.shared.press(.home);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15));XCTAssertEqual(try sample()["riftEpoch"] as? String,epoch);shot("rift-03-background-resume")
  game.terminate();game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15));expectation(for:ready,evaluatedWith:probe);waitForExpectations(timeout:15)
  let fresh=try sample();XCTAssertNotEqual(try XCTUnwrap(fresh["riftEpoch"] as? String),epoch);shot("rift-04-fresh-run")
 }
}
