import XCTest

final class PrivacyControls: XCTestCase {
    func testFreshAllowAndPersistedChoice() throws { try verifyChoice(allow: true) }
    func testFreshDenyAndPersistedChoice() throws { try verifyChoice(allow: false) }
    private func verifyChoice(allow choice: Bool) throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.brandon.Sparkforge")
        app.launchArguments = ["--privacy-att-system-test"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 30), "Fresh iPad must show real system ATT sheet")
        let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        before.name = "Real ATT fresh iPad"; before.lifetime = .keepAlways; add(before)
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "relevant ads")).firstMatch.exists)
        let button = choice ? alert.buttons["Allow"] : alert.buttons["Ask App Not to Track"]
        XCTAssertTrue(button.exists, alert.debugDescription)
        button.tap()
        let probe = app.staticTexts["privacy-state-probe"]
        let ready = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", choice ? "ATT=authorized" : "ATT=denied", "ready=true")
        expectation(for: ready, evaluatedWith: probe)
        waitForExpectations(timeout: 20)
        print("Verified probe:", probe.label)
        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = choice ? "ATT authorized real OS, consent and SDK stubbed" : "ATT denied real OS, consent and SDK stubbed"; after.lifetime = .keepAlways; add(after)
        app.terminate(); app.launch()
        expectation(for: ready, evaluatedWith: probe); waitForExpectations(timeout: 20)
        XCTAssertFalse(springboard.alerts.firstMatch.exists, "Persisted choice must not reprompt")
        app.terminate()
    }
    func testEntitlementOwnerAndUnknownGameplay() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.brandon.Sparkforge")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let probe = app.staticTexts["privacy-state-probe"]
        func launch(_ mode: String) {
            app.launchArguments = ["--privacy-att-system-test", "--privacy-entitlement-test=" + mode]
            app.launch()
        }
        func check(_ text: String) {
            expectation(for: NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", text, "sdk=false"), evaluatedWith: probe)
            waitForExpectations(timeout: 15)
            print("Native entitlement probe:", probe.label)
        }
        launch("owner"); check("entitlement=owner")
        XCTAssertTrue(probe.label.contains("update=false") && probe.label.contains("form=false"))
        XCTAssertFalse(springboard.alerts.firstMatch.waitForExistence(timeout: 3))
        let owner = XCTAttachment(screenshot: app.screenshot()); owner.name = "Owner skip: StoreKit UMP GMA explicitly stubbed"; owner.lifetime = .keepAlways; add(owner)
        app.terminate()
        launch("unknown"); check("entitlement=unknown")
        XCTAssertFalse(springboard.alerts.firstMatch.waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.355)).tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "scene=GameScene"), evaluatedWith: probe)
        waitForExpectations(timeout: 15)
        check("entitlement=unknown")
        let game = XCTAttachment(screenshot: app.screenshot()); game.name = "Unknown entitlement permits GameScene entry; ads closed"; game.lifetime = .keepAlways; add(game)
        app.terminate()
        launch("delayed-owner"); check("entitlement=owner")
        XCTAssertTrue(probe.label.contains("update=false") && probe.label.contains("form=false"))
        XCTAssertFalse(springboard.alerts.firstMatch.exists)
        app.terminate()
        launch("owner"); check("entitlement=owner")
        XCTAssertFalse(springboard.alerts.firstMatch.exists)
        app.terminate()
    }

    func testRoomPreviewLifecycle() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.brandon.Sparkforge")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for room in ["--arena8-game", "--arena8-six"] {
            app.launchArguments = [room, "--privacy-debug-probe"]
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
            XCTAssertFalse(springboard.alerts.firstMatch.waitForExistence(timeout: 2), "Room preview must not request ATT")
            XCTAssertFalse(app.staticTexts["privacy-state-probe"].exists, "Isolated presenter must not initialize privacy probe/services")
            XCUIDevice.shared.press(.home)
            app.activate()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
            XCTAssertFalse(springboard.alerts.firstMatch.exists)
            XCTAssertFalse(app.staticTexts["privacy-state-probe"].exists)
            let image = XCTAttachment(screenshot: app.screenshot())
            image.name = room + " background-resume; no privacy probe"
            image.lifetime = .keepAlways
            add(image)
            app.terminate()
        }
    }

}
