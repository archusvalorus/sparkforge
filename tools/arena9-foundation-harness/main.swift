import Foundation
import CoreGraphics

var passed = 0
var failed = 0
func check(_ result: @autoclosure () -> Bool, _ name: String) {
    if result() { passed += 1 } else { failed += 1; print("FAIL \(name)") }
}
func rejected(_ name: String, _ expected: Arena9StageDefinition.DefinitionError,
              _ body: () throws -> Void) {
    do { try body(); check(false, name) }
    catch let error as Arena9StageDefinition.DefinitionError { check(error == expected, name) }
    catch { check(false, name + " unexpected error") }
}

do {
    // These are harness fixtures, not authored route dimensions or balance.
    let world = CGRect(x: -100, y: -200, width: 3000, height: 600)
    let entries = [Arena9StageDefinition.Encounter(id: "approach", triggerX: 0),
                   .init(id: "breach", triggerX: 900), .init(id: "parallel", triggerX: 900),
                   .init(id: "last", triggerX: 2600)]
    let stage = try Arena9StageDefinition(world: world, start: CGPoint(x: -50, y: 0), encounters: entries)
    let bounds = Arena9StageBounds(definition: stage)
    check(stage.world == world && stage.encounters == entries, "retain valid definition")
    for bad in [CGRect.null, .infinite, .zero, CGRect(x: 0, y: 0, width: -1, height: 20),
                CGRect(x: CGFloat.nan, y: 0, width: 30, height: 30),
                CGRect(x: CGFloat.greatestFiniteMagnitude, y: 0, width: CGFloat.greatestFiniteMagnitude, height: 30),
                CGRect(x: 1e308, y: 0, width: 1, height: 100),
                CGRect(x: 0, y: 1e308, width: 100, height: 1)] {
        rejected("reject bad world", .invalidWorld) { _ = try Arena9StageDefinition(world: bad, start: .zero, encounters: []) }
    }
    for point in [CGPoint(x: CGFloat.nan, y: 0), CGPoint(x: 0, y: CGFloat.infinity), CGPoint(x: -101, y: 0), CGPoint(x: 0, y: 401)] {
        rejected("reject bad start", .invalidStart) { _ = try Arena9StageDefinition(world: world, start: point, encounters: []) }
    }
    for e in [[Arena9StageDefinition.Encounter(id: "", triggerX: 0)], [.init(id: " \n", triggerX: 0)],
              [.init(id: "x", triggerX: .nan)], [.init(id: "x", triggerX: .infinity)],
              [.init(id: "x", triggerX: -101)], [.init(id: "x", triggerX: 2901)],
              [.init(id: "x", triggerX: 900), .init(id: "y", triggerX: 0)]] {
        rejected("reject bad encounter", .invalidEncounter) { _ = try Arena9StageDefinition(world: world, start: .zero, encounters: e) }
    }
    rejected("duplicate IDs", .duplicateEncounter) {
        _ = try Arena9StageDefinition(world: world, start: .zero, encounters: [.init(id: "x", triggerX: 0), .init(id: "x", triggerX: 5)])
    }
    _ = try Arena9StageDefinition(world: world, start: CGPoint(x: 2900, y: 400), encounters: [])
    check(bounds.contains(CGPoint(x: 2890, y: 390), bodyRadius: 10), "closed body edge")
    check(!bounds.contains(CGPoint(x: 2891, y: 390), bodyRadius: 10), "body beyond edge")
    check(bounds.clamped(CGPoint(x: 4000, y: -300), bodyRadius: 20) == CGPoint(x: 2880, y: -180), "translated far end not old circle")
    for radius in [-1.0, Double.nan, Double.infinity, 301] {
        check(bounds.clamped(.zero, bodyRadius: CGFloat(radius)) == nil, "reject radius")
    }
    check(bounds.clamped(CGPoint(x: CGFloat.nan, y: 0), bodyRadius: 0) == nil, "reject nonfinite body")

    for viewport in [CGSize(width: 390, height: 844), CGSize(width: 1024, height: 1366),
                     CGSize(width: 600, height: 400), CGSize(width: 4000, height: 2000)] {
        for x in stride(from: -400.0, through: 3300.0, by: 37) {
            let point = CGPoint(x: x, y: x / 7)
            if let camera = bounds.cameraCenter(following: point, viewport: viewport),
               let visible = bounds.visibleFootprint(following: point, viewport: viewport) {
                check(Arena9StageDefinition.finite(camera), "finite camera")
                check(visible.minX >= world.minX && visible.maxX <= world.maxX && visible.minY >= world.minY && visible.maxY <= world.maxY, "visibility contained")
                check(visible.width == min(world.width, viewport.width) && visible.height == min(world.height, viewport.height), "no artificial view shrink")
            } else { check(false, "valid camera input") }
        }
    }
    check(bounds.cameraCenter(following: CGPoint(x: 2500, y: 0), viewport: CGSize(width: 400, height: 400))?.x == 2500, "follows right")
    check(bounds.cameraCenter(following: CGPoint(x: 400, y: 0), viewport: CGSize(width: 400, height: 400))?.x == 400, "does not impose retreat wall")
    for size in [CGSize.zero, CGSize(width: -1, height: 10), CGSize(width: CGFloat.nan, height: 20), CGSize(width: CGFloat.infinity, height: 20)] {
        check(bounds.cameraCenter(following: .zero, viewport: size) == nil, "reject camera size")
        check(bounds.visibleFootprint(following: .zero, viewport: size) == nil, "reject visible size")
    }
    for dx in [-100000.0, 0, 200000] {
        let translated = try Arena9StageDefinition(world: world.offsetBy(dx: dx, dy: dx), start: CGPoint(x: dx, y: dx), encounters: [])
        let b = Arena9StageBounds(definition: translated)
        for radius in [0.0, 10, 20, 60, 300] {
            for point in [CGPoint(x: dx, y: dx), CGPoint(x: dx + 8000, y: dx - 8000)] {
                if let q = b.clamped(point, bodyRadius: radius) {
                    check(b.contains(q, bodyRadius: radius), "clamp is valid")
                    check(b.clamped(q, bodyRadius: radius) == q, "idempotent clamp")
                } else { check(false, "valid translated clamp") }
            }
        }
    }

    let ledger = Arena9EncounterLedger(definition: stage)
    check(ledger.candidates(at: CGPoint(x: -1, y: 0)).isEmpty, "before threshold")
    check(ledger.candidates(at: .zero) == ["approach"], "exact threshold")
    check(ledger.candidates(at: CGPoint(x: 900, y: 0)) == ["approach", "breach", "parallel"], "ties author order")
    check(ledger.activated.isEmpty && ledger.live.isEmpty, "query does not activate")
    check(ledger.candidates(at: CGPoint(x: 2600, y: 0)) == entries.map(\.id), "long-step candidates not skipped")
    for p in [CGPoint(x: CGFloat.nan, y: 0), CGPoint(x: 5000, y: 0), CGPoint(x: 2000, y: 401)] {
        check(ledger.candidates(at: p).isEmpty, "reject out-of-stage activation query")
    }
    check(ledger.activate("unknown") == nil, "unknown rejected")
    if let first = ledger.activate("approach") {
        check(ledger.accepts(first), "live ticket")
        check(ledger.activate("approach") == nil, "no duplicate activation")
        check(ledger.candidates(at: .zero).isEmpty, "no threshold replay")
        check(ledger.retire(first), "explicit retirement")
        check(!ledger.accepts(first) && !ledger.retire(first), "no duplicate retirement callback")
        check(ledger.activate("approach") == nil, "retired encounter still never replays")
        let otherRun = Arena9EncounterLedger(definition: stage)
        check(!otherRun.accepts(first), "foreign run ticket rejected")
        let alias = ledger
        let previousGeneration = ledger.generation
        alias.reset()
        check(ledger.generation != previousGeneration && ledger === alias, "aliases share one lifetime owner")
        check(ledger.activated.isEmpty && ledger.live.isEmpty, "reset ownership")
        check(!ledger.accepts(first), "reset rejects stale")
        if let second = ledger.activate("approach") {
            check(second != first && ledger.accepts(second), "reused ID fresh generation")
            check(!ledger.retire(first) && ledger.accepts(second), "old callback cannot remove new encounter")
        } else { check(false, "replay fresh run") }
    } else { check(false, "first activation") }
    for _ in 0..<100 {
        let generation = ledger.generation
        let stale = ledger.activate("last")
        ledger.reset()
        check(ledger.generation != generation, "renew generation")
        if let stale { check(!ledger.accepts(stale), "stale lifetime callback") }
    }
} catch { check(false, "unexpected top-level error \(error)") }
print("Arena9 foundation: \(passed) PASS / \(failed) FAIL")
exit(failed == 0 ? 0 : 1)
