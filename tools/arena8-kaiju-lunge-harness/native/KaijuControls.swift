import XCTest
final class KaijuControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 func probe(_ id:String)->XCUIElement{game.descendants(matching:.any).matching(identifier:id).firstMatch}
 override func tearDown(){game.terminate();super.tearDown()}
 func sample(_ id:String)throws->[String:Any]{let p=probe(id);XCTAssertTrue(p.waitForExistence(timeout:15));let text=try XCTUnwrap(p.value as? String),data=try XCTUnwrap(text.data(using:.utf8));return try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])}
 func title()throws->[String:Any]{let s=try sample("arena8-title-probe");XCTAssertEqual(s["isolated"] as? Bool,true);XCTAssertEqual(s["selectedFloor"] as? Int,6);return s}
 func gameplay()throws->[String:Any]{
  let s=try sample("arena8-six-probe");XCTAssertEqual(s["safe"] as? Bool,true);XCTAssertEqual(s["entryFromTitle"] as? Bool,true);XCTAssertEqual(s["roomCount"] as? Int,6)
  XCTAssertEqual(s["kaijuRootSafe"] as? Bool,true);XCTAssertEqual(s["kaijuUnsafeFrames"] as? Int,0);return s
 }
 func ready()throws->[String:Any]{
  let e=probe("arena8-six-probe");XCTAssertTrue(e.waitForExistence(timeout:15))
  let pred=NSPredicate{obj,_ in guard let element=obj as? XCUIElement,let text=element.value as? String,let data=text.data(using:.utf8),let s=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false};return !(s["kaijuEpoch"] as? String ?? "").isEmpty}
  expectation(for:pred,evaluatedWith:e);waitForExpectations(timeout:15);return try gameplay()
 }
 func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func play()throws->[String:Any]{let s=try title();tap(CGFloat(try XCTUnwrap(s["playX"] as? Double)),CGFloat(try XCTUnwrap(s["playY"] as? Double)));return try ready()}
 func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func testKaijuSweepAndLifecycle()throws{
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-title","--arena8-title-input","--arena8-kaiju-lunge-input","--arena8-six-input","--arena8-six-traversal"]
  game.launch();let initialTitle=try title();shot("kaiju-00-title")
  let first=try play(),epoch=try XCTUnwrap(first["kaijuEpoch"] as? String)
  Thread.sleep(forTimeInterval:0.8);_ = try gameplay();shot("kaiju-01-wall-lunges")
  let before=try gameplay(),joy=game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75))
  joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:45,dy:0)),withVelocity:.fast,thenHoldForDuration:0.5)
  XCTAssertGreaterThan(try gameplay()["x"] as? Double ?? -999,before["x"] as? Double ?? 999)
  joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:-45,dy:0)),withVelocity:.fast,thenHoldForDuration:0.8)
  _ = try gameplay();shot("kaiju-02-native-wall-reversal")
  tap(game.frame.width-30,80);XCTAssertEqual(try gameplay()["state"] as? String,"paused")
  XCUIDevice.shared.press(.home);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15));XCTAssertEqual(try gameplay()["kaijuEpoch"] as? String,epoch);shot("kaiju-03-pause-background")
  tap(game.frame.width/2,game.frame.height/2+232);shot("kaiju-04-quit-confirmation");tap(game.frame.width/2,game.frame.height/2+59)
  let returned=try title();XCTAssertNotEqual(returned["titleEpoch"] as? String,initialTitle["titleEpoch"] as? String)
  let second=try play();XCTAssertNotEqual(second["kaijuEpoch"] as? String,epoch);Thread.sleep(forTimeInterval:0.5);_ = try gameplay();shot("kaiju-05-fresh-entry")
 }
}
