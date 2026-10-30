import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL \(name)")}}
for map in [Arena8GameMap.twoRoom,.sixRoom] {
 let s=ActualScene();s.debugRoomIntegration=map
 for room in map.rooms {
  for target in map.rooms where target.id != room.id {
   let orb=XPOrbNode();orb.position=room.center;orb.startVacuum();s.player.position=target.center;s.xpOrbs=[orb]
   var crossed=false,contained=true
   for _ in 0..<300 {
    let before=orb.position;s.updateXPOrbs(1.0/60)
    if map.geometry.isBlocked(orb.position,margin:XPOrbNode.visualRadius){crossed=true}
    contained = contained && map.bounds.contains(orb.position,bodyRadius:XPOrbNode.visualRadius)
    if before.distance(to:s.player.position)>12 {
     check("vacuum follows direct live target",(orb.position-before).normalized.distance(to:(s.player.position-before).normalized)<0.001)
    }
    if orb.position.distance(to:s.player.position)<1 {break}
   }
   check("vacuum reaches target",orb.position.distance(to:s.player.position)<1)
   check("vacuum remains within outer bounds",contained)
   if map.geometry.segmentBlockedExact(room.center,target.center,travelRadius:XPOrbNode.visualRadius){check("vacuum crosses actual internal wall",crossed)}
  }
 }
 let passive=XPOrbNode();passive.position=map.player;s.player.position=map.player+CGPoint(x:500,y:0);s.xpOrbs=[passive];s.updateXPOrbs(1)
 check("ordinary out-of-range orb stays still",passive.position==map.player)
 let near=XPOrbNode();near.position=map.player;s.player.position=map.player+CGPoint(x:20,y:0);s.xpOrbs=[near];s.updateXPOrbs(1.0/60)
 check("passive speed unchanged",abs(near.position.distance(to:map.player)-5)<0.001 && !near.isVacuuming)
 let route=XPOrbNode();route.position=map.rooms[0].center+CGPoint(x:0,y:150);s.player.position=map.rooms[1].center+CGPoint(x:0,y:150);s.playerStats.effectivePickupRadius=2000;s.xpOrbs=[route]
 var routeSafe=true
 for _ in 0..<600 {s.updateXPOrbs(1.0/60);routeSafe=routeSafe && map.valid(route.position,radius:XPOrbNode.visualRadius)}
 check("passive attraction retains wall-safe routing",routeSafe && route.position.distance(to:s.player.position)<30 && !route.isVacuuming)
 s.playerStats.effectivePickupRadius=80
 for corner in [CGPoint(x:map.world.minX+20,y:map.world.minY+20),CGPoint(x:map.world.minX+20,y:map.world.maxY-20),CGPoint(x:map.world.maxX-20,y:map.world.minY+20),CGPoint(x:map.world.maxX-20,y:map.world.maxY-20)] {
  let cornerOrb=XPOrbNode();cornerOrb.startVacuum();cornerOrb.position=map.player;s.xpOrbs=[cornerOrb];s.player.position=corner;s.updateXPOrbs(10)
  check("all outer corners captured",cornerOrb.position==corner && map.bounds.contains(cornerOrb.position,bodyRadius:XPOrbNode.visualRadius))
 }
 let changing=XPOrbNode();changing.startVacuum();changing.position=map.player;s.xpOrbs=[changing];s.player.position=map.rooms.last?.center ?? map.player;s.updateXPOrbs(1.0/60);let previous=changing.position;s.player.position=map.player;s.updateXPOrbs(1.0/60)
 check("live target reaim",changing.position.distance(to:s.player.position)<previous.distance(to:s.player.position))
 let clamped=XPOrbNode();clamped.startVacuum();clamped.position=map.player;s.xpOrbs=[clamped];s.player.position=CGPoint(x:map.world.maxX+1000,y:map.world.maxY+1000);s.updateXPOrbs(10)
 check("cannot lose vacuum beyond outer body bounds",map.bounds.contains(clamped.position,bodyRadius:XPOrbNode.visualRadius))
 let first=XPOrbNode(xpValue:2);s.xpOrbs=[first];let before=s.player.xp;let boosts=s.playerStats.boosts;s.handleXPCollection(orbBody:first.physicsBody);s.handleXPCollection(orbBody:first.physicsBody)
 check("collection credited once",s.player.xp==before+2 && first.collections==1 && s.playerStats.boosts==boosts+1)
 let stale=XPOrbNode(xpValue:100);s.handleXPCollection(orbBody:stale.physicsBody)
 check("unowned callback cannot mint XP",s.player.xp==before+2)
 let edge=XPOrbNode();edge.startVacuum();edge.position=map.rooms[0].center;s.xpOrbs=[edge];s.player.position=CGPoint(x:map.world.maxX-20,y:map.world.maxY-20);s.updateXPOrbs(10)
 check("long frame caps at live player",edge.position==s.player.position && map.bounds.contains(edge.position,bodyRadius:XPOrbNode.visualRadius))
}
let legacy=ActualScene();let orb=XPOrbNode();orb.position=CGPoint(x:0,y:0);orb.startVacuum();legacy.xpOrbs=[orb];legacy.player.position=CGPoint(x:700,y:0);legacy.updateXPOrbs(0.1)
check("legacy circle vacuum unchanged",abs(orb.position.x-70)<0.001)
print("Magnet real-source: \(passed) PASS / \(failed) FAIL")
exit(failed==0 ? 0:1)
