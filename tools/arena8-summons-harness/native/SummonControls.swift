import XCTest

/// Real touch/menu/home/joystick inputs; read-only room observation seam.
final class SummonControls: XCTestCase {
    let game = XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
    var probe:XCUIElement { game.descendants(matching:.any).matching(identifier:"arena8-six-probe").firstMatch }
    override func tearDown() { game.terminate();super.tearDown() }
    func sample() throws -> [String:Any] {
        XCTAssertTrue(probe.exists)
        let value = try XCTUnwrap(probe.value as? String)
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
    func testSummonsPauseMovementBackgroundAndFreshRun() throws {
        continueAfterFailure = false
        game.launchArguments = ["--arena8-six","--arena8-summons-input","--arena8-six-input","--arena8-six-traversal"]
        game.launch()
        XCTAssertTrue(game.wait(for:.runningForeground,timeout:20))
        XCTAssertTrue(probe.waitForExistence(timeout:10))
        var value = try sample()
        XCTAssertEqual(value["state"] as? String,"playing")
        XCTAssertGreaterThanOrEqual(value["summonLaunches"] as? Int ?? 0,1)
        let root = try XCTUnwrap(value["treeRoot"] as? [String:Double])
        let epoch = try XCTUnwrap(value["summonEpoch"] as? String)
        XCTAssertFalse(epoch.isEmpty)
        let lion = try XCTUnwrap(value["lion"] as? [String:Any])
        XCTAssertEqual(lion["safe"] as? Bool,true)
        shot("summons-00-top-room-tree-lion-flight")
        let live = NSPredicate { element,_ in
            guard let element = element as? XCUIElement,
                  let text = element.value as? String,let data = text.data(using:.utf8),
                  let json = (try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
                  let payloads = json["naturePayloads"] as? [[String:Any]] else { return false }
            return payloads.contains { ($0["life"] as? Double ?? 0) > 1.5 }
        }
        expectation(for:live,evaluatedWith:probe)
        waitForExpectations(timeout:15)
        tap(game.frame.width-30,80)
        let held = try sample()
        XCTAssertEqual(held["state"] as? String,"paused")
        XCTAssertFalse((held["naturePayloads"] as? [[String:Any]] ?? []).isEmpty,"Pause must freeze a live payload, not compare two empty arrays")
        Thread.sleep(forTimeInterval:1.2)
        let still = try sample()
        XCTAssertEqual(still["wave"] as? Double,held["wave"] as? Double)
        XCTAssertEqual(still["summonLaunches"] as? Int,held["summonLaunches"] as? Int)
        XCTAssertTrue(NSArray(array:held["naturePayloads"] as? [[String:Any]] ?? []).isEqual(to:still["naturePayloads"] as? [[String:Any]] ?? []))
        shot("summons-01-paused-payloads")
        tap(game.frame.width/2,game.frame.height/2+124)
        XCTAssertEqual(try sample()["state"] as? String,"playing")
        let before = try sample()
        let joy = game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75))
        joy.press(forDuration:0.05,thenDragTo:joy.withOffset(CGVector(dx:70,dy:0)),withVelocity:.fast,thenHoldForDuration:0.3)
        value = try sample()
        XCTAssertGreaterThan(value["x"] as? Double ?? -999,before["x"] as? Double ?? 999)
        XCTAssertEqual(value["treeRoot"] as? [String:Double],root)
        shot("summons-02-player-moves-tree-stays")
        let count = value["summonLaunches"] as? Int ?? 0
        let advances = NSPredicate { element,_ in
            guard let element = element as? XCUIElement,
                  let text = element.value as? String, let data = text.data(using:.utf8),
                  let json = (try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else { return false }
            return (json["summonLaunches"] as? Int ?? 0) > count
        }
        expectation(for:advances,evaluatedWith:probe)
        waitForExpectations(timeout:15)
        value = try sample()
        XCTAssertGreaterThan(value["summonLaunches"] as? Int ?? 0,count)
        XCTAssertEqual(value["treeRoot"] as? [String:Double],root)
        XCUIDevice.shared.press(.home);game.activate()
        XCTAssertTrue(game.wait(for:.runningForeground,timeout:15))
        Thread.sleep(forTimeInterval:0.5)
        value = try sample()
        XCTAssertEqual(value["treeRoot"] as? [String:Double],root)
        shot("summons-03-background-resume")
        game.terminate();game.launch()
        XCTAssertTrue(probe.waitForExistence(timeout:10))
        let fresh = try sample()
        XCTAssertEqual(fresh["treeRoot"] as? [String:Double],root)
        let freshEpoch = try XCTUnwrap(fresh["summonEpoch"] as? String)
        XCTAssertFalse(freshEpoch.isEmpty)
        XCTAssertNotEqual(freshEpoch,epoch)
        XCTAssertGreaterThanOrEqual(fresh["summonLaunches"] as? Int ?? 0,1)
        shot("summons-04-fresh-capture")
    }
}
