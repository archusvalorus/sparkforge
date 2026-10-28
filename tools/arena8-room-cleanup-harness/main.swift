import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL \(name)")}}
let map=Arena8GameMap.sixRoom
guard let path=Arena8RinkFootprint.path(in:map) else{fatalError("missing authored floor")}
let stroke=path.copy(strokingWithWidth:3,lineCap:.butt,lineJoin:.miter,miterLimit:10)
let rectangles=map.rooms.map(\.rect)+map.connections.map(\.corridor)
var x=map.world.minX-17.31
while x<map.world.maxX+18 {
 var y=map.world.minY-19.19
 while y<map.world.maxY+20 {
  let p=CGPoint(x:x,y:y),expected=rectangles.contains{$0.contains(p)}
  check("rink-fill-equals-authored-floor",path.contains(p)==expected)
  y+=17.13
 }
 x+=15.17
}
for corridor in map.connections {
 check("open-corridor-filled",path.contains(corridor.center))
 let points:[CGPoint]
 if corridor.corridor.width>corridor.corridor.height {points=[CGPoint(x:corridor.corridor.minX,y:corridor.center.y),CGPoint(x:corridor.corridor.maxX,y:corridor.center.y)]}
 else{points=[CGPoint(x:corridor.center.x,y:corridor.corridor.minY),CGPoint(x:corridor.center.x,y:corridor.corridor.maxY)]}
 for p in points{check("no-false-stroke-at-open-door-join",path.contains(p) && !stroke.contains(p))}
}
for wall in map.geometry.blockedFootprints{check("wall-interiors-not-ice",!path.contains(wall.center))}
check("two-room-keeps-legacy-art",Arena8RinkFootprint.path(in:.twoRoom)==nil)
func stored(_ p:CGPoint)->CGPoint{CGPoint(x:CGFloat(Float(p.x)),y:CGFloat(Float(p.y)))}
for scale:CGFloat in [1,1.25,1.7777777] {
 DeviceScale.gameplay=scale
 for room in map.rooms {
  for basePoint in [room.center,CGPoint(x:room.rect.maxX-20,y:room.rect.maxY-20),CGPoint(x:room.rect.minX+20,y:room.rect.minY+20)] {
   let scene=GameScene(),base=PandaNode();base.position=basePoint
   let before=base.position,request=before+CGPoint(x:0,y:16*scale)
   scene.spawnStackedPanda(on:base)
   check("one-static-child-and-base-retained",scene.pandas.count==1 && base.position==before)
   if let child=scene.pandas.first {
    check("child-root-Float-safe20",map.valid(child.node.position,radius:20))
    let expected=Arena8PandaDestination(map:map)!.destination(at:request)!
    check("actual-stack-uses-reviewed-projection",child.node.position==stored(expected))
    if map.valid(request,radius:20) && map.valid(stored(request),radius:20){check("valid-stack-offset-retained",child.node.position==stored(request))}
    check("existing-child-scale-and-timer",child.node.bodyScale==PandaNode.baseScale*0.85 && child.timer==GameConfig.Panda.stackLinger)
   }
  }
 }
}
for room in map.rooms {
 for facing in [false,true] {
  for distance:CGFloat in [40,55,70] {
   let scene=GameScene();scene.player.position=CGPoint(x:facing ? room.rect.maxX-20 : room.rect.minX+20,y:room.rect.maxY-20)
   let before=scene.player.position;TestRandom.nextFacing=facing;TestRandom.nextDistance=distance;TestRandom.draws=0
   scene.actualWitnessBlock();check("one-witness-original-two-draws-three-arrival-attempts",scene.pandas.count==1 && TestRandom.draws==2 && scene.spawnAttempts==GameConfig.Panda.afterKaijuPandas)
   if let witness=scene.pandas.first {
    let request=before+CGPoint(x:distance*(facing ? 1 : -1),y:-10),expected=Arena8PandaDestination(map:map)!.destination(at:request)!
    check("witness-root-safe-and-only-witness-moves",map.valid(witness.node.position,radius:20) && witness.node.position==stored(expected) && scene.player.position==before)
    check("witness-keeps-linger-timing",witness.timer==GameConfig.Panda.witnessLinger)
    check("one-health-drop-keeps12-clear",scene.healthOrbs.count==1 && scene.healthOrbs.allSatisfy{map.valid($0.position,radius:12)})
   }
  }
 }
}
let capped=GameScene(),base=PandaNode()
capped.pandas=(0..<GameConfig.Panda.maxPandas).map{_ in Panda(node:PandaNode(),act:.pleased,phase:.lingering,timer:1,destination:.zero)}
let allocated=PandaNode.allocations;capped.spawnStackedPanda(on:base)
check("stack-cap-before-node-allocation",capped.pandas.count==GameConfig.Panda.maxPandas && PandaNode.allocations==allocated)
capped.player.position=map.rooms[0].center;capped.actualWitnessBlock()
check("witness-existing-unconditional-cap-exception",capped.pandas.count==GameConfig.Panda.maxPandas+1 && capped.spawnAttempts==GameConfig.Panda.afterKaijuPandas)
let bad=GameScene(),invalidBase=PandaNode();invalidBase.position=CGPoint(x:CGFloat.nan,y:0);let oldAlloc=PandaNode.allocations;bad.spawnStackedPanda(on:invalidBase)
check("invalid-static-request-before-allocation",bad.pandas.isEmpty && PandaNode.allocations==oldAlloc)
for context in [nil,Arena8GameMap.twoRoom] {
 let scene=GameScene();scene.debugRoomIntegration=context;base.position=CGPoint(x:999,y:999);scene.spawnStackedPanda(on:base)
 check("legacy-stack-offset-unchanged",scene.pandas.first?.node.position==stored(base.position+CGPoint(x:0,y:16*DeviceScale.gameplay)))
}
let malformed=GameScene();malformed.player.position=CGPoint(x:CGFloat.nan,y:0);let allocBefore=PandaNode.allocations
malformed.actualWitnessBlock()
check("invalid-witness-skipped-with-following-attempts-retained",malformed.pandas.isEmpty && malformed.healthOrbs.isEmpty && malformed.spawnAttempts==GameConfig.Panda.afterKaijuPandas && PandaNode.allocations==allocBefore)
for mode in ["active","retired","removed-membership","detached","same-scene-reset","replaced-scene","leaving","wrong-act","nil-view"] {
 let scene=GameScene(),view=TestView();view.scene=scene;scene.view=view
 scene.spawnAvalanchePanda(at:map.rooms[0].center,heading:CGPoint(x:1,y:0),delay:0.75)
 guard let node=scene.pandas.first?.node else{check("actual-child-created",false);continue}
 let callbacks=node.actions.flatMap{$0.callbacks()};check("actual-scheduled-callback-captured",callbacks.count==1)
 let other=GameScene()
 switch mode {
 case "retired":scene.pandas[0].phase = .lingering
 case "removed-membership":scene.pandas.removeAll()
 case "detached":node.removeFromParent()
 case "same-scene-reset":scene.pandas.removeAll();scene.spawnAvalanchePanda(at:node.position,heading:CGPoint(x:1,y:0),delay:0.1)
 case "replaced-scene":view.scene=other
 case "leaving":scene.pandas[0].leaving=true
 case "wrong-act":scene.pandas[0].act = .pleased
 case "nil-view":scene.view=nil
 default:break
 }
 callbacks.forEach{$0()}
 check("callback-state-"+mode,node.rollStarts==(mode=="active" ? 1 : 0))
}
for context in [nil,Arena8GameMap.twoRoom] {
 let scene=GameScene();scene.debugRoomIntegration=context
 scene.spawnAvalanchePanda(at:.zero,heading:CGPoint(x:1,y:0),delay:0.75)
 if let node=scene.pandas.first?.node {scene.pandas[0].phase = .lingering;node.actions.flatMap{$0.callbacks()}.forEach{$0()};check("legacy-delayed-callback-unchanged",node.rollStarts==1)}
}
print("Room cleanup checks: \(passed) passed / \(failed) failed")
exit(failed==0 ? 0 : 1)
