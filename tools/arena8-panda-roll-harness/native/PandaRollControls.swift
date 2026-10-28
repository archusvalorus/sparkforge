import XCTest
final class PandaRollControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 var probe:XCUIElement{game.descendants(matching:.any).matching(identifier:"arena8-six-probe").firstMatch}
 override func tearDown(){game.terminate();super.tearDown()}
 func sample() throws -> [String:Any]{
  let text=try XCTUnwrap(probe.value as? String),data=try XCTUnwrap(text.data(using:.utf8));let v=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
  XCTAssertEqual(v["safe"] as? Bool,true)
  let visitors=try XCTUnwrap(v["pandaRollVisitors"] as? [[String:Any]]);XCTAssertEqual(visitors.count,1)
  if (v["pandaRollRests"] as? Int ?? 0)>0 {
   XCTAssertTrue(visitors.allSatisfy{($0["rootSafe"] as? Bool)==true && ($0["phase"] as? String)=="lingering"})
  }
  return v
 }
 func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func testRollPauseMovementAndLifecycle() throws {
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-panda-roll-input","--arena8-six-input","--arena8-six-traversal"]
  game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15))
  let ready=NSPredicate{element,_ in
   guard let e=element as? XCUIElement,let text=e.value as? String,let data=text.data(using:.utf8),let v=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false}
   return (v["state"] as? String)=="paused" && !(v["pandaRollEpoch"] as? String ?? "").isEmpty
  }
  expectation(for:ready,evaluatedWith:probe);waitForExpectations(timeout:15)
  let initial=try sample(),epoch=try XCTUnwrap(initial["pandaRollEpoch"] as? String);XCTAssertEqual(initial["pandaRollRests"] as? Int,0);shot("panda-roll-00-ready-paused")
  Thread.sleep(forTimeInterval:1.2);let held=try sample()
  XCTAssertTrue(NSArray(array:try XCTUnwrap(initial["pandaRollVisitors"] as? [[String:Any]])).isEqual(to:try XCTUnwrap(held["pandaRollVisitors"] as? [[String:Any]])))
  tap(game.frame.width/2,game.frame.height/2+124)
  let rested=NSPredicate{element,_ in
   guard let e=element as? XCUIElement,let text=e.value as? String,let data=text.data(using:.utf8),let v=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false}
   return (v["pandaRollRests"] as? Int)==1
  }
  expectation(for:rested,evaluatedWith:probe);waitForExpectations(timeout:15);let settled=try sample();shot("panda-roll-01-safe-retirement")
  let last=try XCTUnwrap(settled["pandaRollLastRest"] as? [String:Any]);XCTAssertGreaterThan(last["travelled"] as? Double ?? 0,0);XCTAssertEqual(last["done"] as? Bool,true)
  tap(game.frame.width-30,80);XCTAssertEqual(try sample()["state"] as? String,"paused");shot("panda-roll-02-paused-after-retirement")
  tap(game.frame.width/2,game.frame.height/2+124);let before=try sample()
  let joy=game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75))
  joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:70,dy:0)),withVelocity:.fast,thenHoldForDuration:0.3)
  XCTAssertGreaterThan(try sample()["x"] as? Double ?? -999,before["x"] as? Double ?? 999)
  XCUIDevice.shared.press(.home);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15));XCTAssertEqual(try sample()["pandaRollEpoch"] as? String,epoch);XCTAssertEqual(try sample()["pandaRollRests"] as? Int,1);shot("panda-roll-03-background-resume")
  game.terminate();game.launch();XCTAssertTrue(probe.waitForExistence(timeout:15));expectation(for:ready,evaluatedWith:probe);waitForExpectations(timeout:15)
  let fresh=try sample();XCTAssertNotEqual(try XCTUnwrap(fresh["pandaRollEpoch"] as? String),epoch);XCTAssertEqual(fresh["pandaRollRests"] as? Int,0);shot("panda-roll-04-fresh-run")
 }
}
