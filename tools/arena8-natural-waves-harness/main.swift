import Foundation
// The real prototype's GameConfig extension compiles unchanged above this stub.
enum GameConfig {}
var passed = 0, failed = 0
func check(_ name: String, _ yes: Bool) {
    if yes { passed += 1 } else { failed += 1; print("FAIL " + name) }
}
func event(_ run: inout Arena8NaturalWaveRun, _ time: Double, _ alive: Bool = true,
           _ placed: Bool = false) -> Arena8NaturalWaveRun.Action? {
    guard let ticket = run.begin(elapsed: time, carrierAlive: alive) else { return nil }
    let action = ticket.action
    check("finish-positive", run.finish(ticket, placed: placed) != nil)
    check("accounting", run.accountedSlots == run.emissions && run.pending == nil)
    check("duplicate-finish-rejected", run.finish(ticket, placed: placed) == nil)
    return action
}
let arguments = ["--arena8-six", "--arena8-title", "--arena8-natural-waves"]
check("natural-gate", Arena8NaturalWaveMode.enabled(arguments: arguments, sixRoom: true, isolated: true, arena9: false))
for combination in [(false,true,false),(true,false,false),(true,true,true)] {
    check("natural-isolation", !Arena8NaturalWaveMode.enabled(arguments: arguments, sixRoom: combination.0, isolated: combination.1, arena9: combination.2))
}
for conflict in ["--arena8-mixed-pressure","--arena8-pressure-trial","--arena8-carrier-fixture","--arena8-signaler-fixture","--arena8-six-traversal","--arena8-pressure-kiting","--arena8-pressure-late"] {
    check("natural-conflict-" + conflict, !Arena8NaturalWaveMode.enabled(arguments: arguments + [conflict], sixRoom: true, isolated: true, arena9: false))
}
check("baseline-comparison-kept", Arena8MixedPressureMode.enabled(arguments: ["--arena8-mixed-pressure"], sixRoom: true, isolated: true, arena9: false))
check("trial-comparison-kept", Arena8MixedPressureMode.profile(arguments: ["--arena8-pressure-trial"]) == .trial)
check("comparison-natural-conflict", !Arena8MixedPressureMode.enabled(arguments: arguments + ["--arena8-mixed-pressure"], sixRoom: true, isolated: true, arena9: false))
check("accepted-rate", Arena8PreviewSpawnClock.Profile.trial.intervalScale == 0.8)
var run = Arena8NaturalWaveRun()
for invalid in [Double.nan, Double.infinity, -1] { check("invalid-time", run.begin(elapsed: invalid, carrierAlive: true) == nil) }
check("hold-no-emission", run.begin(elapsed: 100, carrierAlive: true, held: true) == nil && run.emissions == 0)
check("before30-ordinary", event(&run, 29.999) == .ordinary)
check("at30-reserve", event(&run, 30) == .reservePacket && run.reservedSlots == 1)
check("next-reserve", event(&run, 31) == .reservePacket && run.reservedSlots == 2)
check("blocked-packet-fallback", event(&run, 32) == .packet && !run.packetIntroduced && run.ordinarySlots == 2 && run.reservedSlots == 2)
check("placed-packet-exact-cost", event(&run, 33, true, true) == .packet && run.packetIntroduced && run.packetSlots == 3 && run.reservedSlots == 0)
check("before34-ordinary", event(&run, 33.999) == .ordinary)
check("at34-source-blocked", event(&run, 34) == .signaler && !run.signalerIntroduced && run.signalerSlots == 0)
check("source-placed-one-slot", event(&run, 35, true, true) == .signaler && run.signalerIntroduced && run.signalerSlots == 1)
check("command-once", run.recordPreparedCommand() && !run.recordPreparedCommand())
for time in 36...70 { check("no-replacement", event(&run, Double(time), false, true) == .ordinary) }
check("introduced-counts-permanent", run.packetSlots == 3 && run.signalerSlots == 1 && run.commandPrepared)
check("duplicate-clock-inert", run.begin(elapsed: 70, carrierAlive: true) == nil)
check("backward-clock-inert", run.begin(elapsed: 50, carrierAlive: true) == nil)
var pending = Arena8NaturalWaveRun()
if let ticket = pending.begin(elapsed: 30, carrierAlive: true) {
    check("pending-blocks-emission", pending.begin(elapsed: 31, carrierAlive: true) == nil)
    pending = Arena8NaturalWaveRun()
    check("stale-generation-finish", pending.finish(ticket, placed: true) == nil && pending.emissions == 0)
} else { check("pending-exists", false) }
check("no-command-before-source", !pending.recordPreparedCommand())
var lost = Arena8NaturalWaveRun()
_ = event(&lost, 30); _ = event(&lost, 31); _ = event(&lost, 32, true, true)
check("lost-carrier-skips-source", event(&lost, 34, false) == .ordinary && lost.signalerSkipped)
check("no-source-after-skip", event(&lost, 35, true, true) == .ordinary && !lost.signalerIntroduced)
var blocked = Arena8NaturalWaveRun()
for time in 30...230 { _ = event(&blocked, Double(time), true, false) }
check("blocked-reserve-bounded", blocked.reservedSlots == 2 && blocked.packetAttempts == 199 && blocked.ordinarySlots == 199 && !blocked.packetIntroduced)
// Paired real clock simulation: exact elapsed is supplied independently; the
// natural ledger never advances it or emits additional spawn-clock events.
for hz in [30,60,120] {
    for packetBlocked in [0,1,7,10000] {
        var clock = Arena8PreviewSpawnClock(profile: .trial)
        var ledger = Arena8NaturalWaveRun(), packetTries = 0, sourceTries = 0
        let dt = 1.0 / Double(hz)
        for frame in 1...(125 * hz) {
            let time = Double(frame) * dt
            let interval = time < 90 ? max(0.55, 1.2 - time * 0.01) : max(0.25, 0.55 - (time - 90) * 0.02)
            if clock.advance(dt: dt, baseInterval: interval) {
                guard let ticket = ledger.begin(elapsed: time, carrierAlive: true) else { check("simulation-ticket",false);continue }
                let placed: Bool
                switch ticket.action {
                case .packet: packetTries += 1; placed = packetTries > packetBlocked
                case .signaler: sourceTries += 1; placed = sourceTries > 2
                default: placed = false
                }
                _ = ledger.finish(ticket, placed: placed)
                check("simulation-accounting", ledger.accountedSlots == clock.attempts)
                check("simulation-caps", ledger.packetSlots <= 3 && ledger.signalerSlots <= 1 && ledger.reservedSlots <= 2)
            }
        }
        check("simulation-no-extra-emission", ledger.emissions == clock.attempts)
        check("simulation-profile-unchanged", clock.profile == .trial)
    }
}
print("RESULT \(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
