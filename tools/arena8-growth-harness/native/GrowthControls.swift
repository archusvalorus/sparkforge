import XCTest

/// Real Simulator touch/drag/menu/home input. Observation seam is read-only.
final class GrowthControls: XCTestCase {
    let game = XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
    override func tearDown() {
        game.terminate()
        super.tearDown()
    }
    func sample() throws -> [String:Any] {
        let element = game.descendants(matching:.any).matching(identifier:"arena8-six-probe").firstMatch
        XCTAssertTrue(element.waitForExistence(timeout:10))
        let value = try XCTUnwrap(element.value as? String)
        let data = try XCTUnwrap(value.data(using:.utf8))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        XCTAssertEqual(json["safe"] as? Bool,true)
        return json
    }
    func shot(_ name:String) {
        let attachment = XCTAttachment(screenshot:game.screenshot())
        attachment.name = name;attachment.lifetime = .keepAlways;add(attachment)
    }
    func tap(_ x:CGFloat,_ y:CGFloat) {
        game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()
    }
    func testPlacementGrowthPauseAndRelaunch() throws {
        continueAfterFailure = false
        game.launchArguments = ["--arena8-six","--arena8-growth-input","--arena8-six-input"]
        game.launch()
        XCTAssertTrue(game.wait(for:.runningForeground,timeout:20))
        var value = try sample()
        XCTAssertEqual(value["state"] as? String,"placingZone")
        XCTAssertEqual((value["gardens"] as? [[String:Any]])?.count,0)
        shot("growth-00-placement-ghost")
        // Camera is captured on Spark at the first corridor. Drag 15 points
        // along the corridor: a genuine gesture, without writing world state.
        let start = game.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.1,thenDragTo:start.withOffset(CGVector(dx:15,dy:0)),withVelocity:.slow,thenHoldForDuration:0.15)
        Thread.sleep(forTimeInterval:0.5)
        value = try sample()
        XCTAssertEqual(value["state"] as? String,"playing")
        let gardens = try XCTUnwrap(value["gardens"] as? [[String:Any]])
        XCTAssertEqual(gardens.count,1)
        let root = try XCTUnwrap(gardens.first)
        XCTAssertEqual(root["radius"] as? Double,180)
        XCTAssertEqual(value["tree"] as? Bool,true)
        XCTAssertEqual(value["flowers"] as? Int,3)
        XCTAssertGreaterThan(root["x"] as? Double ?? -999,-260)
        XCTAssertLessThan(root["x"] as? Double ?? 999,-200)
        XCTAssertEqual(try XCTUnwrap(root["y"] as? Double),280,accuracy:0.001)
        shot("growth-01-doorway-shadow-tree-flowers")
        tap(game.frame.width-30,80)
        Thread.sleep(forTimeInterval:0.3)
        let held = try sample()
        XCTAssertEqual(held["state"] as? String,"paused")
        Thread.sleep(forTimeInterval:1.5)
        let still = try sample()
        XCTAssertEqual(still["wave"] as? Double,held["wave"] as? Double)
        XCTAssertEqual(still["x"] as? Double,held["x"] as? Double)
        XCTAssertEqual(still["gardens"] as? [[String:Double]],held["gardens"] as? [[String:Double]])
        shot("growth-02-paused")
        tap(game.frame.width/2,game.frame.height/2+124)
        Thread.sleep(forTimeInterval:0.3)
        XCTAssertEqual(try sample()["state"] as? String,"playing")
        XCUIDevice.shared.press(.home)
        game.activate()
        XCTAssertTrue(game.wait(for:.runningForeground,timeout:15))
        Thread.sleep(forTimeInterval:1)
        let resumed = try sample()
        XCTAssertEqual(resumed["gardens"] as? [[String:Double]],held["gardens"] as? [[String:Double]])
        shot("growth-03-background-resume")
        // Actual joystick movement must not drag the garden/rooted Tree.
        if resumed["state"] as? String == "paused" {
            tap(game.frame.width/2,game.frame.height/2+124)
        }
        let joy = game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75))
        joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:70,dy:0)),withVelocity:.fast,thenHoldForDuration:0.35)
        let moved = try sample()
        XCTAssertGreaterThan(moved["x"] as? Double ?? -999,resumed["x"] as? Double ?? 999)
        XCTAssertEqual(moved["gardens"] as? [[String:Double]],held["gardens"] as? [[String:Double]])
        shot("growth-04-root-stays-after-movement")
        game.terminate();game.launch()
        XCTAssertEqual(try sample()["state"] as? String,"placingZone")
        XCTAssertEqual((try sample()["gardens"] as? [[String:Any]])?.count,0)
        shot("growth-05-relaunch-fresh-placement")
        game.terminate()
    }
}
