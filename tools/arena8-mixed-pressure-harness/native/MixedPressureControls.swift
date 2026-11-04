import XCTest

/// Read-only Scene probes plus native touches. No API-check/autoplay, stat
/// injection, placement override, invulnerability or enemy-damage changes.
final class MixedPressureControls: XCTestCase {
    let game = XCUIApplication(bundleIdentifier: "com.brandon.Sparkforge")
    override func tearDown() { game.terminate(); super.tearDown() }
    func sample(_ id: String = "arena8-six-probe") throws -> [String: Any] {
        let probe = game.descendants(matching: .any).matching(identifier: id).firstMatch
        if !probe.exists { XCTAssertTrue(probe.waitForExistence(timeout: 15)) }
        let text = try XCTUnwrap(probe.value as? String)
        let data = try XCTUnwrap(text.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
    func record(_ name: String, _ value: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted])
        let item = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        item.name = name; item.lifetime = .keepAlways; add(item)
    }
    func shot(_ name: String) {
        let item = XCTAttachment(screenshot: game.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
    func tap(_ x: Double, _ y: Double) { game.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap() }
    func control(_ id: String, _ value: [String: Any]) throws { tap(try XCTUnwrap(value[id + "X"] as? Double), try XCTUnwrap(value[id + "Y"] as? Double)) }
    func awaitState(_ name: String, _ predicate: ([String: Any]) -> Bool) throws -> [String: Any] {
        let end = Date().addingTimeInterval(10); var s = try sample()
        while !predicate(s) && Date() < end { Thread.sleep(forTimeInterval: 0.1); s = try sample() }
        XCTAssertTrue(predicate(s), name + " " + String(describing: s)); return s
    }
    func playing(_ s: [String: Any]) {
        XCTAssertEqual(s["state"] as? String, "playing"); XCTAssertEqual(s["safe"] as? Bool, true)
        XCTAssertEqual(s["entryFromTitle"] as? Bool, true); XCTAssertEqual(s["roomCount"] as? Int, 6)
        XCTAssertEqual(s["bossMode"] as? Bool, false); XCTAssertEqual(s["mixedPressure"] as? Bool, true)
    }
    func partitions(_ s: [String: Any]) throws {
        let startup = try XCTUnwrap(s["ordinaryStartupAttempts"] as? Int), timed = try XCTUnwrap(s["ordinaryTimedAttempts"] as? Int)
        let placed = try XCTUnwrap(s["ordinaryPlaced"] as? Int), thinned = try XCTUnwrap(s["ordinaryThinned"] as? Int), blocked = try XCTUnwrap(s["ordinaryBlocked"] as? Int)
        XCTAssertEqual(startup + timed, placed + thinned + blocked)
        let clock = try XCTUnwrap(s["pressureClockAttempts"] as? Int), suppressed = try XCTUnwrap(s["pressureSuppressed"] as? Int)
        XCTAssertEqual(clock, timed + suppressed)
        let scale = try XCTUnwrap(s["pressureIntervalScale"] as? Double), base = try XCTUnwrap(s["pressureBaseInterval"] as? Double), interval = try XCTUnwrap(s["pressureInterval"] as? Double)
        XCTAssertEqual(interval, base * scale, accuracy: 1e-12)
    }
    func start(trial: Bool) throws -> [String: Any] {
        game.launchArguments = ["--arena8-six", "--arena8-title", "--arena8-mixed-pressure", "--arena8-title-input", "--arena8-six-input"] + (trial ? ["--arena8-pressure-trial"] : [])
        game.launch(); let title = try sample("arena8-title-probe")
        XCTAssertEqual(title["isolated"] as? Bool, true); XCTAssertEqual(title["selectedFloor"] as? Int, 6); XCTAssertEqual(title["registeredArenas"] as? Int, 7)
        tap(try XCTUnwrap(title["playX"] as? Double), try XCTUnwrap(title["playY"] as? Double))
        let s = try awaitState("mixed Play") { $0["mixedPressure"] as? Bool == true }
        playing(s); XCTAssertEqual(s["pressureProfile"] as? String, trial ? "trial" : "baseline")
        XCTAssertEqual(s["pressureIntervalScale"] as? Double, trial ? 0.8 : 1)
        XCTAssertEqual(s["ordinaryStartupAttempts"] as? Int, 1); XCTAssertEqual(s["carrierFireEnabled"] as? Bool, true)
        XCTAssertEqual(s["manualPacketsPlaced"] as? Int, 0); XCTAssertEqual(s["manualSignalersPlaced"] as? Int, 0)
        try partitions(s); return s
    }
    func fire(_ enabled: Bool) throws {
        let s = try sample(); if s["carrierFireEnabled"] as? Bool != enabled { try control("roomCarrierFire", s) }
        _ = try awaitState("native FIRE") { $0["carrierFireEnabled"] as? Bool == enabled }
    }
    func pause() throws -> [String: Any] {
        tap(Double(game.frame.width) - 30, 80)
        return try awaitState("native Pause") { $0["state"] as? String == "paused" }
    }
    func resume() throws -> [String: Any] {
        tap(Double(game.frame.width) / 2, Double(game.frame.height) / 2 + 124)
        return try awaitState("native Resume") { $0["state"] as? String == "playing" }
    }
    func drag(_ dx: Double, _ dy: Double, hold: TimeInterval) {
        let joy = game.coordinate(withNormalizedOffset: CGVector(dx: 0.24, dy: 0.77))
        joy.press(forDuration: 0.05, thenDragTo: joy.withOffset(CGVector(dx: dx, dy: dy)), withVelocity: .fast, thenHoldForDuration: hold)
    }
    func moveForCombat(_ s: [String: Any]) throws {
        let px = try XCTUnwrap(s["x"] as? Double), py = try XCTUnwrap(s["y"] as? Double)
        let xp = (s["mixedXPOrbs"] as? [[String: Any]] ?? []).compactMap { n -> (Double, Double)? in
            guard let x = n["x"] as? Double, let y = n["y"] as? Double else { return nil }; return (x, y)
        }
        let bodies = (s["liveEnemyBodies"] as? [[String: Any]] ?? []).compactMap { n -> (Double, Double)? in
            guard let x = n["x"] as? Double, let y = n["y"] as? Double else { return nil }; return (x, y)
        }
        let loot = xp.min { hypot($0.0 - px, $0.1 - py) < hypot($1.0 - px, $1.1 - py) }
        let threat = bodies.min { hypot($0.0 - px, $0.1 - py) < hypot($1.0 - px, $1.1 - py) }
        let dx: Double, dy: Double
        if let loot { dx = loot.0 - px; dy = loot.1 - py }
        else if let threat { dx = px - threat.0; dy = py - threat.1 }
        else { dx = 1; dy = 0 }
        let length = max(1, hypot(dx, dy)); drag(55 * dx / length, -55 * dy / length, hold: 0.35)
    }
    func pickRealUpgrade() throws -> String {
        var firstID: String?
        for _ in 0..<8 {
            let s = try sample(), state = s["state"] as? String
            if state == "playing", let id = firstID {
                playing(s); try record("mixed-native-actual-upgrade-queue", s); return id
            }
            if state == "synergyReveal" || state == "placingZone" {
                tap(Double(game.frame.width) / 2, Double(game.frame.height) / 2)
                Thread.sleep(forTimeInterval: 0.3); continue
            }
            XCTAssertEqual(state, "levelUp")
            let shown = try awaitState("real offered cards") { ($0["mixedCardChoices"] as? [[String: Any]])?.isEmpty == false }
            let offered = try XCTUnwrap(shown["mixedCardChoices"] as? [[String: Any]])
            let chosen = try XCTUnwrap(offered.first(where: { $0["tag"] as? String != "growth" }) ?? offered.first)
            let id = try XCTUnwrap(chosen["id"] as? String)
            if firstID == nil { firstID = id }
            tap(try XCTUnwrap(chosen["x"] as? Double), try XCTUnwrap(chosen["y"] as? Double))
            var next = try sample()
            if next["state"] as? String == "levelUp", next["mixedNeedsStat"] as? Bool == true {
                let stats = try XCTUnwrap(next["mixedStatChoices"] as? [[String: Any]])
                let stat = try XCTUnwrap(stats.first(where: { ($0["id"] as? String)?.lowercased() == "hp" }) ?? stats.first)
                tap(try XCTUnwrap(stat["x"] as? Double), try XCTUnwrap(stat["y"] as? Double))
            }
            // Ordinary card dismiss/reveal callbacks run on the real frame loop.
            Thread.sleep(forTimeInterval: 0.6); next = try sample()
            XCTAssertTrue((next["mixedOwnedCards"] as? [[String: Any]])?.contains { $0["id"] as? String == id && ($0["tier"] as? Int ?? 0) >= 1 } == true)
            try record("mixed-native-actual-card-" + id, next)
        }
        XCTFail("bounded real upgrade/reveal queue did not return to play")
        return firstID ?? ""
    }
    func exercise(trial: Bool) throws {
        continueAfterFailure = false
        let first = try start(trial: trial), epoch = try XCTUnwrap(first["entryEpoch"] as? String)
        try fire(false)
        try control("roomCarrierSpawn", sample()); drag(0, 55, hold: 0.6)
        _ = try awaitState("manual carrier packet in ambient waves") { ($0["carrierActors"] as? [[String: Any]])?.count == 3 }
        try control("roomSignalerSpawn", sample())
        let spawned = try awaitState("manual Signaler in ambient waves") { $0["signalerLive"] as? Int == 1 }
        playing(spawned); XCTAssertGreaterThan(try XCTUnwrap(spawned["ambientLive"] as? Int), 0)
        XCTAssertEqual(spawned["manualPacketsPlaced"] as? Int, 1); XCTAssertEqual(spawned["manualSignalersPlaced"] as? Int, 1)
        try control("roomSignalerSignal", spawned)
        let paused = try pause(), remaining = try XCTUnwrap(paused["carrierWarningRemaining"] as? Double)
        let commits = try XCTUnwrap(paused["signalerCommits"] as? Int)
        XCTAssertEqual(paused["signalerAccepted"] as? Int, 1)
        // This case specifically requires a native precommit warning capture.
        // A legitimate already-committed pause is not enough evidence for it.
        XCTAssertEqual(commits, 0); XCTAssertGreaterThan(remaining, 0)
        Thread.sleep(forTimeInterval: 0.7)
        let held = try sample(); XCTAssertEqual(held["state"] as? String, "paused")
        for key in ["wave", "pressureAccumulated", "carrierWarningRemaining"] { XCTAssertEqual(held[key] as? Double, paused[key] as? Double) }
        XCTAssertEqual(held["pressureClockAttempts"] as? Int, paused["pressureClockAttempts"] as? Int)
        var observation = held; observation["nativeWarningCapturedBeforeCommit"] = commits == 0 && remaining > 0
        try record("mixed-native-warning-pause-" + (trial ? "trial" : "baseline"), observation); shot("mixed-native-warning-pause")
        XCUIDevice.shared.press(.home); Thread.sleep(forTimeInterval: 0.5)
        game.activate(); XCTAssertTrue(game.wait(for: .runningForeground, timeout: 15))
        // runningForeground precedes the app-switch presentation finishing.
        // Let the real window become touch-ready before the single Resume tap.
        Thread.sleep(forTimeInterval: 0.7)
        XCTAssertEqual(try sample()["state"] as? String, "paused")
        shot("mixed-native-foreground-paused")
        _ = try resume(); drag(55, 0, hold: 0.7)
        let committed = try awaitState("one mixed native command") { $0["signalerCommits"] as? Int == 1 || $0["state"] as? String != "playing" }
        playing(committed); XCTAssertEqual(committed["signalerCommits"] as? Int, 1); try partitions(committed)
        XCTAssertGreaterThan(try XCTUnwrap(committed["pressureClockAttempts"] as? Int), 0)
        try fire(true)
        var combat = try sample()
        for _ in 0..<24 {
            if combat["state"] as? String != "playing" { break }
            try moveForCombat(combat); combat = try sample()
        }
        XCTAssertGreaterThan(try XCTUnwrap(combat["kills"] as? Int), 0)
        XCTAssertGreaterThan(try XCTUnwrap(combat["level"] as? Int), 1)
        XCTAssertEqual(combat["state"] as? String, "levelUp")
        let levelTime = try XCTUnwrap(combat["wave"] as? Double), levelAttempts = combat["pressureClockAttempts"] as? Int
        Thread.sleep(forTimeInterval: 0.5); let levelHeld = try sample()
        XCTAssertEqual(levelHeld["wave"] as? Double, levelTime); XCTAssertEqual(levelHeld["pressureClockAttempts"] as? Int, levelAttempts)
        try record("mixed-native-real-gun-XP-level", combat)
        _ = try pickRealUpgrade()
        _ = try pause()
        tap(Double(game.frame.width) / 2, Double(game.frame.height) / 2 + 232)
        tap(Double(game.frame.width) / 2, Double(game.frame.height) / 2 + 59)
        let title = try sample("arena8-title-probe")
        tap(try XCTUnwrap(title["playX"] as? Double), try XCTUnwrap(title["playY"] as? Double))
        let fresh = try awaitState("new mixed Title Play") { $0["mixedPressure"] as? Bool == true }
        playing(fresh); XCTAssertNotEqual(fresh["entryEpoch"] as? String, epoch)
        XCTAssertEqual(fresh["ordinaryStartupAttempts"] as? Int, 1); XCTAssertEqual(fresh["manualPacketsPlaced"] as? Int, 0)
        XCTAssertEqual(fresh["manualSignalersPlaced"] as? Int, 0); XCTAssertEqual(fresh["signalerAccepted"] as? Int, 0)
        XCTAssertEqual(fresh["level"] as? Int, 1); XCTAssertEqual(fresh["kills"] as? Int, 0); XCTAssertEqual(fresh["xp"] as? Int, 0)
        XCTAssertEqual(fresh["pressureProfile"] as? String, trial ? "trial" : "baseline"); try partitions(fresh)
        try record("mixed-native-fresh-clean-run", fresh)
    }
    func testBaselineMixedNativeControlsCombatAndLifecycle() throws { try exercise(trial: false) }
    func testTrialMixedNativeControlsCombatAndLifecycle() throws { try exercise(trial: true) }
}
