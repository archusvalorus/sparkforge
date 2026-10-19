import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ name:String,_ ok:Bool){if ok{passed+=1;print("PASS I \(name)")}else{failed+=1;print("FAIL I \(name)")}}
let defaults=TestDefaults.store
defer {defaults.removePersistentDomain(forName:TestDefaults.name)}
// A pre-Arena7 save already earned Marchwarden; no replay should be needed.
defaults.set(6,forKey:"sf_arenas_unlocked")
defaults.set(5,forKey:"sf_current_arena")
defaults.set(["marchwarden"],forKey:"sf_defeated_bosses")
let shared=ProgressionManager.shared
check("old-save Marchwarden reconciliation opens Arena7",shared.arenasUnlocked==7)
check("migration preserves menu selection and defeat record",shared.currentArena==5 && shared.hasDefeatedBoss("marchwarden") && !shared.hasDefeatedBoss("switchwarden"))
let again=ProgressionManager()
check("launch reconciliation idempotent",again.arenasUnlocked==7 && again.currentArena==5)
check("registry ids exact0through6",ArenaConfig.all.map{$0.id}==Array(0...6) && Set(ArenaConfig.all.map{$0.bossID}).count==7)
check("Switchwarden stable identity and radius",ArenaConfig.arena(forBossID:"switchwarden")?.id==6 && ArenaConfig.twinChannels.radiusScale==1.30)
shared.registerArenaBossDefeat("switchwarden")
shared.registerArenaBossDefeat("switchwarden")
check("boss defeat idempotent and no Arena8",shared.arenasUnlocked==7 && shared.defeatedBosses==Set(["marchwarden","switchwarden"]))
check("BossMode entry and home geometry",BossRegistry.shared.entry("switchwarden")?.arenaID==6 && ArenaConfig.twinChannels.geometry.blockedFootprints.count==2)
check("BossMode factory accepts HP ramp",BossRegistry.shared.entry("switchwarden")?.make(400,42).scaling==42)
check("BossMode grammar matches ordinary arena floor",GameConfig.Wave.bossTimeFloor(for:BossRegistry.shared.grammar(forArena:6))==120)
check("defeat unlocks BossMode entry",BossRegistry.shared.unlocked.contains{$0.id=="switchwarden"})
// A new or unfinished save cannot reach Arena7 through persisted selection.
defaults.removePersistentDomain(forName:TestDefaults.name)
shared.arenasUnlocked=6;shared.currentArena=6
ArenaConfig.overrideID=nil
check("locked persisted Arena7 selection clamps to Arena6",ArenaConfig.current.id==5)
ArenaConfig.overrideID=6
check("transient BossMode Arena7 uses registered geometry",ArenaConfig.current.id==6 && ArenaConfig.current.geometry.routeNodes.count==10 && shared.currentArena==6)
ArenaConfig.overrideID=nil
let unfinished=ProgressionManager()
check("unfinished save stays locked",unfinished.arenasUnlocked==6 && !unfinished.hasDefeatedBoss("switchwarden"))
check("unearned Switchwarden absent BossMode",!BossRegistry.shared.unlocked.contains{$0.id=="switchwarden"})
shared.registerArenaBossDefeat("marchwarden")
check("new Marchwarden defeat opens Arena7",shared.arenasUnlocked==7)
shared.currentArena=6
check("earned Arena7 selection resolves production",ArenaConfig.current.id==6 && ArenaConfig.current.bossID=="switchwarden")
let oldIDs=["slag_titan","quench_warden","dynamo_choir","faceted_lie","unmade_star","marchwarden"]
check("old arena and BossMode pairings preserved",Array(ArenaConfig.all.prefix(6).map{$0.bossID})==oldIDs && Array(BossRegistry.shared.all.prefix(6).map{$0.id})==oldIDs)
print("Arena7 Integration: \(passed) passed / \(failed) failed")
exit(failed==0 ? 0 : 1)
