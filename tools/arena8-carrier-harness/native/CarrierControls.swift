import XCTest

/// Native gestures and read-only Debug accessibility samples only.
/// No API-check flags, Scene commands, placement overrides or combat changes.
final class CarrierControls: XCTestCase {
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
                                "--arena8-six-input", "--arena8-carrier-fixture"]
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

    func testNativeEmptyEntryMovementAndTitleReset() throws {
        continueAfterFailure = false
        let initial = try start()
        let epoch = try XCTUnwrap(initial["entryEpoch"] as? String)
        try fire(false)
        let before = try sample()
        let joy = game.coordinate(withNormalizedOffset: CGVector(dx: 0.24, dy: 0.77))
        joy.press(forDuration: 0.05,
                  thenDragTo: joy.withOffset(CGVector(dx: 55, dy: 0)),
                  withVelocity: .fast, thenHoldForDuration: 0.25)
        let moved = try sample(); checkPlaying(moved)
        XCTAssertGreaterThan(try XCTUnwrap(moved["x"] as? Double),
                             try XCTUnwrap(before["x"] as? Double))
        Thread.sleep(forTimeInterval: 1.2)
        let empty = try sample(); checkPlaying(empty)
        XCTAssertEqual(empty["enemies"] as? Int, 0)
        XCTAssertEqual(empty["carrierPackets"] as? Int, 0)
        XCTAssertEqual(empty["carrierCommits"] as? Int, 0)
        let paused = try pause()
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 0.6)
        game.activate(); XCTAssertTrue(game.wait(for: .runningForeground, timeout: 15))
        let held = try sample()
        XCTAssertEqual(held["state"] as? String, "paused")
        XCTAssertEqual(held["wave"] as? Double, paused["wave"] as? Double)
        XCTAssertEqual(held["entryEpoch"] as? String, epoch)
        try record("carrier-native-empty-paused-background", held)
        shot("carrier-native-empty-paused-background")
        let title = try returnToTitle()
        XCTAssertEqual(title["selectedFloor"] as? Int, 6)
        tap(try XCTUnwrap(title["playX"] as? Double), try XCTUnwrap(title["playY"] as? Double))
        let fresh = try awaitState("fresh title play") { $0["carrierFireEnabled"] != nil }
        checkPlaying(fresh)
        XCTAssertNotEqual(fresh["entryEpoch"] as? String, epoch)
        XCTAssertEqual(fresh["carrierFireEnabled"] as? Bool, true)
        XCTAssertEqual(fresh["enemies"] as? Int, 0)
        XCTAssertEqual(fresh["carrierPackets"] as? Int, 0)
        XCTAssertEqual(fresh["carrierCommits"] as? Int, 0)
        XCTAssertEqual(fresh["xp"] as? Int, 0)
        XCTAssertEqual(fresh["kills"] as? Int, 0)
        try record("carrier-native-fresh-title-play", fresh)
    }

    func testNativePacketMigrationPauseAndCleanup() throws {
        continueAfterFailure = false
        _ = try start(); try fire(false)
        let controls = try sample()
        try control("roomCarrierSpawn", from: controls)
        let spawned = try awaitState("manual three actor packet") {
            ($0["carrierPackets"] as? Int) == 1 && ($0["carrierActors"] as? [[String: Any]])?.count == 3
        }
        checkPlaying(spawned)
        XCTAssertEqual(try actors(spawned).compactMap { $0["kind"] as? String }.sorted(),
                       ["CinderCarrierNode", "LinekeeperNode", "SpurhoundNode"])
        XCTAssertTrue(try actors(spawned).allSatisfy { ($0["safe"] as? Bool) == true })
        let ids = try actorIDs(spawned)
        try record("carrier-native-spawn", spawned)
        try control("roomCarrierMigrate", from: spawned)
        // Do not sample between MIGRATE and PAUSE: native input timing may
        // otherwise consume the entire one-second warning. Record the actual
        // phase observed; no windup-freeze claim when it was already committed.
        let paused = try pause()
        let remaining = try XCTUnwrap(paused["carrierWarningRemaining"] as? Double)
        let commits = try XCTUnwrap(paused["carrierCommits"] as? Int)
        XCTAssertTrue((commits == 0 && remaining > 0) || commits == 1)
        XCTAssertEqual(try actorIDs(paused), ids)
        Thread.sleep(forTimeInterval: 1.2)
        let held = try sample()
        XCTAssertEqual(held["state"] as? String, "paused")
        XCTAssertEqual(held["carrierCommits"] as? Int, commits)
        XCTAssertEqual(held["carrierWarningRemaining"] as? Double, remaining)
        XCTAssertEqual(held["wave"] as? Double, paused["wave"] as? Double)
        XCTAssertEqual(try actorIDs(held), ids)
        var observation = held
        observation["nativeWarningCapturedBeforeCommit"] = commits == 0 && remaining > 0
        observation["scope"] = "native tap and pause; exact one-second warning boundary is separately tested through actual Scene API"
        try record("carrier-native-warning-or-committed-pause-observation", observation)
        shot("carrier-native-packet-paused")
        _ = try resume()
        let committed = try awaitState("one native migration commit", timeout: 5) {
            ($0["carrierCommits"] as? Int) == 1 || ($0["state"] as? String) != "playing"
        }
        checkPlaying(committed)
        XCTAssertEqual(committed["carrierCommits"] as? Int, 1)
        XCTAssertEqual(try actorIDs(committed), ids)
        XCTAssertTrue(try actors(committed).allSatisfy { ($0["safe"] as? Bool) == true })
        // One short real retreat gesture while the packet is live. This does
        // not claim traversing all corridors or surviving a complete encounter.
        let px = try XCTUnwrap(committed["x"] as? Double)
        let py = try XCTUnwrap(committed["y"] as? Double)
        let roots = try actors(committed).compactMap { value -> (Double, Double)? in
            guard let x = value["x"] as? Double, let y = value["y"] as? Double else { return nil }
            return (x, y)
        }
        let nearest = try XCTUnwrap(roots.min { hypot($0.0 - px, $0.1 - py) < hypot($1.0 - px, $1.1 - py) })
        let dx = px - nearest.0, dy = py - nearest.1
        let length = max(1, hypot(dx, dy))
        let joy = game.coordinate(withNormalizedOffset: CGVector(dx: 0.24, dy: 0.77))
        joy.press(forDuration: 0.05,
                  thenDragTo: joy.withOffset(CGVector(dx: 55 * dx / length, dy: -55 * dy / length)),
                  withVelocity: .fast, thenHoldForDuration: 0.2)
        let kited = try sample(); checkPlaying(kited)
        let movement = hypot(try XCTUnwrap(kited["x"] as? Double) - px,
                             try XCTUnwrap(kited["y"] as? Double) - py)
        XCTAssertGreaterThan(movement, 1)
        XCTAssertEqual(kited["carrierCommits"] as? Int, 1)
        try record("carrier-native-short-live-packet-retreat", kited)
        let againPaused = try pause()
        XCTAssertEqual(againPaused["carrierCommits"] as? Int, 1)
        try record("carrier-native-one-commit-before-title", againPaused)
        _ = try returnToTitle()
        let title = try sample("arena8-title-probe")
        tap(try XCTUnwrap(title["playX"] as? Double), try XCTUnwrap(title["playY"] as? Double))
        let fresh = try awaitState("fresh empty fixture after packet Title") { $0["carrierFireEnabled"] != nil }
        checkPlaying(fresh)
        XCTAssertNotEqual(fresh["entryEpoch"] as? String, spawned["entryEpoch"] as? String)
        XCTAssertEqual(fresh["carrierPackets"] as? Int, 0)
        XCTAssertEqual(try actors(fresh).count, 0)
        XCTAssertEqual(fresh["carrierCommits"] as? Int, 0)
        XCTAssertEqual(fresh["enemies"] as? Int, 0)
        XCTAssertEqual(fresh["carrierFireEnabled"] as? Bool, true)
        XCTAssertEqual(fresh["kills"] as? Int, 0)
        XCTAssertEqual(fresh["xp"] as? Int, 0)
        try record("carrier-native-packet-title-cleanup", fresh)
    }
}
