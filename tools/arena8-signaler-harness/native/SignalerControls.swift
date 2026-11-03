import XCTest

/// Native gestures and read-only Debug accessibility samples only.
/// No API-check flags, Scene commands, placement overrides or combat changes.
final class SignalerControls: XCTestCase {
    let game = XCUIApplication(bundleIdentifier: "com.brandon.Sparkforge")

    override func tearDown() { game.terminate(); super.tearDown() }

    func sample(_ id: String = "arena8-six-probe") throws -> [String: Any] {
        let probe = game.descendants(matching: .any).matching(identifier: id).firstMatch
        XCTAssertTrue(probe.waitForExistence(timeout: 15), "read-only probe " + id)
        let text = try XCTUnwrap(probe.value as? String)
        let data = try XCTUnwrap(text.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func record(_ label: String, _ value: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = label; attachment.lifetime = .keepAlways; add(attachment)
    }

    func shot(_ label: String) {
        let attachment = XCTAttachment(screenshot: game.screenshot())
        attachment.name = label; attachment.lifetime = .keepAlways; add(attachment)
    }

    func tap(_ x: Double, _ y: Double) {
        game.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()
    }

    func control(_ name: String, from value: [String: Any]) throws {
        tap(try XCTUnwrap(value[name + "X"] as? Double),
            try XCTUnwrap(value[name + "Y"] as? Double))
    }

    func awaitState(_ label: String, timeout: TimeInterval = 8,
                    _ predicate: ([String: Any]) -> Bool) throws -> [String: Any] {
        let deadline = Date().addingTimeInterval(timeout)
        var value = try sample()
        while !predicate(value) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
            value = try sample()
        }
        XCTAssertTrue(predicate(value), label + " " + String(describing: value))
        return value
    }

    func actors(_ value: [String: Any]) throws -> [[String: Any]] {
        try XCTUnwrap(value["carrierActors"] as? [[String: Any]])
    }

    func actorIDs(_ value: [String: Any]) throws -> [String] {
        try actors(value).map { try XCTUnwrap($0["id"] as? String) }.sorted()
    }

    func checkPlaying(_ value: [String: Any]) {
        XCTAssertEqual(value["state"] as? String, "playing")
        XCTAssertEqual(value["safe"] as? Bool, true)
        XCTAssertEqual(value["roomCount"] as? Int, 6)
        XCTAssertEqual(value["bossMode"] as? Bool, false)
        XCTAssertEqual(value["entryFromTitle"] as? Bool, true)
    }

    func start() throws -> [String: Any] {
        game.launchArguments = ["--arena8-six", "--arena8-title", "--arena8-title-input",
                                "--arena8-six-input", "--arena8-signaler-fixture"]
        game.launch()
        let title = try sample("arena8-title-probe")
        XCTAssertEqual(title["isolated"] as? Bool, true)
        XCTAssertEqual(title["selectedFloor"] as? Int, 6)
        XCTAssertEqual(title["registeredArenas"] as? Int, 7)
        tap(try XCTUnwrap(title["playX"] as? Double), try XCTUnwrap(title["playY"] as? Double))
        let value = try awaitState("carrier fixture entered") { $0["carrierFireEnabled"] != nil }
        checkPlaying(value)
        XCTAssertEqual(value["enemies"] as? Int, 0)
        XCTAssertEqual(value["carrierPackets"] as? Int, 0)
        XCTAssertEqual(try actors(value).count, 0)
        XCTAssertEqual(value["carrierCommits"] as? Int, 0)
        XCTAssertEqual(value["carrierFireEnabled"] as? Bool, true)
        return value
    }

    func fire(_ enabled: Bool) throws {
        let before = try sample()
        if before["carrierFireEnabled"] as? Bool != enabled {
            try control("roomCarrierFire", from: before)
        }
        _ = try awaitState("native fire control") { ($0["carrierFireEnabled"] as? Bool) == enabled }
    }

    func pause() throws -> [String: Any] {
        tap(Double(game.frame.width) - 30, 80)
        return try awaitState("native manual pause") { ($0["state"] as? String) == "paused" }
    }

    func resume() throws -> [String: Any] {
        // Existing PauseMenuNode RESUME position: scene-center y -124.
        tap(Double(game.frame.width) / 2, Double(game.frame.height) / 2 + 124)
        return try awaitState("native resume") { ($0["state"] as? String) == "playing" }
    }

    func returnToTitle() throws -> [String: Any] {
        tap(Double(game.frame.width) / 2, Double(game.frame.height) / 2 + 232)
        // Existing measured confirmation: QUIT RUN59points below scene center.
        tap(Double(game.frame.width) / 2, Double(game.frame.height) / 2 + 59)
        return try sample("arena8-title-probe")
    }

    func testNativeSignalerCommandPauseAndTitleCleanup() throws {
        continueAfterFailure = false
        _ = try start(); try fire(false)
        try control("roomCarrierSpawn", from: sample())
        // Make room before the next native UI round trip; all bodies retain
        // their real movement/contact rules and Spark remains in this room.
        let openingRetreat = game.coordinate(withNormalizedOffset: CGVector(dx: 0.24, dy: 0.77))
        openingRetreat.press(forDuration: 0.05, thenDragTo: openingRetreat.withOffset(CGVector(dx: 0, dy: 55)), withVelocity: .fast, thenHoldForDuration: 0.8)
        _ = try awaitState("live carrier group") { ($0["carrierActors"] as? [[String: Any]])?.count == 3 }
        try control("roomSignalerSpawn", from: sample())
        let spawned = try awaitState("live Signaler") { ($0["signalerActors"] as? [[String: Any]])?.count == 1 }
        XCTAssertEqual(spawned["enemies"] as? Int, 4)
        XCTAssertEqual(spawned["signalerAccepted"] as? Int, 0)
        XCTAssertTrue((spawned["signalerActors"] as? [[String: Any]])?.allSatisfy { ($0["safe"] as? Bool) == true } == true)
        let ids = try actorIDs(spawned)
        try record("signaler-native-spawn", spawned)
        try control("roomSignalerSignal", from: spawned)
        let paused = try pause()
        XCTAssertEqual(paused["signalerAccepted"] as? Int, 1)
        let commits = try XCTUnwrap(paused["signalerCommits"] as? Int)
        let remaining = try XCTUnwrap(paused["carrierWarningRemaining"] as? Double)
        XCTAssertTrue((commits == 0 && remaining > 0) || commits == 1)
        Thread.sleep(forTimeInterval: 1.2)
        let held = try sample()
        XCTAssertEqual(held["state"] as? String, "paused")
        XCTAssertEqual(held["wave"] as? Double, paused["wave"] as? Double)
        XCTAssertEqual(held["signalerCommits"] as? Int, commits)
        XCTAssertEqual(held["carrierWarningRemaining"] as? Double, remaining)
        XCTAssertEqual(try actorIDs(held), ids)
        var observation = held
        observation["nativeWarningCapturedBeforeCommit"] = commits == 0 && remaining > 0
        try record("signaler-native-pause", observation); shot("signaler-native-pause")
        let resumed = try resume()
        // Kite immediately after resuming. Extra live telemetry round trips
        // while stationary are not a survival requirement for this fixture.
        let joy = game.coordinate(withNormalizedOffset: CGVector(dx: 0.24, dy: 0.77))
        joy.press(forDuration: 0.05, thenDragTo: joy.withOffset(CGVector(dx: 55, dy: 0)), withVelocity: .fast, thenHoldForDuration: 0.9)
        let committed = try awaitState("native Signaler commit", timeout: 6) { ($0["signalerCommits"] as? Int) == 1 || ($0["state"] as? String) != "playing" }
        // Pause promptly after the one live sample, before serializing evidence.
        let safelyPaused = try pause()
        checkPlaying(committed)
        XCTAssertEqual(committed["signalerCommits"] as? Int, 1)
        XCTAssertEqual(try actorIDs(committed), ids)
        XCTAssertTrue(try actors(committed).allSatisfy { ($0["safe"] as? Bool) == true })
        XCTAssertTrue((committed["signalerActors"] as? [[String: Any]])?.count == 1)
        XCTAssertTrue((committed["signalerActors"] as? [[String: Any]])?.allSatisfy { ($0["safe"] as? Bool) == true } == true)
        let movement = hypot(try XCTUnwrap(committed["x"] as? Double) - XCTUnwrap(resumed["x"] as? Double), try XCTUnwrap(committed["y"] as? Double) - XCTUnwrap(resumed["y"] as? Double))
        XCTAssertGreaterThan(movement, 1)
        XCTAssertEqual(safelyPaused["signalerCommits"] as? Int, 1)
        try record("signaler-native-live-retreat", committed)
        XCUIDevice.shared.press(.home); Thread.sleep(forTimeInterval: 0.5)
        game.activate(); XCTAssertTrue(game.wait(for: .runningForeground, timeout: 15))
        XCTAssertEqual(try sample()["state"] as? String, "paused")
        let title = try returnToTitle()
        tap(try XCTUnwrap(title["playX"] as? Double), try XCTUnwrap(title["playY"] as? Double))
        let fresh = try awaitState("fresh Signaler title play") { $0["signalerAccepted"] != nil }
        checkPlaying(fresh)
        XCTAssertEqual(fresh["enemies"] as? Int, 0)
        XCTAssertEqual(fresh["signalerAccepted"] as? Int, 0)
        XCTAssertEqual(fresh["signalerCommits"] as? Int, 0)
        XCTAssertEqual((fresh["signalerActors"] as? [[String: Any]])?.count, 0)
        XCTAssertEqual(try actors(fresh).count, 0)
        try record("signaler-native-title-cleanup", fresh)
    }
}
