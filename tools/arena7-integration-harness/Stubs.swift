import Foundation
import CoreGraphics
enum GameConfig {}
enum DeviceScale { static var arenaRadius:CGFloat=350;static var gameplay:CGFloat=1 }
enum TestDefaults {
    static let name="sf-a7-integration-"+UUID().uuidString
    static let store=UserDefaults(suiteName:name)!
}
final class PlayerStats {}
final class ForgePathManager {static let shared=ForgePathManager();func applyPathBonuses(to:PlayerStats){};func resetAll(){}}
final class HighScoreManager {static let shared=HighScoreManager();func resetAll(){}}
final class CodexManager {static let shared=CodexManager();func resetAll(){}}
final class DailyForgeManager {static let shared=DailyForgeManager();func resetAll(){}}
protocol ArenaBossNode {var scaling:Int{get}}
class ProbeBoss:ArenaBossNode {var scaling:Int;init(hpScaling:Int=0){scaling=hpScaling}}
class BossNode:ProbeBoss {enum Config{case slagTitan};static let slagTitan=Config.slagTitan;init(config:Config,hpScaling:Int){super.init(hpScaling:hpScaling)}}
class QuenchWardenNode:ProbeBoss {}
class DynamoChoirNode:ProbeBoss {}
class FacetedLieNode:ProbeBoss {}
class MarchwardenNode:ProbeBoss {}
class UnmadeStarNode:ProbeBoss {init(arenaRadius:CGFloat,hpScaling:Int){super.init(hpScaling:hpScaling)}}
class SwitchwardenNode:ProbeBoss {func applyHealthBonus(_ n:Int){scaling=n}}
