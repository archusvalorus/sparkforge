import XCTest
final class MagnetControls:XCTestCase {
 let game=XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
 func probe(_ id:String)->XCUIElement{game.descendants(matching:.any).matching(identifier:id).firstMatch}
 func sample(_ id:String)throws->[String:Any]{let p=probe(id);XCTAssertTrue(p.waitForExistence(timeout:30));let t=try XCTUnwrap(p.value as? String),d=try XCTUnwrap(t.data(using:.utf8));return try XCTUnwrap(JSONSerialization.jsonObject(with:d) as? [String:Any])}
 override func tearDown(){game.terminate();super.tearDown()}
 func testRealTitlePlayMagnet()throws{
  continueAfterFailure=false
  game.launchArguments=["--arena8-six","--arena8-title","--arena8-title-input","--arena8-six-input","--arena8-magnet-checks","--arena8-six-traversal","--arena8-pressure-kiting"]
  game.launch()
  let title=try sample("arena8-title-probe");XCTAssertEqual(title["isolated"] as? Bool,true)
  game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:try XCTUnwrap(title["playX"] as? Double),dy:try XCTUnwrap(title["playY"] as? Double))).tap()
  let p=probe("arena8-six-probe");XCTAssertTrue(p.waitForExistence(timeout:30))
  let ready=NSPredicate{obj,_ in guard let e=obj as? XCUIElement,let t=e.value as? String,let d=t.data(using:.utf8),let s=(try? JSONSerialization.jsonObject(with:d)) as? [String:Any] else{return false};return s["magnetDone"] as? Bool == true}
  expectation(for:ready,evaluatedWith:p);waitForExpectations(timeout:30)
  let s=try sample("arena8-six-probe");XCTAssertEqual(s["entryFromTitle"] as? Bool,true);XCTAssertEqual(s["roomCount"] as? Int,6);XCTAssertEqual(s["magnetFailed"] as? Int,0);XCTAssertGreaterThan(try XCTUnwrap(s["magnetPassed"] as? Int),100)
  let a=XCTAttachment(screenshot:game.screenshot());a.name="magnet-real-title-play-report";a.lifetime = .keepAlways;add(a)
 }
}
