import XCTest
final class AvalancheControls:XCTestCase {
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
  let pred=NSPredicate{obj,_ in guard let element=obj as? XCUIElement,let text=element.value as? String,let data=text.data(using:.utf8),let s=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false};return !(s["avalancheEpoch"] as? String ?? "").isEmpty}
  expectation(for:pred,evaluatedWith:e);waitForExpectations(timeout:15);return try gameplay()
 }
 func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func play()throws->[String:Any]{let s=try title();tap(CGFloat(try XCTUnwrap(s["playX"] as? Double)),CGFloat(try XCTUnwrap(s["playY"] as? Double)));return try ready()}
 func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func armAndCheck()throws->[String:Any]{
  let s=try gameplay();tap(CGFloat(try XCTUnwrap(s["armX"] as? Double)),CGFloat(try XCTUnwrap(s["armY"] as? Double)))
  let held=try gameplay();XCTAssertEqual(held["state"] as? String,"paused")
  XCTAssertEqual(held["avalancheWaiting"] as? Bool,true);XCTAssertEqual(held["avalancheAlpha"] as? Double,0)
  XCTAssertEqual(held["avalancheTravel"] as? Double,0);return held
 }
 func testAvalancheAndTerminalLifecycle()throws{
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-title","--arena8-title-input","--arena8-avalanche-input","--arena8-six-input","--arena8-six-traversal","--arena8-pressure-kiting"]
  game.launch();let initialTitle=try title();shot("avalanche-00-title")
  let first=try play(),epoch=try XCTUnwrap(first["avalancheEpoch"] as? String)
  let held=try armAndCheck(),hp=try XCTUnwrap(held["avalancheTargetHP"] as? Int);XCTAssertGreaterThan(hp,0)
  Thread.sleep(forTimeInterval:0.7);let still=try gameplay();XCTAssertEqual(still["avalancheTargetHP"] as? Int,hp);XCTAssertEqual(still["avalancheAlpha"] as? Double,0);XCTAssertEqual(still["avalancheTravel"] as? Double,0);shot("avalanche-01-held-windup")
  XCUIDevice.shared.press(.home);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15));let foreground=try gameplay();XCTAssertEqual(foreground["state"] as? String,"paused");XCTAssertEqual(foreground["avalancheTargetHP"] as? Int,hp);XCTAssertEqual(foreground["avalancheEpoch"] as? String,epoch);shot("avalanche-02-background-held")
  tap(game.frame.width/2,game.frame.height/2+124);Thread.sleep(forTimeInterval:1.5)
  let hit=try gameplay();let payload=try JSONSerialization.data(withJSONObject:hit,options:[.sortedKeys]);let snapshot=XCTAttachment(string:String(data:payload,encoding:.utf8)!);snapshot.name="post-resume-probe";snapshot.lifetime = .keepAlways;add(snapshot);XCTAssertEqual(hit["avalancheEpoch"] as? String,epoch);XCTAssertGreaterThanOrEqual(try XCTUnwrap(hit["avalancheTargetHP"] as? Int),0);XCTAssertLessThan(try XCTUnwrap(hit["avalancheTargetHP"] as? Int),hp);XCTAssertEqual(hit["avalancheWaiting"] as? Bool,false);XCTAssertEqual(hit["avalancheEntries"] as? Int,0);shot("avalanche-03-resumed-impact");let afterHP=hit["avalancheTargetHP"] as? Int;Thread.sleep(forTimeInterval:0.6);XCTAssertEqual(try gameplay()["avalancheTargetHP"] as? Int,afterHP)
  tap(game.frame.width-30,80);XCTAssertEqual(try gameplay()["state"] as? String,"paused")
  tap(game.frame.width/2,game.frame.height/2+232);shot("avalanche-04-quit-confirmation");tap(game.frame.width/2,game.frame.height/2+59)
  let returned=try title();XCTAssertNotEqual(returned["titleEpoch"] as? String,initialTitle["titleEpoch"] as? String)
  let second=try play();XCTAssertNotEqual(second["avalancheEpoch"] as? String,epoch)
  _ = try armAndCheck();Thread.sleep(forTimeInterval:0.6);XCTAssertEqual(try gameplay()["avalancheWaiting"] as? Bool,true);XCTAssertEqual(try gameplay()["avalancheAlpha"] as? Double,0);shot("avalanche-05-fresh-held-entry")
 }
}
