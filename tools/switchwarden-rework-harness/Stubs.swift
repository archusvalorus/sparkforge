import Foundation
import SpriteKit
enum GameConfig {}
enum DeviceScale { static var arenaRadius: CGFloat = 350; static var gameplay: CGFloat = 1 }
final class ProgressionManager {
    static let shared = ProgressionManager()
    var currentArena = 6
    var arenasUnlocked = 7
}
enum BossGrammar { case arena, monument }
struct DirectHit { let basis: Int; let dealt: Int }
class EnemyNode: SKNode { var isSnowman=false;func didStrikePlayer() {} }
final class MarchwardenNode: EnemyNode { func chargeConnected() {} }
final class ProbeStats { var effectiveCollisionRadius:CGFloat=10;var effectiveMoveSpeed:CGFloat=250 }
final class GameScene {
    enum State { case playing, paused, levelUp, dead }
    var gameState:State = .playing
    var isTwinChannels=true
    var isInvulnerable=false
    var damageCooldownTimer:TimeInterval=0
    var boss:(any ArenaBossNode)?
    var player=SKNode()
    var playerStats=ProbeStats()
    var contactDamageAttempts=0
    var bounces=0
    var damages:[Int]=[]
    var onDrain:(()->Void)?
    func drainChainReactions() { onDrain?() }
    func processTollkeeperPulses() {}
    func processRailspikeLaunches() {}
    func guardContactBounce(_ body:SKPhysicsBody) { bounces+=1 }
    func applyBossHazardDamage(_ damage:Int,shakeIntensity:CGFloat) { damages.append(damage) }
}
