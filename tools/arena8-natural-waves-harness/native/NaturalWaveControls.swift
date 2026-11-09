import XCTest

/// Read-only Scene probes plus native touches. No API-check/autoplay, stat
/// injection, placement override, invulnerability or enemy-damage changes.
final class NaturalWaveControls: XCTestCase {
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
        let emissions = try XCTUnwrap(s["naturalEmissions"] as? Int)
        XCTAssertEqual(s["naturalAccountedSlots"] as? Int, emissions)
        XCTAssertEqual(s["naturalOrdinarySlots"] as? Int, s["ordinaryTimedAttempts"] as? Int)
        XCTAssertEqual(try XCTUnwrap(s["pressureClockAttempts"] as? Int), emissions + (s["pressureSuppressed"] as? Int ?? 0))
        XCTAssertEqual(s["manualPacketsPlaced"] as? Int, 0); XCTAssertEqual(s["manualSignalersPlaced"] as? Int, 0)
        XCTAssertFalse(s["naturalPending"] as? Bool ?? true)
        XCTAssertLessThanOrEqual(s["naturalPacketSlots"] as? Int ?? 4, 3)
        XCTAssertLessThanOrEqual(s["naturalSignalerSlots"] as? Int ?? 2, 1)
    }
    func startNatural() throws -> [String: Any] {
        game.launchArguments = ["--arena8-six", "--arena8-title", "--arena8-natural-waves", "--arena8-title-input", "--arena8-six-input"]
        game.launch(); let title = try sample("arena8-title-probe")
        XCTAssertEqual(title["isolated"] as? Bool, true); XCTAssertEqual(title["registeredArenas"] as? Int, 7)
        tap(try XCTUnwrap(title["playX"] as? Double), try XCTUnwrap(title["playY"] as? Double))
        let s = try awaitState("natural Play") { $0["naturalWaves"] as? Bool == true }
        playing(s); XCTAssertEqual(s["pressureProfile"] as? String, "trial")
        XCTAssertEqual(s["pressureIntervalScale"] as? Double, 0.8)
        XCTAssertEqual(s["ordinaryStartupAttempts"] as? Int, 1)
        XCTAssertLessThan(s["wave"] as? Double ?? 100, 30)
        XCTAssertEqual(s["naturalPacketIntroduced"] as? Bool, false)
        XCTAssertEqual(s["naturalSignalerIntroduced"] as? Bool, false)
        return s
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
    func pickRealUpgrade(controlledNatural: Bool = false) throws -> String {
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
            _ = try awaitState("real offered cards") { ($0["mixedCardChoices"] as? [[String: Any]])?.isEmpty == false }
            // Let the real staggered card spread finish appearing before a pick.
            Thread.sleep(forTimeInterval: 0.45)
            let shown = try sample()
            let offered = try XCTUnwrap(shown["mixedCardChoices"] as? [[String: Any]])
            // A controlled positive tell test chooses offered controlled stat/primary-hit
            // cards, so FIRE OFF is not contradicted by an autonomous aura.
            // This is a native pick preference, never an availability filter.
            let safe: Set<String> = ["fire_1","fire_2","fire_3","fire_4","v13_overcharge","v16_cauterize","v17_relay_burn",
                "shock_1","shock_2","shock_3","shock_4","v21_bloodthirsty","bleed_1","bleed_2","bleed_3","bleed_4",
                "v21_berserk","v21_sanguinarian","v13_execution","v16_open_vein","v18_bloodlust","v18_glass_blood",
                "guard_1","guard_2","guard_3","guard_4","v13_phase_skin","v16_aegis_pulse","v17_grounded_core","v18_silver_skin",
                "void_1","void_2","void_3","void_4","v21_void_horror","v21_shadow_edge","v16_null_bloom","v17_dead_circuit","v18_riftline","v18_mirror_edge",
                "chill_1","chill_2","chill_3","v16_hoarfrost","v16_whiteout"]
            let controlled = offered.filter { item in
                let id = item["id"] as? String ?? ""
                return (item["tag"] as? String == "neutral" && id != "v20_panda") || safe.contains(id)
            }
            let priorities = ["neutral_1", "guard_1", "v13_phase_skin", "v16_hoarfrost", "guard_3", "shock_3", "v13_magnetic_core", "v18_silver_skin"]
            let preferredControlled = priorities.compactMap { id in controlled.first(where: { $0["id"] as? String == id }) }.first
                ?? controlled.first(where: { $0["tag"] as? String == "neutral" }) ?? controlled.first
            let preferred = controlledNatural ? preferredControlled
                : (offered.first(where: { $0["tag"] as? String != "growth" }) ?? offered.first)
            let chosen = try XCTUnwrap(preferred,"a real offered controlled pick is required by this controlled test")
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
    let route: [(Double,Double)] = [(0,420),(780,420),(780,-420),(0,-420),(-780,-420),(-780,420)]
    func kite(_ s: [String: Any], _ index: inout Int, hold: TimeInterval = 0.4) throws {
        let x = try XCTUnwrap(s["x"] as? Double), y = try XCTUnwrap(s["y"] as? Double)
        if hypot(route[index].0 - x, route[index].1 - y) < 45 { index = (index + 1) % route.count }
        let dx = route[index].0 - x, dy = route[index].1 - y, length = max(1,hypot(dx,dy))
        drag(dx / length * 55, -dy / length * 55, hold: hold)
    }
    /// Input-only steering over the authored greybox and observed enemy roots.
    /// It neither moves Spark directly nor changes actors, damage or clocks.
    /// The app's own collision resolver and hostile damage remain authoritative.
    func kiteSafely(_ s: [String: Any], _ index: inout Int, hold: TimeInterval) throws {
        let x = try XCTUnwrap(s["x"] as? Double), y = try XCTUnwrap(s["y"] as? Double)
        if hypot(route[index].0 - x,route[index].1 - y) < 45 { index = (index + 1) % route.count }
        var walkable: [CGRect] = []
        for cx in [-780.0,0,780] { for cy in [420.0,-420] { walkable.append(CGRect(x:cx-270,y:cy-270,width:540,height:540)) } }
        for cy in [420.0,-420] { for left in [-510.0,270] { walkable.append(CGRect(x:left,y:cy-60,width:240,height:120)) } }
        for cx in [-780.0,0,780] { walkable.append(CGRect(x:cx-60,y:-150,width:120,height:300)) }
        func floor(_ px: Double,_ py: Double) -> Bool {
            for n in 0..<8 {
                let angle = Double(n) * .pi / 4
                let point = CGPoint(x:px+12*cos(angle),y:py+12*sin(angle))
                if !walkable.contains(where:{$0.contains(point)}) { return false }
            }
            return true
        }
        let bodies = (s["liveEnemyBodies"] as? [[String:Any]] ?? []).compactMap { body -> (Double,Double,Double)? in
            guard let bx=body["x"] as? Double,let by=body["y"] as? Double,let radius=body["radius"] as? Double else{return nil}
            return(bx,by,radius)
        }
        let gx=route[index].0-x,gy=route[index].1-y,goalLength=max(1,hypot(gx,gy))
        var best: (Double,Double,Double)?
        for n in 0..<16 {
            let angle=Double(n) * .pi / 8,dx=cos(angle),dy=sin(angle)
            let travel=250 * (hold + 0.1), chase=130 * (hold + 0.3)
            var clearance=Double.infinity,valid=true
            for sample in 1...8 {
                let f=Double(sample)/8,px=x+travel*dx*f,py=y+travel*dy*f
                if !floor(px,py) {valid=false;break}
                for (bx,by,radius) in bodies {
                    let chaseLength=max(1,hypot(x-bx,y-by)),advance=min(chase*f,chaseLength)
                    let predictedX=bx+(x-bx)/chaseLength*advance,predictedY=by+(y-by)/chaseLength*advance
                    clearance=min(clearance,hypot(px-predictedX,py-predictedY)-radius)
                }
            }
            if !valid {continue}
            let alignment=(gx*dx+gy*dy)/goalLength
            let score=min(150,clearance)+alignment*20-(clearance<80 ? 1000:0)
            if best == nil || score > (best?.2 ?? -.infinity) {best=(dx,dy,score)}
        }
        let direction=try XCTUnwrap(best,"at least one legal native steering direction")
        drag(direction.0*55,-direction.1*55,hold:hold)
    }
    func returnFresh(_ epoch: String) throws {
        _ = try pause()
        XCTAssertEqual(try sample()["naturalHUDVisible"] as? Bool, false)
        tap(Double(game.frame.width)/2, Double(game.frame.height)/2 + 232)
        tap(Double(game.frame.width)/2, Double(game.frame.height)/2 + 59)
        let title = try sample("arena8-title-probe")
        tap(try XCTUnwrap(title["playX"] as? Double),try XCTUnwrap(title["playY"] as? Double))
        let fresh = try awaitState("fresh natural Title Play") { $0["naturalWaves"] as? Bool == true }
        playing(fresh); XCTAssertNotEqual(fresh["entryEpoch"] as? String,epoch)
        XCTAssertEqual(fresh["naturalPacketIntroduced"] as? Bool,false)
        XCTAssertEqual(fresh["naturalSignalerIntroduced"] as? Bool,false)
        XCTAssertEqual(fresh["naturalCommandPrepared"] as? Bool,false)
        XCTAssertEqual(fresh["ordinaryStartupAttempts"] as? Int,1)
        try partitions(fresh); try record("natural-native-fresh-reset",fresh)
    }
    func testNaturalPositiveKitingWarningAndOneOrder() throws {
        continueAfterFailure = false
        let initial = try startNatural(), epoch = try XCTUnwrap(initial["entryEpoch"] as? String)
        // Normal combat first; deliberately stop firing before the packet
        // arrives so its one-HP provisional owner can survive for the tell test.
        var index = 0, s = try sample(), captured = false, stoppedFiring = false
        for _ in 0..<240 {
            if s["state"] as? String == "levelUp" { _ = try pickRealUpgrade(controlledNatural: true);s = try sample() }
            playing(s); try partitions(s)
            if !stoppedFiring && (s["wave"] as? Double ?? 0) >= 29 {
                try fire(false);stoppedFiring = true;s = try sample()
                try record("natural-native-normal-combat-warmup",s)
            }
            if s["naturalCommandPrepared"] as? Bool == true && s["signalerCommits"] as? Int == 0 {
                let held = try pause(), remaining = try XCTUnwrap(held["carrierWarningRemaining"] as? Double)
                XCTAssertGreaterThan(remaining,0); XCTAssertEqual(held["signalerCommits"] as? Int,0)
                Thread.sleep(forTimeInterval:0.6); let after = try sample()
                for key in ["wave","carrierWarningRemaining","pressureAccumulated"] { XCTAssertEqual(held[key] as? Double,after[key] as? Double) }
                XCTAssertEqual(held["naturalEmissions"] as? Int,after["naturalEmissions"] as? Int)
                XCTAssertEqual(after["naturalHUDVisible"] as? Bool,false)
                try record("natural-native-positive-warning-hold",after); shot("natural-native-positive-warning-hold")
                XCUIDevice.shared.press(.home);Thread.sleep(forTimeInterval:0.5);game.activate()
                XCTAssertTrue(game.wait(for:.runningForeground,timeout:15));Thread.sleep(forTimeInterval:0.7)
                XCTAssertEqual(try sample()["state"] as? String,"paused")
                _ = try resume(); captured = true; s = try sample(); break
            }
            XCTAssertLessThan(s["wave"] as? Double ?? 200,100)
            let fast = (s["wave"] as? Double ?? 0) >= 33
            if stoppedFiring { try kiteSafely(s,&index,hold:fast ? 0.55 : 0.8) }
            else { try kite(s,&index) }
            s = try sample()
        }
        XCTAssertTrue(captured,"positive natural warning must actually be captured, not inferred")
        for _ in 0..<20 {
            if s["signalerCommits"] as? Int == 1 { break }
            playing(s);try kiteSafely(s,&index,hold:0.5);s = try sample()
        }
        playing(s);try partitions(s)
        XCTAssertEqual(s["naturalPacketSlots"] as? Int,3);XCTAssertEqual(s["naturalSignalerSlots"] as? Int,1)
        XCTAssertEqual(s["signalerAccepted"] as? Int,1);XCTAssertEqual(s["signalerCommits"] as? Int,1)
        XCTAssertEqual(s["naturalCommandPrepared"] as? Bool,true)
        try record("natural-native-real-introductions-and-commit",s);shot("natural-native-real-introductions-and-commit")
        try fire(true)
        for _ in 0..<60 {
            if s["state"] as? String != "playing" { break }
            playing(s);try moveForCombat(s);s = try sample()
        }
        XCTAssertGreaterThan(s["kills"] as? Int ?? 0,0)
        XCTAssertGreaterThan(s["level"] as? Int ?? 0,1)
        XCTAssertEqual(s["state"] as? String,"levelUp")
        let levelTime = try XCTUnwrap(s["wave"] as? Double)
        let levelEmissions = try XCTUnwrap(s["naturalEmissions"] as? Int)
        Thread.sleep(forTimeInterval:0.5);let levelHeld = try sample()
        XCTAssertEqual(levelHeld["wave"] as? Double,levelTime)
        XCTAssertEqual(levelHeld["naturalEmissions"] as? Int,levelEmissions)
        XCTAssertEqual(levelHeld["naturalHUDVisible"] as? Bool,false)
        try record("natural-native-real-XP-and-level-hold",levelHeld)
        _ = try pickRealUpgrade(controlledNatural: true)
        try returnFresh(epoch)
    }
    func testNaturalFireOnCarrierLossSkipsSourceWithoutReplacement() throws {
        continueAfterFailure = false
        let initial = try startNatural(),epoch = try XCTUnwrap(initial["entryEpoch"] as? String)
        var index = 0,s = try sample(),sawPacket = false
        for _ in 0..<260 {
            if s["state"] as? String == "levelUp" { _ = try pickRealUpgrade();s = try sample() }
            playing(s);try partitions(s)
            sawPacket = sawPacket || s["naturalPacketIntroduced"] as? Bool == true
            if s["naturalSignalerSkipped"] as? Bool == true { break }
            XCTAssertLessThan(s["wave"] as? Double ?? 200,100)
            let owner = (s["liveEnemyBodies"] as? [[String:Any]])?.first { $0["kind"] as? String == "CinderCarrierNode" }
            if let owner, let x=owner["x"] as? Double,let y=owner["y"] as? Double,
               let px=s["x"] as? Double,let py=s["y"] as? Double {
                let length=max(1,hypot(x-px,y-py));drag(55*(x-px)/length,-55*(y-py)/length,hold:0.3)
            } else { try kite(s,&index) }
            s = try sample()
        }
        XCTAssertTrue(sawPacket);XCTAssertEqual(s["naturalSignalerSkipped"] as? Bool,true)
        XCTAssertEqual(s["naturalSignalerIntroduced"] as? Bool,false)
        XCTAssertEqual(s["naturalPacketSlots"] as? Int,3);XCTAssertEqual(s["naturalSignalerSlots"] as? Int,0)
        XCTAssertGreaterThan(s["kills"] as? Int ?? 0,0)
        try record("natural-native-FIRE-ON-carrier-loss-source-skip",s)
        for _ in 0..<5 { try kite(s,&index);s = try sample();if s["state"] as? String == "levelUp" { _ = try pickRealUpgrade();s = try sample() } }
        XCTAssertEqual(s["naturalPacketSlots"] as? Int,3);XCTAssertEqual(s["naturalSignalerSlots"] as? Int,0)
        try returnFresh(epoch)
    }
}
