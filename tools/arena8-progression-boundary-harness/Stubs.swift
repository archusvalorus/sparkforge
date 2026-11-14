// Host-only platform/collaborator adapters. No owner defaults, SpriteKit or StoreKit.
import Foundation
import CoreGraphics
enum GameConfig {}
enum DeviceScale { static var arenaRadius: CGFloat = 350; static var gameplay: CGFloat = 1 }
enum ProbeContext {
    static let name: String = {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--suite-name"), index + 1 < args.count else {
            return "sf-a8-erasure-" + UUID().uuidString
        }
        let name = args[index + 1]
        guard name.hasPrefix("sf-a8-erasure-"), UUID(uuidString: String(name.dropFirst("sf-a8-erasure-".count))) != nil else {
            fatalError("Only a newly owned UUID-named probe suite is permitted")
        }
        return name
    }()
    static let backing: UserDefaults? = {
        guard CommandLine.arguments.contains("--private-suite") else { return nil }
        guard let value = UserDefaults(suiteName: name) else { fatalError("Private probe suite unavailable") }
        value.removePersistentDomain(forName: name)
        return value
    }()
    static let store = GameRunPreferences(backing: backing)
    static func snapshot() -> [String: Any] {
        if let backing { return backing.persistentDomain(forName: name) ?? [:] }
        return store.dictionaryRepresentation()
    }
    static func clean() { backing?.removePersistentDomain(forName: name) }
}
enum ResetCalls { static var forge = 0; static var scores = 0; static var codex = 0; static var daily = 0 }
final class PlayerStats {}
final class ForgePathManager {
    static let shared = ForgePathManager()
    func applyPathBonuses(to: PlayerStats) {}
    func resetAll() { ResetCalls.forge += 1 }
}
final class HighScoreManager { static let shared = HighScoreManager(); func resetAll() { ResetCalls.scores += 1 } }
final class CodexManager { static let shared = CodexManager(); func resetAll() { ResetCalls.codex += 1 } }
final class DailyForgeManager { static let shared = DailyForgeManager(); func resetAll() { ResetCalls.daily += 1 } }
protocol ArenaBossNode { var scaling: Int { get } }
class ProbeBoss: ArenaBossNode { var scaling: Int; init(hpScaling: Int = 0) { scaling = hpScaling } }
class BossNode: ProbeBoss {
    enum Config { case slagTitan }; static let slagTitan = Config.slagTitan
    init(config: Config, hpScaling: Int) { super.init(hpScaling: hpScaling) }
}
class QuenchWardenNode: ProbeBoss {}
class DynamoChoirNode: ProbeBoss {}
class FacetedLieNode: ProbeBoss {}
class MarchwardenNode: ProbeBoss {}
class UnmadeStarNode: ProbeBoss { init(arenaRadius: CGFloat, hpScaling: Int) { super.init(hpScaling: hpScaling) } }
class SwitchwardenNode: ProbeBoss { func applyHealthBonus(_ amount: Int) { scaling = amount } }
