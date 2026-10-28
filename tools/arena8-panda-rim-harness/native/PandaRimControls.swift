import XCTest
final class PandaRimControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 var probe:XCUIElement{game.descendants(matching:.any).matching(identifier:"arena8-six-probe").firstMatch}
 override func tearDown(){game.terminate();super.tearDown()}
 func sample() throws -> [String:Any]{
  let text=try XCTUnwrap(probe.value as? String),data=try XCTUnwrap(text.data(using:.utf8));let v=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
  XCTAssertEqual(v["safe"] as? Bool,true)
  let visitors=try XCTUnwrap(v["pandaDestVisitors"] as? [[String:Any]])
  XCTAssertFalse(visitors.isEmpty);XCTAssertTrue(visitors.allSatisfy{($0["destinationSafe"] as? Bool)==true})
  let rim=try XCTUnwrap(v["pandaRimLastSpawn"] as? [String:Any]),world=try XCTUnwrap(v["pandaRimWorld"] as? [String:Any])
  let x=try XCTUnwrap(rim["x"] as? Double)-(try XCTUnwrap(world["x"] as? Double)), y=try XCTUnwrap(rim["y"] as? Double)-(try XCTUnwrap(world["y"] as? Double))
  let halfX=try XCTUnwrap(world["halfX"] as? Double), halfY=try XCTUnwrap(world["halfY"] as? Double)
  XCTAssertTrue(abs(abs(x)-halfX)<0.001 || abs(abs(y)-halfY)<0.001)
  // Resting-body clearance is intentionally NOT inferred from destination safety.
  return v
 }
 func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func testDestinationPauseMovementAndLifecycle() throws {
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-panda-destination-input","--arena8-six-input","--arena8-six-traversal"]
  game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15))
  let ready=NSPredicate{element,_ in
   guard let e=element as? XCUIElement,let text=e.value as? String,let data=text.data(using:.utf8),let v=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false}
   return (v["pandaDestVisitors"] as? [[String:Any]])?.isEmpty==false && !(v["pandaDestEpoch"] as? String ?? "").isEmpty
  }
  expectation(for:ready,evaluatedWith:probe);waitForExpectations(timeout:15)
  let initial=try sample(),epoch=try XCTUnwrap(initial["pandaDestEpoch"] as? String);shot("panda-rim-00-approach")
  tap(game.frame.width-30,80);let held=try sample();XCTAssertEqual(held["state"] as? String,"paused")
  Thread.sleep(forTimeInterval:1.2);let still=try sample()
  XCTAssertTrue(NSArray(array:try XCTUnwrap(held["pandaDestVisitors"] as? [[String:Any]])).isEqual(to:try XCTUnwrap(still["pandaDestVisitors"] as? [[String:Any]])));shot("panda-rim-01-paused")
  tap(game.frame.width/2,game.frame.height/2+124);let before=try sample();XCTAssertEqual(before["state"] as? String,"playing")
  let joy=game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75))
  joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:70,dy:0)),withVelocity:.fast,thenHoldForDuration:0.3)
  XCTAssertGreaterThan(try sample()["x"] as? Double ?? -999,before["x"] as? Double ?? 999)
  let arrived=NSPredicate{element,_ in
   guard let e=element as? XCUIElement,let text=e.value as? String,let data=text.data(using:.utf8),let v=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let visitors=v["pandaDestVisitors"] as? [[String:Any]] else{return false}
   return visitors.contains{($0["phase"] as? String)=="acting"}
  }
  expectation(for:arrived,evaluatedWith:probe);waitForExpectations(timeout:40);let settled=try sample();XCTAssertEqual(settled["pandaRimHandoffs"] as? Int,1);XCTAssertTrue((settled["pandaDestVisitors"] as? [[String:Any]])?.allSatisfy{($0["rootSafe"] as? Bool)==true} == true);shot("panda-rim-02-arrived")
  XCUIDevice.shared.press(.home);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15));XCTAssertEqual(try sample()["pandaDestEpoch"] as? String,epoch);shot("panda-rim-03-background-resume")
  game.terminate();game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15));expectation(for:ready,evaluatedWith:probe);waitForExpectations(timeout:15)
  let fresh=try sample();XCTAssertNotEqual(try XCTUnwrap(fresh["pandaDestEpoch"] as? String),epoch);shot("panda-rim-04-fresh-run")
 }
}
