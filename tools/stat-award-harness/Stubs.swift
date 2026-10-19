import SpriteKit
final class UpgradeCardNode:SKNode {
 static func emoji(for tag:UpgradeManager.Tag)->String{"•"}
 static func brightColor(hex:UInt32)->SKColor{SKColor(hex:hex)}
}
final class AudioManager {enum Cue{case levelUp};static let shared=AudioManager();func play(_ cue:Cue){}}
struct ProbeCard {
 let id="stat-probe",name="Stat probe",maxTier=1,isCapstone=false
 let tag:UpgradeManager.Tag = .neutral
 func description(forTier:Int)->String{""}
}
final class ProbeManager {
 var tagCounts:[UpgradeManager.Tag:Int]=[:]
 func drawCards(count:Int,level:Int,allowSecret:Bool=true)->[ProbeCard]{[ProbeCard()]}
 func tier(of:String)->Int{0}
 func acquire(_ card:ProbeCard,stats:PlayerStats,level:Int)->Bool{true}
 func recordDiscovered(_ cards:[ProbeCard]){}
 func checkSynergies(stats:PlayerStats)->[UpgradeManager.SynergyUnlock]{[]}
}
final class ProbePlayer {
 var currentLevel=1
 var xpProgress:CGFloat=0
 var isLevelDue=false
 func grantLevel(){currentLevel+=1}
 func updateCollisionRadius(){}
}
final class ProbeXPBar {func flashLevelUp(){};func updateFill(_ progress:CGFloat){}}
final class ProbeBuffs {func update(tagCounts:[UpgradeManager.Tag:Int]){}}
struct CardMaxReveal {let tag:UpgradeManager.Tag;let cardName:String;let effect:String;let isCapstone:Bool}
final class AwardScene:SKNode {
    // SCENE_MEMBERS
 enum State {case playing,levelUp,synergyReveal}
 let playerStats=PlayerStats(),player=ProbePlayer(),upgradeManager=ProbeManager()
 let statHUD=StatHUDNode(),hpBar=HPBarNode(width:210),xpBar=ProbeXPBar(),levelLabel=SKLabelNode()
 let levelUpOverlay=SKNode(),buffTracker=ProbeBuffs()
 var camera:SKNode?
 var levelStatPick:PlayerStats.StatKind?
 var pendingLevelCard:UpgradeCardNode?
 var levelNeedsStat=false
 var gameState:State = .playing
 var commits=0
 var cultivatedZones:[Int]=[]
 var pendingCapstones:[CardMaxReveal]=[],capstoneQueue:[CardMaxReveal]=[]
 var synergyQueue:[UpgradeManager.SynergyUnlock]=[]
 var resumeCalls=0
 func commitCard(_ card:UpgradeCardNode){commits+=1}
 func showCardSelection(_ cards:[ProbeCard]){}
 func refreshLevelUpButtons(){}
 func plantTerraGroundIfNeeded(){};func expandGarden(){};func growFlower(){};func raiseVineWall(){};func growTree(to:Int){};func modifyAllCultivatedZones(radiusScale:CGFloat){}
 func refreshKineticGauge(){};func refreshApexGauge(){};func refreshErasureGauge(){}
 func showBuildHint(_ text:String){};func presentNextReveal(){};func resumeAfterLevelUp(){resumeCalls+=1}
}
