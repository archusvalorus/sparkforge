import Foundation
import CoreGraphics
enum GameConfig {}
enum DeviceScale { static var arenaRadius:CGFloat=350; static let gameplay:CGFloat=1 }
struct ArenaConfig { let radiusScale:CGFloat; static var current=ArenaConfig(radiusScale:1.15) }
class EnemyStorage {
 var position=CGPoint.zero;var geometryFootprintRadius:CGFloat=14;var moveSpeed:CGFloat;var currentSlow:CGFloat=0
 var isDying=false,isFrozen=false,isStunned=false,isVoidTrapped=false,isFeared=false
 let health:Int;let xpValue:Int
 init(health:Int,moveSpeed:CGFloat,xpValue:Int){self.health=health;self.moveSpeed=moveSpeed;self.xpValue=xpValue}
}
final class FakeVisual { var isHidden=false }
final class EnemyProjectileNode {
 var channelRailRect:CGRect?;var position=CGPoint.zero;var zPosition:CGFloat=0
 let direction:CGPoint;let damage:Int;let speed:CGFloat;let range:CGFloat
 init(direction:CGPoint,damage:Int,speed:CGFloat,range:CGFloat,colorHex:UInt32,elongated:Bool){self.direction=direction;self.damage=damage;self.speed=speed;self.range=range}
}
final class WorldNode { var children:[EnemyNode]=[];var bolts:[EnemyProjectileNode]=[];func addChild(_ e:EnemyNode){children.append(e)};func addChild(_ b:EnemyProjectileNode){bolts.append(b)} }
final class AudioManager { enum SFX{case linekeeperAim};static let shared=AudioManager();func play(_ sfx:SFX){} }
final class Stats { var effectiveCollisionRadius:CGFloat=10 }
final class Wave { var elapsedTime:TimeInterval=0 }
final class GameScene {
 enum State{case playing,paused,levelUp,dead}
 var gameState:State = .playing;var isTwinChannelsPreview=true
 var arenaGeometry:ArenaGeometry{ArenaGeometry.twinChannels}
 var player=EnemyNode(health:100,moveSpeed:250,xpValue:0);var playerStats=Stats();var waveManager=Wave()
 var enemies:[EnemyNode]=[];var worldNode=WorldNode();var repulseFlights:[ObjectIdentifier:Bool]=[:]
 var channelTollkeeperLastSpawn:TimeInterval = -.infinity;var channelSpawnWestNext=true
 var channelRailspikeLastSpawn: TimeInterval = -.infinity
 let channelAttacks=ChannelAttackSchedule();var channelRailBolts:[EnemyProjectileNode]=[];var enemyProjectiles:[EnemyProjectileNode]=[]
 var damages:[(Int,Bool)]=[]
 func applyBossHazardDamage(_ amount:Int,shakeIntensity:CGFloat,fromBossClass:Bool){damages.append((amount,fromBossClass))}
}
