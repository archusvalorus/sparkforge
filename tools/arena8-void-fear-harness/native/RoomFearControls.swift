import XCTest
final class RoomFearControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 func probe(_ id:String)->XCUIElement{game.descendants(matching:.any).matching(identifier:id).firstMatch}
 override func tearDown(){game.terminate();super.tearDown()}
 func sample(_ id:String)throws->[String:Any]{let p=probe(id);XCTAssertTrue(p.waitForExistence(timeout:15));let text=try XCTUnwrap(p.value as? String),data=try XCTUnwrap(text.data(using:.utf8));return try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])}
 func title()throws->[String:Any]{let s=try sample("arena8-title-probe");XCTAssertEqual(s["isolated"] as? Bool,true);XCTAssertEqual(s["selectedFloor"] as? Int,6);return s}
 func gameplay()throws->[String:Any]{
  let s=try sample("arena8-six-probe");XCTAssertEqual(s["safe"] as? Bool,true);XCTAssertEqual(s["entryFromTitle"] as? Bool,true);XCTAssertEqual(s["roomCount"] as? Int,6);XCTAssertEqual(s["fearSafe"] as? Bool,true)
  let actors=try XCTUnwrap(s["fearActors"] as? [[String:Any]]);XCTAssertEqual(actors.count,2);XCTAssertTrue(actors.allSatisfy{($0["safe"] as? Bool)==true});XCTAssertTrue(actors.contains{($0["ranged"] as? Bool)==true});return s
 }

 func ready()throws->[String:Any]{
  let e=probe("arena8-six-probe");XCTAssertTrue(e.waitForExistence(timeout:15))
  let pred=NSPredicate{obj,_ in guard let element=obj as? XCUIElement,let text=element.value as? String,let data=text.data(using:.utf8),let s=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return false};return !(s["fearEpoch"] as? String ?? "").isEmpty}
  expectation(for:pred,evaluatedWith:e);waitForExpectations(timeout:15);return try gameplay()
 }
 func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
 func play()throws->[String:Any]{let s=try title();tap(CGFloat(try XCTUnwrap(s["playX"] as? Double)),CGFloat(try XCTUnwrap(s["playY"] as? Double)));return try ready()}
 func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func testFearMovementAndLifecycle()throws{
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-title","--arena8-title-input","--arena8-void-fear-input","--arena8-six-input","--arena8-six-traversal"]
  game.launch();let initialTitle=try title();shot("room-fear-00-title")
  let first=try play(),epoch=try XCTUnwrap(first["fearEpoch"] as? String),initialSteps=first["fearSteps"] as? Int ?? 0
  Thread.sleep(forTimeInterval:0.5);let flying=try gameplay();XCTAssertGreaterThan(flying["fearSteps"] as? Int ?? 0,initialSteps)
  let initialActors=try XCTUnwrap(first["fearActors"] as? [[String:Any]]),laterActors=try XCTUnwrap(flying["fearActors"] as? [[String:Any]])
  for old in initialActors {
   let next=try XCTUnwrap(laterActors.first{($0["ranged"] as? Bool)==(old["ranged"] as? Bool)})
   let dx=try XCTUnwrap(next["x"] as? Double)-XCTUnwrap(old["x"] as? Double),dy=try XCTUnwrap(next["y"] as? Double)-XCTUnwrap(old["y"] as? Double)
   XCTAssertGreaterThan(hypot(dx,dy),0.1)
  }
  shot("room-fear-01-actual-basic-ranged")
  let before=try gameplay(),joy=game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75))
  joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:40,dy:0)),withVelocity:.fast,thenHoldForDuration:0.25)
  XCTAssertGreaterThan(try gameplay()["x"] as? Double ?? -999,before["x"] as? Double ?? 999);shot("room-fear-02-native-movement")
  tap(game.frame.width-30,80);let paused=try gameplay();XCTAssertEqual(paused["state"] as? String,"paused")
  Thread.sleep(forTimeInterval:0.3);XCTAssertEqual(try gameplay()["fearSteps"] as? Int,paused["fearSteps"] as? Int)
  XCUIDevice.shared.press(.home);game.activate();XCTAssertTrue(game.wait(for:.runningForeground,timeout:15));let resumed=try gameplay();XCTAssertEqual(resumed["fearEpoch"] as? String,epoch);XCTAssertEqual(resumed["fearSteps"] as? Int,paused["fearSteps"] as? Int);shot("room-fear-03-pause-background")
  tap(game.frame.width/2,game.frame.height/2+232);shot("room-fear-04-quit-confirmation");tap(game.frame.width/2,game.frame.height/2+59)
  let returned=try title();XCTAssertNotEqual(returned["titleEpoch"] as? String,initialTitle["titleEpoch"] as? String)
  let second=try play();XCTAssertNotEqual(second["fearEpoch"] as? String,epoch);shot("room-fear-05-fresh-entry")
 }
}
