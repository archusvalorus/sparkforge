import Foundation
import SpriteKit
enum GameConfig {}
enum BossGrammar { case arena, monument }
struct Insets {var top:CGFloat=0,bottom:CGFloat=0,left:CGFloat=0,right:CGFloat=0;static let zero=Insets()}
final class ProbeView {var safeAreaInsets=Insets()}
enum DeviceScale {static var isIPad=false;static var screenShort:CGFloat=375;static var ui:CGFloat{isIPad ? screenShort/390 : 1};static var gameplay:CGFloat{1};static var arenaRadius:CGFloat{350}}
enum ReviewMode {static var isActive=false}
final class ProgressionManager {
 static let shared=ProgressionManager();var forgeLevel=12;var forgeLevelProgress:CGFloat=0.45;var totalKills=12478;var arenasUnlocked=7;var currentArena=6
 func hasDefeatedBoss(_ id:String)->Bool {id != "switchwarden"}
}
final class HighScoreManager {static let shared=HighScoreManager();var totalRuns=84;var bestTimeFormatted="12:46";var bestLevel=31}
final class ForgePathManager {
 struct Branch {let icon:String};struct Summary {let branch:Branch;let count:Int}
 static let shared=ForgePathManager();var picksAvailable=2;var summary:[Summary]=[]
}
final class DailyForgeManager {struct Blessing {let icon:String;let name:String};static let shared=DailyForgeManager();var hasClaimedToday=false;var activeBlessing:Blessing?}
final class BossRegistry {static let shared=BossRegistry();var isAvailable=true}
final class IAPManager {static let shared=IAPManager();var hasRemovedAds=false}
final class UIApplication {static let shared=UIApplication();func open(_ url:URL){}}
final class MenuProbe:SKNode {
    // ACTUAL_NODES
 var size=CGSize(width:375,height:812);var view:ProbeView?=ProbeView();var layoutY:CGFloat=0
 var displayedArenaIndex=6;var arenaTextMaxWidth:CGFloat=240;var forgePathRowY:CGFloat=0;var dailyForgeRowY:CGFloat=0
 var menuScrollNodes:[(node:SKNode,baseY:CGFloat)]=[];var menuContentTopY:CGFloat=0;var menuContentBottomY:CGFloat=0;var menuScrollOffset:CGFloat=0
 var actions:[String]=[]
 func startGame(){actions.append("play")};func handleDailyForge(){actions.append("daily")};func showForgePathModal(){actions.append("path")}
 func showRemoveAdsValueModal(){actions.append("ads")};func presentCodexHub(){actions.append("codex")};func showBossModeModal(){actions.append("boss")};func showSkinPickerModal(){actions.append("skins")}
 func settingsGearHit(_ p:CGPoint)->Bool {childNode(withName:"settingsGearButton")?.calculateAccumulatedFrame().contains(p) ?? false}
 func presentSettingsMenu(){actions.append("settings")};func handleRestorePurchases(){actions.append("restore")};func presentCrossPromo(){actions.append("promo")};func handleReviewKnockTap(){actions.append("knock")}
 var removeAdsPriceText:String?="$2.99";func loadRemoveAdsPrice(){}
 static func versionFooterText()->String {"v2.2"}
 func build() {
  layoutY=min(size.height*0.30,280);displayedArenaIndex=ProgressionManager.shared.currentArena
  setupForgeGlow();setupTitle();setupTapPrompt();setupForgeLevel();setupStats();setupArenaProgress();setupDailyForge();setupSettings()
  let gear=SKLabelNode(text:"⚙");gear.fontSize=24;gear.name="settingsGearButton";gear.zPosition=30
  let insets=view?.safeAreaInsets ?? .zero;gear.position=CGPoint(x:size.width/2-insets.right-26,y:size.height/2-insets.top-34);addChild(gear)
  buildMenuScrollSet(topInset:insets.top,bottomInset:insets.bottom)
 }
    // ACTUAL_MEMBERS
}
