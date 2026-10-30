import XCTest
final class RoomSizeControls: XCTestCase {
    let game = XCUIApplication(bundleIdentifier:"com.brandon.Sparkforge")
    func start(_ traversal:Bool) {
        continueAfterFailure=false
        game.launchArguments=["--arena8-six","--arena8-title","--arena8-title-input","--arena8-six-input"] + (traversal ? ["--arena8-six-traversal"] : [])
        game.launch();XCTAssertTrue(game.wait(for:.runningForeground,timeout:20));Thread.sleep(forTimeInterval:0.8)
        let title=game.descendants(matching:.any).matching(identifier:"arena8-title-probe").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout:10))
        guard let text=title.value as? String,let data=text.data(using:.utf8),let info=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let px=info["playX"] as? Double,let py=info["playY"] as? Double else {XCTFail("Missing title Play coordinates");return}
        tap(px,py)
        XCTAssertTrue(game.descendants(matching:.any).matching(identifier:"arena8-six-probe").firstMatch.waitForExistence(timeout:10))
    }
    func sample()->[String:Any] {
        let element=game.descendants(matching:.any).matching(identifier:"arena8-six-probe").firstMatch
        guard let s=element.value as? String,let data=s.data(using:.utf8),let json=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{XCTFail("Missing native observation");return [:]}
        XCTAssertEqual(json["safe"] as? Bool,true);return json
    }
    func position()->CGPoint {let s=sample();let x=(s["x"] as? Double) ?? 9999,y=(s["y"] as? Double) ?? 9999;XCTAssertEqual((s["cameraX"] as? Double) ?? -9999,x,accuracy:0.01);XCTAssertEqual((s["cameraY"] as? Double) ?? -9999,y,accuracy:0.01);return CGPoint(x:x,y:y)}
    func shot(_ name:String){let a=XCTAttachment(screenshot:game.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
    func tap(_ x:CGFloat,_ y:CGFloat){game.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:x,dy:y)).tap()}
    func joystick(_ dx:Double,_ dy:Double,_ hold:Double){let a=game.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.75));let scale=70/hypot(dx,dy);let b=a.withOffset(CGVector(dx:dx*scale,dy:dy*scale));a.press(forDuration:0.05,thenDragTo:b,withVelocity:.fast,thenHoldForDuration:hold)}
    func go(_ x:Double,_ y:Double){
        for _ in 0..<12 {
            let p=position(),dx=x-Double(p.x),dy=y-Double(p.y)
            if hypot(dx,dy)<35{return}
            // One axis at a time preserves clearance at each planned turn.
            let horizontal=abs(dx)>abs(dy),distance=horizontal ? dx:dy
            let hold=min(1.6,max(0.01,abs(distance)/250 - 0.06))
            joystick(horizontal ? (distance>0 ? 0.18:-0.18):0,horizontal ? 0:(distance>0 ? -0.18:0.18),hold)
        }
        let p=position();XCTAssertLessThan(hypot(Double(p.x)-x,Double(p.y)-y),35,"Did not reach world target \(x),\(y): \(p)")
    }
    func testAAllSevenDoorwaysAndWallSliding(){
        start(true);shot("00-six-room-start")
        tap(game.frame.width-30,80);Thread.sleep(forTimeInterval:0.3)
        let held=sample();XCTAssertEqual(held["state"] as? String,"paused");shot("01-paused")
        Thread.sleep(forTimeInterval:2);let still=sample();XCTAssertEqual(still["wave"] as? Double,held["wave"] as? Double);XCTAssertEqual(still["x"] as? Double,held["x"] as? Double)
        tap(game.frame.width/2,game.frame.height/2+124);Thread.sleep(forTimeInterval:0.3);XCTAssertEqual(sample()["state"] as? String,"playing")
        go(-780,600);joystick(0.18,0,1.0);let before=position();joystick(0.18,0,0.5);let blocked=position();XCTAssertLessThanOrEqual(blocked.x,-515);XCTAssertLessThan(abs(blocked.y-before.y),1);shot("02-wall-stop")
        joystick(0,0.10,0.12);let slid=position();XCTAssertLessThan(slid.y,blocked.y-10);XCTAssertLessThanOrEqual(slid.x,-515);shot("03-wall-slide")
        joystick(-0.18,0,0.25);XCTAssertLessThan(position().x,slid.x-20);shot("04-wall-reversal")
        go(-780,600);go(-780,420)
        for (index,point) in [(0.0,420.0),(780.0,420.0),(780.0,-420.0),(0.0,-420.0),(-780.0,-420.0),(-780.0,420.0),(0.0,420.0),(0.0,-420.0),(0.0,420.0)].enumerated(){
            go(point.0,point.1);let s=sample();XCTAssertEqual(s["enemies"] as? Int,0);XCTAssertEqual(s["state"] as? String,"playing");shot("door-\(index)-world-\(Int(point.0))-\(Int(point.1))")
        }
        game.terminate()
    }
    func testBOrdinarySixRoomCombatAndUpgrade(){
        start(false);shot("combat-00-start")
        var level=false
        for index in 0..<35 {
            let s=sample();if s["state"] as? String == "levelUp" {level=true;break}
            if index > 3 { joystick(index % 6 < 3 ? 0.18:-0.18,0,0.55) }
            else { Thread.sleep(forTimeInterval:1) }
        }
        let s=sample();XCTAssertGreaterThan(s["kills"] as? Int ?? 0,0);XCTAssertTrue(level,"Normal live combat should earn first level");shot("combat-01-real-kills-xp-level")
        tap(game.frame.width/2-124,game.frame.height/2+86);shot("combat-02-card-selected")
        tap(game.frame.width/2-108,game.frame.height/2-92);Thread.sleep(forTimeInterval:1.5)
        var after=sample()
        XCTAssertTrue(after["state"] as? String == "playing" || (after["state"] as? String == "levelUp" && (after["level"] as? Int ?? 0)>2), "First normal upgrade must commit before a banked modal")
        shot("combat-03-normal-upgrade-completed-or-banked-next")
        for _ in 0..<3 where after["state"] as? String == "levelUp" {
            let prior=after["level"] as? Int ?? 0
            tap(game.frame.width/2-124,game.frame.height/2+86)
            if prior % 2 == 0 { tap(game.frame.width/2-108,game.frame.height/2-92) }
            Thread.sleep(forTimeInterval:1.5);after=sample()
            XCTAssertTrue(after["state"] as? String == "playing" || (after["level"] as? Int ?? 0)>prior,"Queued level must commit")
        }
        XCTAssertEqual(after["state"] as? String,"playing");XCTAssertGreaterThanOrEqual(after["level"] as? Int ?? 0,2);shot("combat-03b-bank-drained-gameplay")
        joystick(0.18,0,0.4);shot("combat-04-post-upgrade-movement");game.terminate()
    }
}
