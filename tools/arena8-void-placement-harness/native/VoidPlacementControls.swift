import XCTest
final class VoidPlacementControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 var probe:XCUIElement{game.descendants(matching:.any).matching(identifier:"arena8-six-probe").firstMatch}
 override func tearDown(){game.terminate();super.tearDown()}
 func sample() throws -> [String:Any]{
  let text=try XCTUnwrap(probe.value as? String);let data=try XCTUnwrap(text.data(using:.utf8));let v=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
  XCTAssertEqual(v["safe"] as? Bool,true)
  let wells=try XCTUnwrap(v["voidWells"] as? [[String:Any]])
  XCTAssertTrue(wells.allSatisfy{($0["safe"] as? Bool)==true});return v
 }
 func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func testWellPlacementPauseMovementAndLifecycle() throws {
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-void-placement-input","--arena8-six-input","--arena8-six-traversal"]
  game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15))
  let live=NSPredicate{element,_ in
   guard let e=element as? XCUIElement,let text=e.value as? String,let data=text.data(using:.utf8),let v=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let wells=v["voidWells"] as? [[String:Any]] else{return false}
   return wells.contains{($0["life"] as? Double ?? 0)>2.5}
  }
  expectation(for:live,evaluatedWith:probe);waitForExpectations(timeout:15)
  let initial=try sample();let epoch=try XCTUnwrap(initial["voidEpoch"] as? String);XCTAssertFalse(epoch.isEmpty)
  XCTAssertGreaterThanOrEqual(initial["voidBirths"] as? Int ?? 0,1);shot("void-00-outer-room-well")
  tap(game.frame.width-30,80)
  let held=try sample();XCTAssertEqual(held["state"] as? String,"paused")
  let wells=try XCTUnwrap(held["voidWells"] as? [[String:Any]]);XCTAssertFalse(wells.isEmpty,"Pause must retain a live well")
  Thread.sleep(forTimeInterval:1.2);let still=try sample()
  XCTAssertEqual(still["voidBirths"] as? Int,held["voidBirths"] as? Int)
  XCTAssertTrue(NSArray(array:wells).isEqual(to:still["voidWells"] as? [[String:Any]] ?? []));shot("void-01-paused-live-well")
  tap(game.frame.width/2,game.frame.height/2+124);let before=try sample();XCTAssertEqual(before["state"] as? String,"playing")
  let joy=game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75))
  joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:70,dy:0)),withVelocity:.fast,thenHoldForDuration:0.3)
  XCTAssertGreaterThan(try sample()["x"] as? Double ?? -999,before["x"] as? Double ?? 999);shot("void-02-movement")
  let advances=NSPredicate{element,_ in
   guard let e=element as? XCUIElement,let text=e.value as? String,let data=text.data(using:.utf8),let v=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false}
   return (v["voidBirths"] as? Int ?? 0)>=3
  }
  expectation(for:advances,evaluatedWith:probe);waitForExpectations(timeout:15);_=try sample()
  XCUIDevice.shared.press(.home);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15))
  XCTAssertEqual(try sample()["voidEpoch"] as? String,epoch);shot("void-03-background-resume")
  game.terminate();game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15))
  let fresh=try sample();let newEpoch=try XCTUnwrap(fresh["voidEpoch"] as? String);XCTAssertFalse(newEpoch.isEmpty);XCTAssertNotEqual(newEpoch,epoch)
  XCTAssertGreaterThanOrEqual(fresh["voidBirths"] as? Int ?? 0,1);shot("void-04-fresh-run")
 }
}
