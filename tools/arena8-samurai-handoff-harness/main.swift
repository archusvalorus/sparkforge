import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ id:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL \(id)")}}
typealias Scene=GameScene
func actor(_ s:Scene,root:CGPoint,target:EnemyNode?)->PandaNode {
 let n=PandaNode();n.position=root;s.worldNode.addChild(n)
 var p=Scene.Panda(node:n,act:.samurai,phase:.approaching,timer:27,destination:target?.position ?? .zero)
 if let target{p.samuraiMark = .enemy(target)}
 s.pandas.append(p);return n
}
func enemy(_ s:Scene,_ p:CGPoint)->EnemyNode{let e=EnemyNode(100);e.position=p;s.enemies.append(e);s.worldNode.addChild(e);return e}
let map=Arena8GameMap.sixRoom
for scale:CGFloat in [1,1.25,1.7777777] {
 DeviceScale.gameplay=scale
 for room in map.rooms {
  for edge in [CGPoint(x:room.rect.minX+17.5,y:room.rect.maxY-60),CGPoint(x:room.rect.maxX-17.5,y:room.rect.maxY-60),CGPoint(x:room.rect.minX+60,y:room.rect.minY+17.5),CGPoint(x:room.rect.minX+60,y:room.rect.maxY-17.5),CGPoint(x:room.rect.maxX-17.5,y:room.rect.maxY-17.5)] {
   let s=Scene(),e=enemy(s,edge),n=actor(s,root:edge+CGPoint(x:0.5,y:0.5),target:e)
   let before=n.position,targetBefore=e.position
   check("arrival-fixture-completes-real-waddle",before.distance(to:e.position)<4*scale)
   check("arrival-fixture-unsafe20",!map.valid(before,radius:20))
   s.updatePandas(0.01)
   check("arrival-enters-acting",s.pandas.count==1 && s.pandas[0].phase == .acting)
   check("arrival-root-safe",map.valid(n.position,radius:20))
   check("strike-called-after-safe-root",n.strikeCalls==1 && map.valid(n.strikeRoot,radius:20))
   check("target-not-projected",e.position==targetBefore)
   check("raw-destination-retained",s.pandas.first?.destination==targetBefore)
   check("arrival-timer-original",s.pandas.first?.timer==GameConfig.Panda.lingerDuration)
   check("no-immediate-damage",s.damageCalls.isEmpty)
   let after=n.position
   e.position=room.center;n.callback?()
   check("windup-damage-original",e.health==0 && s.damageCalls==[100])
   check("windup-cut-follows-live-mark",s.worldNode.children.contains{$0 is SKShapeNode && $0.position==e.position})
   check("windup-root-does-not-track-target",n.position==after)
   check("windup-bows-once",n.bowCalls==1)
  }
  let s=Scene(),e=enemy(s,room.center),n=actor(s,root:room.center+CGPoint(x:0.5,y:0.5),target:e),before=n.position
  s.updatePandas(0.01);check("valid-actual-kept-exact",n.position==before && n.strikeRoot==before)
 }
 for wall in map.geometry.blockedFootprints {
  for removed in [false,true] {
   let s=Scene(),e=enemy(s,map.player),n=actor(s,root:wall.center,target:e)
   let decoy=enemy(s,map.rooms[5].center)
   if removed{s.enemies.removeAll{$0 === e}}else{e.isDying=true}
   let before=n.position;s.updatePandas(0.1)
   check("lostmark-fixture-in-solid",!map.valid(before,radius:20))
   check("lostmark-bow-safe",map.valid(n.position,radius:20) && n.bowCalls==1)
   check("lostmark-no-strike",n.strikeCalls==0 && s.damageCalls.isEmpty && decoy.health==100)
   check("lostmark-no-reacquisition",s.pandas.first?.samuraiMark==nil)
   check("lostmark-lingers-original-second",s.pandas.first?.phase == .lingering && s.pandas.first?.timer==1)
  }
 }
 for connection in map.connections {
  let s=Scene(),e=enemy(s,connection.center),n=actor(s,root:connection.center,target:e),before=n.position
  s.updatePandas(0.01);check("corridor-valid-retention",n.position==before && map.valid(n.position,radius:20))
 }
}
for removed in [false,true] {
 let s=Scene(),e=enemy(s,map.player),n=actor(s,root:map.player,target:e);s.updatePandas(0.01)
 let decoy=enemy(s,map.rooms[5].center)
 if removed{s.enemies.removeAll{$0 === e}}else{e.isDying=true}
 let before=n.position;n.callback?()
 check("dead-windup-no-damage",s.damageCalls.isEmpty && decoy.health==100 && !s.worldNode.children.contains{$0 is SKShapeNode})
 check("dead-windup-bows-safe",n.bowCalls==1 && n.position==before && map.valid(before,radius:20))
}
// Dependency failure injection executes both actual callsite cancellation paths.
for lost in [false,true] {
 let s=Scene(),e=enemy(s,map.player),n=actor(s,root:map.player,target:e)
 var survivors:[PandaNode]=[]
 for _ in 1..<GameConfig.Panda.maxPandas{
  let survivor=PandaNode();survivor.position=map.rooms[1].center;s.worldNode.addChild(survivor);survivors.append(survivor)
  s.pandas.append(Scene.Panda(node:survivor,act:.pleased,phase:.lingering,timer:100,destination:survivor.position))
 }
 if lost{s.enemies.removeAll()}
 Arena8PandaDestination.rejectRequests=true;s.updatePandas(0.01);Arena8PandaDestination.rejectRequests=false
 check("failure-removes-only-visitor",s.pandas.count==GameConfig.Panda.maxPandas-1 && s.pandas.allSatisfy{p in survivors.contains{$0 === p.node}})
 check("failure-detaches-clears-actions",n.parent==nil && n.removedActions==1)
 check("failure-no-stationary-action",n.bowCalls==0 && n.strikeCalls==0 && s.actStarts==0 && s.damageCalls.isEmpty)
 check("failure-frees-cap",s.pandas.count<GameConfig.Panda.maxPandas)
}
let travel=Scene(),mark=enemy(travel,map.rooms[5].center),traveler=actor(travel,root:map.geometry.blockedFootprints[0].center,target:mark),start=traveler.position
travel.updatePandas(0.01)
check("approach-still-crosses-walls",traveler.position != start && !map.valid(traveler.position,radius:20) && traveler.strikeCalls==0)
check("tracking-raw-live-mark",travel.pandas.first?.destination==mark.position)
mark.position=map.rooms[2].center;let beforeMove=traveler.position;travel.updatePandas(0.01)
check("tracking-moving-live-mark",travel.pandas.first?.destination==mark.position)
check("original-calm-travel-speed",abs(traveler.position.distance(to:beforeMove)-GameConfig.Panda.samuraiWalkSpeed*0.01)<0.001)
for context:Arena8GameMap? in [nil,.twoRoom] {
 let s=Scene();s.debugRoomIntegration=context;let e=enemy(s,CGPoint(x:10000,y:0)),n=actor(s,root:e.position,target:e),before=n.position
 s.updatePandas(0.01);check("legacy-arrival-untouched",n.position==before && n.strikeCalls==1)
 let lost=Scene();lost.debugRoomIntegration=context;let l=actor(lost,root:CGPoint(x:10000,y:0),target:nil),old=l.position
 lost.updatePandas(0.01);check("legacy-lostmark-untouched",l.position==old && l.bowCalls==1)
}
let ordinary=Scene(),on=PandaNode();on.position=map.rooms[1].center;ordinary.worldNode.addChild(on)
var op=Scene.Panda(node:on,act:.pleased,phase:.approaching,timer:9,destination:.zero);let ob=on.position
check("nonSamurai-helper-inert",ordinary.prepareSamuraiHandoff(&op) && on.position==ob)
let priority=Scene(),normal=enemy(priority,map.player),elite=enemy(priority,map.player);normal.health=900;elite.isMiniBoss=true;elite.health=10;priority.boss=Boss()
check("priority-elite-over-boss-normal",priority.findSamuraiTarget()?.node===elite)
elite.isDying=true;check("priority-boss-over-normal",priority.findSamuraiTarget()?.node===priority.boss)
priority.boss=nil;check("priority-normal-last",priority.findSamuraiTarget()?.node===normal)
for hp in [1000,100] {
 let s=Scene(),e=EnemyNode(1000);e.health=hp;e.isMiniBoss=true;e.position=map.player;s.enemies=[e]
 let n=actor(s,root:map.player,target:e);s.updatePandas(0.01);n.callback?()
 let expected=CGFloat(hp)/1000>GameConfig.BossClass.executeThreshold ? GameConfig.BossClass.scaledDamage(Int(s.playerStats.effectiveAttack*GameConfig.Panda.samuraiCatastrophicMult),isBossClass:true):hp
 check("miniboss-original-hit",s.damageCalls==[expected])
}
let invalid=Scene(),bad=actor(invalid,root:CGPoint(x:CGFloat.nan,y:0),target:nil)
invalid.updatePandas(0.01);check("invalid-lost-root-cancels",invalid.pandas.isEmpty && bad.parent==nil && bad.bowCalls==0)
let oldRun=Scene(),oldTarget=enemy(oldRun,map.player),oldNode=actor(oldRun,root:map.player,target:oldTarget)
oldRun.updatePandas(0.01);let oldCallback=oldNode.callback;oldRun.pandas.removeAll();oldNode.removeFromParent();oldCallback?()
check("removed-visitor-callback-inert",oldRun.damageCalls.isEmpty && oldNode.bowCalls==0)
print("G20 Samurai: \(passed) passed, \(failed) failed")
exit(failed==0 ? 0:1)
