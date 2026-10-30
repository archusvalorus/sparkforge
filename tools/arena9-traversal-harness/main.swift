import Foundation
import CoreGraphics
var passed = 0, failed = 0
func check(_ id: String, _ yes: @autoclosure () -> Bool) {
    if yes() { passed += 1; print("PASS \(id)") } else { failed += 1; print("FAIL \(id)") }
}
let definition = try Arena9StageDefinition(world: CGRect(x: -500, y: -350, width: 3000, height: 700), start: CGPoint(x: -350,y:0), encounters: [.init(id:"entry",triggerX:0),.init(id:"final",triggerX:1400)])
let goal = CGRect(x:2350,y:-120,width:100,height:240)
for goalFirst in [false,true] {
    let run = Arena9TraversalRun(definition:definition,finalID:"final",goal:goal)
    let first = run.enter(at:.zero)
    check("entry activates exactly once",first.count==1 && run.enter(at:.zero).isEmpty)
    check("retreat does not reactivate",run.enter(at:CGPoint(x:-350,y:0)).isEmpty)
    let earlier = UUID()
    check("earlier member registered",run.register(earlier,ticket:first[0]))
    check("unregistered count cannot seal",!run.seal(first[0],expectedCount:2))
    check("entry sealed",run.seal(first[0],expectedCount:1))
    let final = run.enter(at:CGPoint(x:1500,y:0))
    check("forward activates final only",final.count==1 && final[0].encounterID=="final")
    let a=UUID(),b=UUID()
    check("final members register",run.register(a,ticket:final[0]) && run.register(b,ticket:final[0]))
    check("duplicate owner rejected",!run.register(a,ticket:final[0]))
    check("unsealed final cannot complete",!run.claimSuccess())
    check("final seal exact count",run.seal(final[0],expectedCount:2))
    check("sealed cannot accept late member",!run.register(UUID(),ticket:final[0]))
    if goalFirst { run.observeGoal(at:CGPoint(x:2400,y:0)) }
    check("goal without kills no success",!run.claimSuccess())
    check("one final death",run.retire(a) && !run.claimSuccess())
    check("duplicate and foreign death ignored",!run.retire(a) && !run.retire(UUID()))
    check("second final death",run.retire(b))
    if !goalFirst {
        check("kills without goal no success",!run.claimSuccess())
        run.observeGoal(at:CGPoint(x:2400,y:0))
    }
    check("both orders success once",run.claimSuccess() && !run.claimSuccess())
    check("earlier straggler does not gate final",run.retire(earlier))
    run.cancel()
    check("cancel invalidates all later events",!run.retire(earlier) && !run.register(UUID(),ticket:final[0]) && !run.claimSuccess() && run.enter(at:.zero).isEmpty)
    let replacement=Arena9TraversalRun(definition:definition,finalID:"final",goal:goal)
    _ = replacement.enter(at:CGPoint(x:1500,y:0))
    check("old generation cannot register in new run",!replacement.register(UUID(),ticket:final[0]))
}
do {
    let run=Arena9TraversalRun(definition:definition,finalID:"final",goal:goal)
    let ticket=run.enter(at:CGPoint(x:1500,y:0)).first(where:{$0.encounterID=="final"})
    if let ticket {
        let a=UUID(),b=UUID()
        check("interleaved first spawn registers",run.register(a,ticket:ticket))
        check("interleaved first spawn retires",run.retire(a))
        check("retired identity cannot be reused",!run.register(a,ticket:ticket))
        check("interleaved second spawn registers",run.register(b,ticket:ticket))
        check("seal counts lifetime registration not survivors",run.seal(ticket,expectedCount:2))
        run.observeGoal(at:CGPoint(x:2400,y:0))
        check("last survivor required after interleaving",!run.claimSuccess())
        check("last survivor retirement permits once",run.retire(b) && run.claimSuccess() && !run.claimSuccess())
    } else {check("final interleaved ticket exists",false)}
}
let bounds=Arena9StageBounds(definition:definition)
for radius:CGFloat in [4,12,16,20,40] {
    for point in [CGPoint(x:-9999,y:9999),CGPoint(x:9999,y:-9999),definition.start,CGPoint(x:2400,y:0)] {
        let fitted=bounds.clamped(point,bodyRadius:radius)
        check("rect body clamp",fitted.map { bounds.contains($0,bodyRadius:radius) }==true)
    }
}
for size in [CGSize(width:390,height:844),CGSize(width:834,height:1194)] {
    for x:CGFloat in [-350,300,2000,2400,300,-350] {
        check("camera follows retreat within finite stage",bounds.cameraCenter(following:CGPoint(x:x,y:0),viewport:size).map { Arena9StageDefinition.containsClosed($0,in:definition.world) }==true)
        check("visible clip stays in stage",bounds.visibleFootprint(following:CGPoint(x:x,y:0),viewport:size).map { definition.world.contains($0) }==true)
    }
}
print("RESULT \(passed) passed \(failed) failed");exit(failed==0 ? 0:1)
