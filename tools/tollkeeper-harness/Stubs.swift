import Foundation
import CoreGraphics
enum GameConfig {}
enum DeviceScale { static var arenaRadius:CGFloat=350; static let gameplay:CGFloat=1 }
struct ArenaConfig { let radiusScale:CGFloat;let id:Int;static var current=ArenaConfig(radiusScale:1.15,id:6);static var overrideID:Int? }
enum BossGrammar {case arena,monument}
final class BossRegistry {static let shared=BossRegistry();func grammar(forArena:Int)->BossGrammar{.arena}}
struct BossEntry {let id:String;let arenaID:Int}
final class ProbeGauntlet {var currentEntry:BossEntry?=BossEntry(id:"switchwarden",arenaID:6);var currentHPScaling=30;var stage=1;var totalStages=1}
final class BossModeDials {static let shared=BossModeDials();var hp:CGFloat=1;var flatDamageReduction=0}
struct WaveManager {struct SpawnEvent {let shouldSpawnEnemy:Bool;let shouldSpawnMiniBoss:Bool}}
final class ProgressionManager {enum Kind{case boss};static let shared=ProgressionManager();var kills=0;var defeats:[String]=[];func recordKill(_ kind:Kind){kills+=1};func registerArenaBossDefeat(_ id:String){defeats.append(id)}}
final class CodexManager {enum Family{case switchwarden};static let shared=CodexManager();var defeats=0;func recordDefeat(_ family:Family){defeats+=1}}
class EnemyStorage {
 var position=CGPoint.zero;var geometryFootprintRadius:CGFloat=14;var moveSpeed:CGFloat;var currentSlow:CGFloat=0
 var isDying=false,isFrozen=false,isStunned=false,isVoidTrapped=false,isFeared=false,isMiniBoss=false
 let health:Int;let xpValue:Int
 func setScale(_ s:CGFloat){geometryFootprintRadius=GameConfig.Enemy.visualRadius*s}
 static func spawnPosition()->CGPoint {CGPoint(x:GameConfig.Arena.radius+40,y:0)}
 init(health:Int,moveSpeed:CGFloat,xpValue:Int){self.health=health;self.moveSpeed=moveSpeed;self.xpValue=xpValue}
}
final class FakeVisual { var isHidden=false }
final class FakePhysics { var categoryBitMask:UInt32=2 }
class SKNode {var position=CGPoint.zero;var zPosition:CGFloat=0;var physicsBody:FakePhysics?=FakePhysics();var removed=false;func removeFromParent(){removed=true}}
struct DirectHit {var basis:Int;var dealt:Int}
final class EnemyProjectileNode {
 var channelRailRect:CGRect?;var position=CGPoint.zero;var zPosition:CGFloat=0
 let direction:CGPoint;let damage:Int;let speed:CGFloat;let range:CGFloat
 init(direction:CGPoint,damage:Int,speed:CGFloat,range:CGFloat,colorHex:UInt32,elongated:Bool){self.direction=direction;self.damage=damage;self.speed=speed;self.range=range}
}
final class WorldNode { func shake(intensity:CGFloat,duration:TimeInterval){};var children:[EnemyNode]=[];var bolts:[EnemyProjectileNode]=[];var bosses:[SKNode]=[];func addChild(_ e:EnemyNode){children.append(e)};func addChild(_ b:EnemyProjectileNode){bolts.append(b)};func addChild(_ b:SKNode){bosses.append(b)} }
final class AudioManager { enum SFX{case linekeeperAim};static let shared=AudioManager();func play(_ sfx:SFX){} }
final class Stats { var forgeReadRoom=false;var effectiveCollisionRadius:CGFloat=10;var effectiveMoveSpeed:CGFloat=250 }
final class Wave { var elapsedTime:TimeInterval=0 }
final class GameScene {
 enum State{case playing,paused,levelUp,dead}
 var gameState:State = .playing;var isTwinChannels=true
 var arenaGeometry:ArenaGeometry{ArenaGeometry.twinChannels}
 var player=EnemyNode(health:100,moveSpeed:250,xpValue:0);var playerStats=Stats();var waveManager=Wave()
 var enemies:[EnemyNode]=[];var worldNode=WorldNode();var repulseFlights:[ObjectIdentifier:Bool]=[:]
 var channelTollkeeperLastSpawn:TimeInterval = -.infinity;var channelSpawnWestNext=true
 var channelRailspikeLastSpawn: TimeInterval = -.infinity
 let channelAttacks=ChannelAttackSchedule();var channelRailBolts:[EnemyProjectileNode]=[];var enemyProjectiles:[EnemyProjectileNode]=[]
 var arenaConfig=ArenaConfig.current
 var eventHorizonVoided=false;var falseEndingActive=false;var isGauntlet=false;var killCount=0;var channelArrivalPending=false;var arenaBossSpawnedThisRun=false;var bossDefeatedThisRun=false;var bossHPScalingOverride:Int?
 var gauntlet:ProbeGauntlet?;var gauntletStagePending=false;var gauntletStagePendingIsFirst=false;var gauntletBossOnField=false;var gauntletTransitioning=false;var swappedTo:Int?;var advances=0
 func swapArena(to id:Int){swappedTo=id;arenaConfig=ArenaConfig(radiusScale:1.15,id:id)}
 func spawnInterBossHeals(){};func advanceGauntlet(){advances+=1};func showGauntletStageBanner(entry:BossEntry,stage:Int,of:Int){}
 var otherBossSpawns=0
 func spawnQuenchEnemy(){};func spawnCoilworksEnemy(){};func spawnMirrorwoundEnemy(){};func spawnStarAnvilEnemy(){};func spawnSplitworksEnemy(){};func spawnRangedEnemy(){};func spawnBasicMelee(elapsed:TimeInterval){}
 func spawnBoss(){otherBossSpawns+=1};func spawnQuenchWarden(){otherBossSpawns+=1};func spawnDynamoChoir(){otherBossSpawns+=1};func spawnFacetedLie(){otherBossSpawns+=1};func spawnUnmadeStar(){otherBossSpawns+=1};func spawnMarchwarden(){otherBossSpawns+=1}
 func forgeGrantMoveBuff(_ t:TimeInterval){};func showBossEntrance(name:String,colorHex:UInt32){}
 var xpDrops=0;var coins=0
 func spawnXPOrb(at:CGPoint,value:Int){xpDrops+=value};func spawnForgeCoins(at:CGPoint){coins+=1}
 var boss:(any ArenaBossNode)?;var channelSwitchwardenSpawned=false;var creditChecks=0
 var onDrain:(()->Void)?;func drainChainReactions(){onDrain?()}
 func checkBossCredited(){creditChecks+=1}
 var damages:[(Int,Bool)]=[]
 func applyBossHazardDamage(_ amount:Int,shakeIntensity:CGFloat,fromBossClass:Bool=true){damages.append((amount,fromBossClass))}
}
