import XCTest
final class TitleRoomControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 func probe(_ id:String)->XCUIElement{game.descendants(matching:.any).matching(identifier:id).firstMatch}
 override func tearDown(){game.terminate();super.tearDown()}
 func sample(_ id:String)throws->[String:Any]{
  let element=probe(id);XCTAssertTrue(element.waitForExistence(timeout:15))
  let text=try XCTUnwrap(element.value as? String),data=try XCTUnwrap(text.data(using:.utf8));return try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
 }
 func title()throws->[String:Any]{
  let s=try sample("arena8-title-probe");XCTAssertEqual(s["isolated"] as? Bool,true);XCTAssertEqual(s["selectedFloor"] as? Int,6);XCTAssertEqual(s["registeredArenas"] as? Int,7);return s
 }
 func gameplay()throws->[String:Any]{
  let s=try sample("arena8-six-probe");XCTAssertEqual(s["safe"] as? Bool,true);XCTAssertEqual(s["entryFromTitle"] as? Bool,true);XCTAssertEqual(s["roomCount"] as? Int,6);XCTAssertEqual(s["bossMode"] as? Bool,false);return s
 }
 func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func play()throws->[String:Any]{let s=try title();tap(CGFloat(try XCTUnwrap(s["playX"] as? Double)),CGFloat(try XCTUnwrap(s["playY"] as? Double)));return try gameplay()}
 func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func testRealTitlePlayMenuTitlePlay()throws {
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-title","--arena8-title-input","--arena8-six-input","--arena8-six-traversal"]
  game.launch();let initial=try title(),titleEpoch=try XCTUnwrap(initial["titleEpoch"] as? String);shot("title-room-00-opt-in-title")
  let first=try play(),runEpoch=try XCTUnwrap(first["entryEpoch"] as? String);XCTAssertEqual(first["level"] as? Int,1);XCTAssertEqual(first["kills"] as? Int,0);shot("title-room-01-play-entered-six-rooms")
  let joy=game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75))
  joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:70,dy:0)),withVelocity:.fast,thenHoldForDuration:0.3)
  XCTAssertGreaterThan(try gameplay()["x"] as? Double ?? -999,first["x"] as? Double ?? 999)
  tap(game.frame.width-30,80);XCTAssertEqual(try gameplay()["state"] as? String,"paused")
  XCUIDevice.shared.press(.home);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15));XCTAssertEqual(try gameplay()["entryEpoch"] as? String,runEpoch);XCTAssertEqual(try gameplay()["state"] as? String,"paused");shot("title-room-02-paused-background-resume")
  tap(game.frame.width/2,game.frame.height/2+232)
  shot("title-room-03-quit-confirmation")
  // Existing measured quit panel: QUIT RUN is59points below scene center.
  tap(game.frame.width/2,game.frame.height/2+59)
  let returned=try title();XCTAssertNotEqual(returned["titleEpoch"] as? String,titleEpoch);shot("title-room-04-returned-to-title")
  let second=try play();XCTAssertNotEqual(second["entryEpoch"] as? String,runEpoch);XCTAssertEqual(second["level"] as? Int,1);XCTAssertEqual(second["xp"] as? Int,0);XCTAssertEqual(second["kills"] as? Int,0);shot("title-room-05-fresh-play-retains-map")
 }
}
