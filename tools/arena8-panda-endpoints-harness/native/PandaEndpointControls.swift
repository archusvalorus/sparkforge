import XCTest
final class PandaEndpointControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 var probe:XCUIElement {game.descendants(matching:.any).matching(identifier:"arena8-six-probe").firstMatch}
 override func tearDown(){game.terminate();super.tearDown()}
 func sample() throws -> [String:Any] {
  let text=try XCTUnwrap(probe.value as? String);let data=try XCTUnwrap(text.data(using:.utf8))
  let value=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
  XCTAssertEqual(value["safe"] as? Bool,true)
  let actors=try XCTUnwrap(value["pandaActors"] as? [[String:Any]])
  XCTAssertEqual(actors.count,1);XCTAssertTrue(actors.allSatisfy{($0["safe"] as? Bool)==true})
  return value
 }
 func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func testPandaEndpointPauseMovementAndLifecycle() throws {
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-panda-endpoints-input","--arena8-six-input","--arena8-six-traversal"]
  game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15))
  let corrections=NSPredicate { element,_ in
   guard let e=element as? XCUIElement,let text=e.value as? String,let data=text.data(using:.utf8),let v=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false}
   return (v["pandaCorrections"] as? Int ?? 0)>3
  }
  expectation(for:corrections,evaluatedWith:probe);waitForExpectations(timeout:15)
  let initial=try sample();let epoch=try XCTUnwrap(initial["pandaEndpointEpoch"] as? String);XCTAssertFalse(epoch.isEmpty)
  XCTAssertEqual(initial["pandaCount"] as? Int,1);shot("panda-00-repeated-aggro-safe")
  tap(game.frame.width-30,80)
  let held=try sample();XCTAssertEqual(held["state"] as? String,"paused")
  Thread.sleep(forTimeInterval:1.2)
  let still=try sample();XCTAssertEqual(still["pandaCorrections"] as? Int,held["pandaCorrections"] as? Int)
  XCTAssertTrue(NSArray(array:held["pandaActors"] as? [[String:Any]] ?? []).isEqual(to:still["pandaActors"] as? [[String:Any]] ?? []));shot("panda-01-paused")
  tap(game.frame.width/2,game.frame.height/2+124)
  let before=try sample();XCTAssertEqual(before["state"] as? String,"playing")
  let joy=game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75))
  joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:70,dy:0)),withVelocity:.fast,thenHoldForDuration:0.3)
  XCTAssertGreaterThan(try sample()["x"] as? Double ?? -999,before["x"] as? Double ?? 999);shot("panda-02-movement")
  XCUIDevice.shared.press(.home);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15))
  XCTAssertEqual(try sample()["pandaEndpointEpoch"] as? String,epoch)
  game.terminate();game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15))
  let fresh=try sample();let freshEpoch=try XCTUnwrap(fresh["pandaEndpointEpoch"] as? String)
  XCTAssertFalse(freshEpoch.isEmpty);XCTAssertNotEqual(freshEpoch,epoch);shot("panda-03-fresh-run")
 }
}
