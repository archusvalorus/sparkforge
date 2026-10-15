#!/usr/bin/env python3
"""Build the level-queue seam from the LIVE production sources (v2.2 N2 corrective, Oct 12).

usage: extract-queue.py <GameScene.swift> <PlayerNode.swift> <out.swift>

Copies, VERBATIM and at build time, the scene's level-queue functions
(resumeAfterLevelUp, stepOpenerDraft, takeNextLevel) and PlayerNode's XP &
Leveling members into two shell classes over the REAL XPLedger and the REAL
PlayerStats, with only the SpriteKit-facing members stubbed (actions, the
overlay node, the level-up screen itself, the stage start). The neutral
harness then EXECUTES the production control flow — not a copy that can
drift: a changed production function is what gets extracted next time.

The only edits made to the extracted text: a leading `private ` on a scene
member's own declaration line is dropped so the driver can call it. Everything else is byte for
byte. Exits non-zero (and prints why) if a signature is missing or a body's
braces do not balance, so a renamed function can never silently vanish from
the seam.
"""
import sys

SCENE_MEMBERS = [
    "    private func resumeAfterLevelUp() {",
    "    private func stepOpenerDraft() {",
    "    private func takeNextLevel() {",
]
PLAYER_MEMBERS = [
    "    var currentLevel: Int {",
    "    var currentXP: Int {",
    "    var levelCap: Int {",
    "    var isAtLevelCap: Bool {",
    "    func addXP(_ amount: Int) -> Bool {",
    "    var isLevelDue: Bool {",
    "    func takeDueLevel() -> Bool {",
    "    func grantLevel(keepingXP: Bool) -> Bool {",
    "    func grantLevel() {",
    "    func xpRequired(forLevel level: Int) -> Int {",
    "    var xpProgress: CGFloat {",
]


def extract(text, signature):
    """The member starting at `signature` (its line, plus a preceding @attribute line), to its closing brace."""
    lines = text.split("\n")
    starts = [i for i, l in enumerate(lines) if l.startswith(signature)]
    if len(starts) != 1:
        sys.exit(f"extract-queue: expected exactly one `{signature.strip()}`, found {len(starts)}")
    start = starts[0]
    first = start - 1 if start > 0 and lines[start - 1].strip().startswith("@") else start
    depth, end = 0, None
    for i in range(start, len(lines)):
        for ch in lines[i]:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    end = i
                    break
        if end is not None:
            break
    if end is None:
        sys.exit(f"extract-queue: braces never balance after `{signature.strip()}`")
    member = lines[first:end + 1]
    k = start - first
    if member[k].startswith("    private "):          # v2.2 N4: funcs and the ForgeOffense struct alike
        member[k] = "    " + member[k][len("    private "):]
    return "\n".join(member)


FIRE_SCENE_MEMBERS = [          # v2.2 N3: the volley's pattern and the shot's damage basis
    "    private func fireShotSpread(count: Int, baseDirection: CGPoint) {",
    "    private func shotBaseDamage(_ projectile: ProjectileNode) -> Int {",
]
PROJECTILE_MEMBERS = [          # v2.2 N3: the projectile's range, one-hit and pierce rules
    "    func move(deltaTime: TimeInterval) -> Bool {",
    "    func hasStruck(_ body: SKNode) -> Bool {",
    "    func onHitEnemy(_ body: SKNode? = nil) -> Bool {",
]


HIT_SCENE_MEMBERS = [           # v2.2 N3 corrective: the whole-shot prefix helper and the two Fracture-branch helpers
    "    private struct ForgeOffense {",                                   # v2.2 N4: the offense, once per hit, shared
    "    private func forgeOffense(healthPercent: CGFloat, bossClass: Bool,",  # by the gun's integer steps and the beam
    "    private func applyForgeOffense(_ base: Int, healthPercent: CGFloat, bossClass: Bool,",
    "    private func fractureBranch(_ hit: DirectHit, projectile: ProjectileNode) -> DirectHit {",
    "    private func fractureBranchOnBoss(_ hit: DirectHit, projectile: ProjectileNode,",
]
BEAM_SCENE_MEMBERS = [          # v2.2 N4: the chaos beam's exact parent hits (enemy, boss)
    "    private func beamParentHit(laneTick: CGFloat, hit: BeamTick.LaneHit, crit: BeamTick.LaneCrit, overcharge: CGFloat,",
    "    private func beamParentHitBoss(laneTick: CGFloat, hit: BeamTick.LaneHit, crit: BeamTick.LaneCrit, overcharge: CGFloat,",
]
BOSS_MEMBERS = ["    func challengedDamage(_ scaled: Int, raw: Int, ignoresChallengeDEF: Bool = false) -> Int {"]
CHAIN_START = "        // v2.1 A6: Warp's curve and Riftline's falloff join here (CL-70 rounding).\n        var damage = shotBaseDamage(projectileNode)\n"
ENEMY_CHAIN_END = "        damage = hit.basis\n"
BOSS_CHAIN_END = "            rounding: projectileNode.hitRounding)\n"


def segment(text, func_signature, start, end):
    """The verbatim statements of a function body from `start` to `end` (inclusive)."""
    f = extract(text, func_signature)
    i = f.find(start)
    if i < 0:
        sys.exit(f"extract-queue: `{func_signature.strip()}` has no chain start")
    j = f.find(end, i)
    if j < 0:
        sys.exit(f"extract-queue: `{func_signature.strip()}` has no chain end")
    return f[i:j + len(end)]


ENEMY_DAMAGE_MEMBERS = [        # v2.2 N5: the REAL target damage chain (both entries + the shared body)
    "    func takeDamage(_ amount: Int) -> Bool {",
    "    func takeDirectHit(_ hit: DirectHit) -> Bool {",
    "    private func takeDamage(_ amount: Int, resolved: Int?) -> Bool {",
]


def hit_shell(scene, boss, enemy):
    """v2.2 N3 corrective: the gun's two damage chains — from `shotBaseDamage`
    through the crit/execute/Forge prefix and the direct-hit block (and, on an
    enemy, the Braceguard shield and the Fracture share) — extracted VERBATIM
    from the handlers into methods over the real DirectHitDamage, PlayerStats
    and the shell projectile; the boss dial `challengedDamage` verbatim from
    ArenaBossNode. The harness composes them exactly as the handlers do."""
    members = "\n\n".join(extract(scene, s) for s in HIT_SCENE_MEMBERS + BEAM_SCENE_MEMBERS)
    enemy_chain = segment(scene, "    private func handleProjectileHit(projectileBody: SKPhysicsBody, enemyBody: SKPhysicsBody) {", CHAIN_START, ENEMY_CHAIN_END)
    boss_chain = segment(scene, "    private func handleProjectileHitBoss(projectileBody: SKPhysicsBody) {", CHAIN_START, BOSS_CHAIN_END)
    boss_members = "\n\n".join(extract(boss, s) for s in BOSS_MEMBERS)
    enemy_members = "\n\n".join(extract(enemy, s) for s in ENEMY_DAMAGE_MEMBERS)
    # Whiteout × Fracture / beam (Oct 14): the two FINAL enemy-entry statements, verbatim — the gun handler's
    # delivery and its token-pinned beam copy's (landBeamHit). Each ends at its own line.
    gun_delivery = segment(scene, "    private func handleProjectileHit(projectileBody: SKPhysicsBody, enemyBody: SKPhysicsBody) {",
                           "        let killed = enemyNode.takeDirectHit(", "\n")
    beam_delivery = segment(scene, "    private func landBeamHit(_ hit: DirectHit, damage: Int, projectileNode: ProjectileNode, enemyNode: EnemyNode) {",
                            "        let killed = enemyNode.takeDirectHit(", "\n")
    return f'''
// ── v2.2 N3 corrective: the hit-chain seam ──
/// EnemyNode as the chains read it. v2.2 N5: plus the REAL damage entries and body
/// (`takeDamage(_:)`, `takeDirectHit(_:)`, `takeDamage(_:resolved:)`, extracted verbatim
/// from Sparkforge/Nodes/EnemyNode.swift) over the node's stored state; `onDeath` and the
/// hit flash are SpriteKit visuals, modelled (onDeath sets `isDying` exactly as its first line does).
class EnemyNode: SKNode {{
    var healthPercent: CGFloat = 1
    var isMiniBoss = false
    var isSlowed = false, isFrozen = false, isStunned = false, isBleeding = false
    var vulnerabilityMultiplier: CGFloat = 1
    var health: Int = 100
    var maxHealth: Int = 100
    var isDying = false
    var killCredited = false
    var finishingDamage: Int = 0
    var snowman = SnowmanState()
    var xpValue: Int = 1
    var isSeeded = false, seedGeneration = 0
    var diedBleeding = false, killedByBleed = false, diedBleedGeneration = 0
    let bodyNode = EchoFill(), leftEye = EchoFill(), rightEye = EchoFill()
    let baseBodyHex: UInt32 = 0x222222, baseEyeHex: UInt32 = 0xFFFFFF
    private(set) var hitFlashes = 0
    init(health: Int = 100, position: CGPoint = .zero) {{ self.health = health; self.maxHealth = max(health, 1); super.init(); self.position = position }}
    override func run(_ action: SKAction) {{ hitFlashes += 1 }}
    func endSnowman(melted: Bool) {{}}
    private func onDeath() {{ isDying = true }}

    // ── EXTRACTED from Sparkforge/Nodes/EnemyNode.swift ──
{enemy_members}
}}
final class EchoFill {{ var fillColor = SKColor(hex: 0) }}
final class SKColor {{ init(hex: UInt32, alpha: CGFloat = 1) {{}}; static let white = SKColor(hex: 0xFFFFFF) }}
/// v2.2 N4: a Braceguard the beam's parent can ask (its arc is a test switch; flashes are counted).
final class BraceguardNode: EnemyNode {{
    static let shieldDamageMultiplier: CGFloat = 0.5   // mirrors Sparkforge/Nodes/BraceguardNode.swift (pinned by DX0)
    var arcBlocks = false
    private(set) var flashes = 0
    func blocksHit(from point: CGPoint) -> Bool {{ arcBlocks }}
    func flashShield() {{ flashes += 1 }}
}}
protocol ArenaBossNode: AnyObject {{
    var healthPercent: CGFloat {{ get }}
    var vulnerabilityMultiplier: CGFloat {{ get }}
    func challengedDamage(_ scaled: Int, raw: Int, ignoresChallengeDEF: Bool) -> Int
}}
/// An arena boss's dial, verbatim from Sparkforge/Nodes/ArenaBossNode.swift, over the node's real stored state.
final class ArenaBossStub: ArenaBossNode {{
    var health: Int = 100
    var healthPercent: CGFloat = 1
    var vulnerabilityMultiplier: CGFloat = 1
    var challengeFlatReduction: Int = 0
    init(health: Int = 100, def: Int = 0) {{ self.health = health; self.challengeFlatReduction = def }}

    // ── EXTRACTED from Sparkforge/Nodes/ArenaBossNode.swift ──
{boss_members}
}}
// The shared stubs' GameConfig lacks these two members the chains read; mirrored from GameConfig.swift (pinned by DX0).
extension GameConfig.ForgePath {{ static let holdLineRadius: CGFloat = 100 }}
extension GameConfig.PolarVortex {{ static let brittleColdVuln: CGFloat = 1.4 }}
final class BossStatusStub {{ final class Bleed {{ var isBleeding = false }}; final class Burn {{ func ignite(dps: CGFloat, duration: TimeInterval, source: Any, stackCap: Int, stackInterval: TimeInterval) {{}} }}; let bleed = Bleed(); let burn = Burn() }}

/// GameScene's two gun damage chains over the shell above.
final class HitScene {{
    let playerStats = PlayerStats()
    let player = SKNode()                 // v2.2 N4: the beam's Braceguard arc test reads Spark's position
    let bossStatus = BossStatusStub()
    // Forge Path state the offense helper reads (all quiet unless a test sets them).
    var forgeRisingHeatStacks = 0
    var forgeTimeSinceKill: TimeInterval = 0
    var forgeColdFuryArmed = false
    var forgeWarpathDamageTime: TimeInterval = 0
    weak var forgeRelentlessTarget: EnemyNode?
    var forgeRelentlessStacks = 0
    var forgeRelentlessTimer: TimeInterval = 0
    var forgeRelentlessStackCD: TimeInterval = 0
    var forgeKillingStrokeArmed = false
    var forgeKillingStrokeCooldown: TimeInterval = 0
    var forgeWarpathIdleTime: TimeInterval = 0
    func nearbyEnemyCount(_ radius: CGFloat) -> Int {{ 0 }}

    /// The whole-shot base (the same extracted function the fire seam runs).
    func shotBaseDamage(_ projectile: ProjectileNode) -> Int {{ FireScene.shared.shotBaseDamage(projectile, stats: playerStats) }}

    // ── EXTRACTED from Sparkforge/Scenes/GameScene.swift ──
{members}

    /// handleProjectileHit's FINAL enemy entry, verbatim (the statement after the riders' `damage = hit.basis`).
    func deliverGunHit(_ hit: DirectHit, enemyNode: EnemyNode) -> Bool {{
{gun_delivery}        return killed
    }}
    /// landBeamHit's FINAL enemy entry, verbatim (NB1 pins it token-equal to the gun's).
    func deliverBeamHit(_ hit: DirectHit, enemyNode: EnemyNode) -> Bool {{
{beam_delivery}        return killed
    }}

    /// handleProjectileHit's damage chain, VERBATIM from `var damage = shotBaseDamage` to `damage = hit.basis`.
    func resolveGunHit(projectileNode: ProjectileNode, enemyNode: EnemyNode, braceguardShielded: Bool) -> DirectHit {{
{enemy_chain}        _ = damage
        return hit
    }}

    /// handleProjectileHitBoss's damage chain, VERBATIM from `var damage = shotBaseDamage` through the block.
    func resolveGunHitBoss(projectileNode: ProjectileNode, bossNode: ArenaBossStub) -> DirectHit {{
{boss_chain}        return hit
    }}
}}
'''


def fire_shell(scene, projectile):
    """v2.2 N3: `fireShotSpread` + `shotBaseDamage` (GameScene) and `move` /
    `hasStruck` / `onHitEnemy` (ProjectileNode), verbatim, over the real
    AttackPattern, PlayerStats and VoidState. `fireProjectile` is a recorder;
    the projectile's node-only members (visual flash, warp trail) are stubs."""
    scene_members = "\n\n".join(extract(scene, s) for s in FIRE_SCENE_MEMBERS)
    node_members = "\n\n".join(extract(projectile, s) for s in PROJECTILE_MEMBERS)
    return f'''
// ── v2.2 N3: the fire seam ──
class SKNode {{ var position = CGPoint.zero; init() {{}}; func run(_ action: SKAction) {{}} }}
extension SKAction {{ static func scale(to: CGFloat, duration: TimeInterval) -> SKAction {{ SKAction() }} }}

/// ProjectileNode's range / one-hit / pierce members over the node's real stored state.
final class ProjectileNode: SKNode {{
    let direction: CGPoint
    let projectileSpeed: CGFloat
    let maxRange: CGFloat
    let unlimitedRange: Bool
    let piercesAll: Bool
    let passesTerrain: Bool
    var remainingPierces: Int
    let damageMultiplier: CGFloat
    var fractureShare: CGFloat = 1
    private var struckBodies = Set<ObjectIdentifier>()
    private(set) var distanceTraveled: CGFloat = 0
    private(set) var age: TimeInterval = 0
    private(set) var bodiesStruck = 0
    private(set) var warp: WarpCurve?
    private var warpTrail: SKShapeStub?
    let a6Rounding: A6Rounding
    var isCrit = false
    var overchargeFactor: CGFloat = 1
    var voidHit: VoidHit = .none
    let hitRounding: DirectHitRounding
    let shareRounding: DirectHitRounding
    init(direction: CGPoint, speed: CGFloat = GameConfig.Projectile.speed, range: CGFloat = GameConfig.Projectile.maxRange,
         pierces: Int = 0, damageMultiplier: CGFloat = 1, unlimitedRange: Bool = false, piercesAll: Bool = false, passesTerrain: Bool = false,
         unit: CGFloat = 0.5, hitUnit: CGFloat = 0.5, shareUnit: CGFloat = 0.5) {{
        self.direction = direction.normalized; self.projectileSpeed = speed; self.maxRange = range; self.remainingPierces = pierces
        self.damageMultiplier = damageMultiplier; self.unlimitedRange = unlimitedRange; self.piercesAll = piercesAll; self.passesTerrain = passesTerrain
        self.a6Rounding = A6Rounding(unit: unit)
        self.hitRounding = DirectHitRounding(unit: hitUnit)
        self.shareRounding = DirectHitRounding(unit: shareUnit)
    }}
    func enableWarp(_ curve: WarpCurve) {{ warp = curve }}

    // ── EXTRACTED from Sparkforge/Nodes/ProjectileNode.swift ──
{node_members}
}}
final class SKShapeStub {{ var xScale: CGFloat = 1; var alpha: CGFloat = 1 }}

/// GameScene's volley layout and shot damage basis over the real pattern and stats.
final class FireScene {{
    static let shared = FireScene()
    var playerStats = PlayerStats()
    /// Run the extracted `shotBaseDamage` against another scene's stats (the hit seam).
    func shotBaseDamage(_ projectile: ProjectileNode, stats: PlayerStats) -> Int {{
        let saved = playerStats; playerStats = stats; defer {{ playerStats = saved }}
        return shotBaseDamage(projectile)
    }}
    struct Shot {{ let direction: CGPoint; let originOffset: CGPoint; let damageScale: CGFloat; let allowModifiers: Bool; let fractureShare: CGFloat }}
    private(set) var shots: [Shot] = []
    /// The recorder standing in for GameScene.fireProjectile (its signature kept).
    func fireProjectile(direction: CGPoint, originOffset: CGPoint = .zero, damageScale: CGFloat = 1.0, allowModifiers: Bool = true,
                        rollsCrit: Bool = true, source: KillSource? = nil, fractureShare: CGFloat = 1,
                        configure: ((ProjectileNode) -> Void)? = nil) {{
        shots.append(Shot(direction: direction, originOffset: originOffset, damageScale: damageScale, allowModifiers: allowModifiers, fractureShare: fractureShare))
    }}

    // ── EXTRACTED from Sparkforge/Scenes/GameScene.swift ──
{scene_members}
}}
'''


ECHO_SCENE_MEMBERS = [          # v2.2 N4 Echo ruling (Oct 13): the beam frame, its lines and volley effects, and the shared Echo
    "    private struct BeamLine {",
    "    private func updateChaosBeam(_ dt: TimeInterval) {",
    "    private func beamLines(aim: CGPoint) -> [BeamLine] {",
    "    private func beamVolleyEffects(_ verdict: VolleyCounter.Result, lines: [BeamLine], aim: CGPoint) {",
    "    private func scheduleErasureEcho(direction: CGPoint) {",
]
FIRE_TAIL_START = "        // Modifiers fire only from primary shots — fragments/echoes don't\n"
# Ends at the next stable statement (the N3 comment that follows the Echo), so a REMOVED or MOVED Echo
# call is still extracted as written — and then caught by the EX checks — instead of breaking the build.
FIRE_TAIL_END = "        // (v2.2 N3: Fracture Shot's branches are laid out by fireShotSpread's\n"


def echo_shell(scene):
    """v2.2 N4 Echo ruling: `updateChaosBeam`, `BeamLine`, `beamLines`, `beamVolleyEffects`,
    `scheduleErasureEcho` and fireProjectile's modifier tail (from its `guard allowModifiers`
    through the Echo call, to the comment that follows it) — VERBATIM — over the real PlayerStats, BeamClock, VolleyCounter and
    AttackPattern. The scene's `run(_:)` is a recorded action clock modelling SpriteKit: a
    sequence [wait d, run block] fires its block d seconds of UNPAUSED scene time later, in the
    action phase that follows each frame's update phase (N4-R1); the scene's `isPaused` (app
    background) freezes it; gameState does not. `fireProjectile` is a
    recorder that then runs the extracted tail, so an Echo of an Echo would be scheduled if the
    production tail allowed it. Stubs: the target finder, the draw node, wells, Shadow Edge,
    the tick, the arena geometry and the edge sampler (returns a fixed point)."""
    members = "\n\n".join(extract(scene, s) for s in ECHO_SCENE_MEMBERS)
    tail = segment(scene, "    private func fireProjectile(direction: CGPoint, originOffset: CGPoint = .zero,", FIRE_TAIL_START, FIRE_TAIL_END)
    return f'''
// ── v2.2 N4 Echo ruling: the beam's virtual volley + the shared ordinary Echo ──
extension GameConfig {{
    enum Arena {{ static let radius: CGFloat = 1000 }}                                 // a test arena (the Echo origin is a stub point anyway)
    enum Geometry {{ static let projectileTravelRadius: CGFloat = 3 }}                 // mirrors GameConfig.swift (pinned by EX0)
}}
struct EchoGeometry {{ var hasBlockedGeometry = false; func segmentBlocked(_ a: CGPoint, _ b: CGPoint, travelRadius: CGFloat) -> Bool {{ false }} }}
enum PlacementSampler {{
    static var next = CGPoint(x: 0, y: 850)
    static func randomPoint(in geometry: EchoGeometry, minRadius: CGFloat, maxRadius: CGFloat, margin: CGFloat) -> CGPoint {{ next }}
}}
final class EchoBeamNode {{ var parent: AnyObject?; var isHidden = true; private(set) var draws = 0; func draw(_ segments: [(CGPoint, CGPoint)]) {{ draws += 1 }} }}
final class EchoWorld {{ func addChild(_ node: EchoBeamNode) {{ node.parent = self }} }}

final class EchoScene {{
    enum GameState {{ case playing, levelUp, paused }}
    var gameState: GameState = .playing
    /// SpriteKit's scene pause (app background): freezes the action clock.
    var isPaused = false
    let playerStats = PlayerStats()
    let player = SKNode()
    let worldNode = EchoWorld()
    let beamNode = EchoBeamNode()
    let arenaGeometry = EchoGeometry()
    var targetingIgnoresTerrain = false
    var beamClock = BeamClock()
    var beamSpreadWindow = false
    var volleyCounter = VolleyCounter()
    /// The target the finder reports (nil = nothing in reach).
    var target: CGPoint? = CGPoint(x: 0, y: 300)
    func findNearestTargetPosition() -> CGPoint? {{ target }}

    // Observations.
    struct Fired {{ let at: TimeInterval; let direction: CGPoint; let originOffset: CGPoint; let damageScale: CGFloat; let allowModifiers: Bool; let rollsCrit: Bool; let source: KillSource?; let fractureShare: CGFloat }}
    private(set) var fired: [Fired] = []
    private(set) var scheduled: [(at: TimeInterval, due: TimeInterval)] = []
    private(set) var ticks = 0, wells = 0, blackholes = 0, blades = 0
    private(set) var now: TimeInterval = 0
    private var pending: [(due: TimeInterval, block: () -> Void)] = []

    /// SKNode.run(_:) on the scene, modelled: [wait d, run block] → block at now + d (unpaused time).
    func run(_ action: SKAction) {{
        let wait = action.children.first?.waitDuration ?? action.waitDuration
        guard let block = action.children.last?.block ?? action.block else {{ return }}
        pending.append((now + wait, block)); scheduled.append((now, now + wait))
    }}
    /// One frame of the scene, in SpriteKit's documented per-frame order (SKScene.h: update, then
    /// action evaluation, then didEvaluateActions, then physics — N4-R1 correction): first the
    /// update phase behind its gate (the beam runs only while `.playing`), THEN the due action
    /// blocks — so an Echo's `.playing` guard sees any state change made during this frame's
    /// update. A paused scene (app background) does neither; a non-`.playing` state skips only
    /// the update, and the action clock keeps running.
    func frame(_ dt: TimeInterval) {{
        guard !isPaused else {{ return }}
        now += dt
        if gameState == .playing {{ updateChaosBeam(dt) }}
        let due = pending.enumerated().filter {{ $0.element.due <= now + 1e-9 }}
        pending.removeAll {{ $0.due <= now + 1e-9 }}
        for d in due {{ d.element.block() }}
    }}
    var pendingCount: Int {{ pending.count }}
    /// Due times of the actions still waiting (observation only).
    var pendingDues: [TimeInterval] {{ pending.map {{ $0.due }} }}
    /// TEST-ONLY hook (N4-R1 regression): runs inside the tick stub, i.e. during the modelled UPDATE
    /// phase, to model a state transition made by update-phase code. It does not execute a real XP
    /// pickup or modal callback; production has no such hook.
    var updateTransition: (() -> Void)?
    func beamTick(_ lines: [BeamLine]) {{ ticks += 1; updateTransition?() }}
    func spawnVoidWell(_ preset: VoidWellPreset, at point: CGPoint) {{ if preset == .blackhole {{ blackholes += 1 }} else {{ wells += 1 }} }}
    func fireShadowEdge(direction: CGPoint) {{ blades += 1 }}

    /// The recorder standing in for GameScene.fireProjectile (its signature kept); after recording
    /// it runs fireProjectile's modifier tail, extracted verbatim.
    func fireProjectile(direction: CGPoint, originOffset: CGPoint = .zero, damageScale: CGFloat = 1.0, allowModifiers: Bool = true,
                        rollsCrit: Bool = true, source: KillSource? = nil, fractureShare: CGFloat = 1,
                        configure: ((ProjectileNode) -> Void)? = nil) {{
        fired.append(Fired(at: now, direction: direction, originOffset: originOffset, damageScale: damageScale, allowModifiers: allowModifiers,
                           rollsCrit: rollsCrit, source: source, fractureShare: fractureShare))
{tail}    }}

    // ── EXTRACTED from Sparkforge/Scenes/GameScene.swift ──
{members}
}}
'''


CHAIN_SCENE_MEMBERS = [         # v2.2 N5 (R6): the kill chokepoint, the frame-end drain and one burst
    "    private func onEnemyKilled(at position: CGPoint, xpValue: Int, enemy: EnemyNode? = nil,",
    "    override func didFinishUpdate() {",
    "    private func drainChainReactions() {",
    "    private func chainReactionBurst(_ burst: ChainReaction.Burst) {",
]


def chain_shell(scene):
    """v2.2 N5 (R6): `onEnemyKilled`, `didFinishUpdate`, `drainChainReactions` and
    `chainReactionBurst` — VERBATIM — over the real PlayerStats, ChainReaction, KillSource,
    KillContext, DirectHitRounding and the hit shell's EnemyNode (whose damage entries and
    body are the real ones). Every other scene effect the chokepoint calls is a RECORDER
    (rewards, death bursts, Iceburst, Seed, Dead Circuit, the XP orb, the Codex record, the
    progression counters), so the tests can see exactly what a kill paid. The ring is a
    visual stub. Not SpriteKit, physics or the real frame loop: the test calls
    `didFinishUpdate()` where SpriteKit would."""
    members = "\n\n".join(extract(scene, s) for s in CHAIN_SCENE_MEMBERS)
    return f'''
// ── v2.2 N5: the Chain Reaction seam ──
class ChainSceneBase {{ func didFinishUpdate() {{}} }}
final class AshlingNode: EnemyNode {{ var isShard = false }}
final class RangedEnemyNode: EnemyNode {{}}
enum BestiaryFamily: Equatable {{ case melee, miniBoss }}
extension GameConfig {{ enum Ashling {{ static let shardSpawnDelay: TimeInterval = 0.15 }} }}   // mirrors GameConfig.swift (pinned by CX0)
/// Recorders for the singletons the chokepoint writes (the stubs carry no such state).
enum ChainRecord {{ static var quench = 0, coilworks = 0, mirrorwound = 0, progressionKills = 0, codex: [BestiaryFamily] = [] }}
extension ProgressionManager {{
    enum KillType {{ case melee, ranged }}
    var quenchKills: Int {{ get {{ ChainRecord.quench }} set {{ ChainRecord.quench = newValue }} }}
    var coilworksKills: Int {{ get {{ ChainRecord.coilworks }} set {{ ChainRecord.coilworks = newValue }} }}
    var mirrorwoundKills: Int {{ get {{ ChainRecord.mirrorwound }} set {{ ChainRecord.mirrorwound = newValue }} }}
    func recordKill(_ type: KillType) {{ ChainRecord.progressionKills += 1 }}
}}
extension CodexManager {{ func recordDefeat(_ family: BestiaryFamily) {{ ChainRecord.codex.append(family) }} }}
final class ChainShape {{
    var strokeColor = SKColor(hex: 0), fillColor = SKColor(hex: 0); var lineWidth: CGFloat = 0
    var position = CGPoint.zero; var zPosition: CGFloat = 0
    init(circleOfRadius: CGFloat) {{}}
    func run(_ action: SKAction) {{}}
}}
typealias SKShapeNode = ChainShape
extension SKAction {{
    static func group(_ actions: [SKAction]) -> SKAction {{ SKAction() }}
    static func fadeOut(withDuration: TimeInterval) -> SKAction {{ SKAction() }}
    static func removeFromParent() -> SKAction {{ SKAction() }}
}}
final class ChainWorld {{ private(set) var rings = 0; func addChild(_ n: ChainShape) {{ rings += 1 }}; func shake(intensity: CGFloat, duration: TimeInterval) {{}} }}

final class ChainScene: ChainSceneBase {{
    let playerStats = PlayerStats()
    var enemies: [EnemyNode] = []
    var chainReactions = ChainReaction.Queue()
    var chainRingsThisDrain = 0
    var killCount = 0
    let worldNode = ChainWorld()
    struct ArenaStub {{ var id = 6 }}
    var arenaConfig = ArenaStub()

    // Observations: what each kill paid.
    struct Orb {{ let position: CGPoint; let value: Int }}
    private(set) var orbs: [Orb] = []
    private(set) var rewards: [KillContext] = [], deathBursts: [KillContext] = []
    private(set) var iceburstCalls = 0, seedCalls = 0, wellFeeds = 0, ashlingSplits = 0, delayed = 0

    func spawnXPOrb(at position: CGPoint, value: Int) {{ orbs.append(Orb(position: position, value: value)) }}
    func resolveKillRewards(_ ctx: KillContext) {{ rewards.append(ctx) }}
    func resolveDeathBursts(_ ctx: KillContext) {{ deathBursts.append(ctx) }}
    func feedVoidWells(killAt: CGPoint) {{ wellFeeds += 1 }}
    func iceburst(at: CGPoint, generation: Int) {{ iceburstCalls += 1 }}
    func seedBurst(at: CGPoint, generation: Int) {{ seedCalls += 1 }}
    func showAshlingSplitTelegraph(at: CGPoint) {{ ashlingSplits += 1 }}
    func spawnAshlingShards(at: CGPoint) {{}}
    func bestiaryFamily(for enemy: EnemyNode) -> BestiaryFamily {{ enemy.isMiniBoss ? .miniBoss : .melee }}
    /// SKNode.run(_:completion:) — the full-credit XP orb's 0.05 s delay, run at once here.
    func run(_ action: SKAction, completion: @escaping () -> Void) {{ delayed += 1; completion() }}
    /// The test's handle on a kill: exactly the scene's chokepoint.
    func kill(_ enemy: EnemyNode, source: KillSource) {{
        onEnemyKilled(at: enemy.position, xpValue: enemy.xpValue, enemy: enemy, source: source)
    }}
    var pendingBursts: Int {{ chainReactions.count }}

    // ── EXTRACTED from Sparkforge/Scenes/GameScene.swift ──
{members}
}}
'''


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    scene = open(sys.argv[1], encoding="utf-8").read()
    player = open(sys.argv[2], encoding="utf-8").read()
    projectile = open(sys.argv[2].replace("PlayerNode.swift", "ProjectileNode.swift"), encoding="utf-8").read()
    boss = open(sys.argv[2].replace("PlayerNode.swift", "ArenaBossNode.swift"), encoding="utf-8").read()
    scene_members = "\n\n".join(extract(scene, s) for s in SCENE_MEMBERS)
    player_members = "\n\n".join(extract(player, s) for s in PLAYER_MEMBERS)
    enemy = open(sys.argv[2].replace("PlayerNode.swift", "EnemyNode.swift"), encoding="utf-8").read()
    fire = fire_shell(scene, projectile) + hit_shell(scene, boss, enemy) + echo_shell(scene) + chain_shell(scene)
    out = f'''// GENERATED by tools/neutral-harness/extract-queue.py from the LIVE sources —
// never edit; never commit. The members marked EXTRACTED are byte for byte
// Sparkforge/Scenes/GameScene.swift and Sparkforge/Nodes/PlayerNode.swift.
import Foundation
import CoreGraphics

// SpriteKit-facing stand-ins (the extracted bodies only schedule or label these).
final class SKAction {{
    // v2.2 N4 Echo: a sequence keeps its children, a wait its duration, a run its block —
    // read only by the Echo seam's scene clock; every other seam just constructs them.
    var children: [SKAction] = []
    var waitDuration: TimeInterval = 0
    var block: (() -> Void)?
    static func sequence(_ actions: [SKAction]) -> SKAction {{ let a = SKAction(); a.children = actions; return a }}
    static func fadeAlpha(to: CGFloat, duration: TimeInterval) -> SKAction {{ SKAction() }}
    static func `repeat`(_ action: SKAction, count: Int) -> SKAction {{ SKAction() }}
    static func wait(forDuration: TimeInterval) -> SKAction {{ let a = SKAction(); a.waitDuration = forDuration; return a }}
    static func run(_ block: @escaping () -> Void) -> SKAction {{ let a = SKAction(); a.block = block; return a }}
}}
class QueueNode {{
    var alpha: CGFloat = 1
    func childNode(withName name: String) -> QueueNode? {{ nil }}
}}
final class SKLabelNode: QueueNode {{
    var text: String?
    var fontSize: CGFloat = 0
}}

/// PlayerNode's XP & Leveling members over the REAL XPLedger and PlayerStats.
final class QueuePlayer {{
    var isDead: Bool = false
    weak var stats: PlayerStats?
    private var ledger = XPLedger()
    /// Observation only (the ledger is private to the node, as in production).
    var ledgerCarry: CGFloat {{ ledger.carry }}
    private(set) var levelUpVisuals = 0
    private func onLevelUp() {{ levelUpVisuals += 1 }}
    func run(_ action: SKAction, withKey key: String) {{}}

    // ── EXTRACTED from Sparkforge/Nodes/PlayerNode.swift ──
{player_members}
}}

/// GameScene's level-queue functions over the shell above.
final class QueueScene {{
    enum GameState {{ case playing, levelUp }}
    let playerStats = PlayerStats()
    let player = QueuePlayer()
    /// Every transition to `.playing` is a resume of play.
    var gameState: GameState = .levelUp {{ didSet {{ if gameState == .playing {{ playResumes += 1 }} }} }}
    var openerDraftRunning = false
    var openerDraftRemaining = 0
    var openerDraftTotal = 0
    var gauntletStageStartPending = false
    var invulnerableTimer: TimeInterval = 0
    var openerDraftInputLock: TimeInterval = 0
    let levelUpOverlay = QueueNode()

    // Observations: what the production control flow DID.
    struct Screen {{ let level: Int; let xp: Int; let carry: CGFloat; let pendingAfter: Int; let openerRemaining: Int; let openerRunning: Bool }}
    private(set) var screens: [Screen] = []
    private(set) var stageStarts = 0
    private(set) var playResumes = 0
    private(set) var stageStartedWhilePending = 0

    init() {{ player.stats = playerStats }}

    /// The level-up SCREEN itself (card + stat choice) is UI and is not run
    /// here; the shell records that it opened, for which level, and the state
    /// of the queue at that moment. Its even/odd stat cadence is
    /// `triggerLevelUp`'s own and is covered by the catalog harness.
    func triggerLevelUp() {{
        gameState = .levelUp
        screens.append(Screen(level: player.currentLevel, xp: player.currentXP, carry: player.ledgerCarry,
                              pendingAfter: playerStats.grantedLevelsPending, openerRemaining: openerDraftRemaining, openerRunning: openerDraftRunning))
    }}
    func beginGauntletStage(isFirst: Bool) {{
        stageStarts += 1
        if playerStats.grantedLevelsPending > 0 || player.isLevelDue {{ stageStartedWhilePending += 1 }}
    }}
    func run(_ action: SKAction, withKey key: String) {{}}

    // ── EXTRACTED from Sparkforge/Scenes/GameScene.swift ──
{scene_members}
}}
''' + fire
    open(sys.argv[3], "w", encoding="utf-8").write(out)
    print(f"extract-queue: {len(SCENE_MEMBERS)} scene members + {len(PLAYER_MEMBERS)} player members + fire seam ({len(FIRE_SCENE_MEMBERS)} + {len(PROJECTILE_MEMBERS)}) + hit seam ({len(HIT_SCENE_MEMBERS)} + {len(BEAM_SCENE_MEMBERS)} beam members, 2 chains, {len(BOSS_MEMBERS)} boss) → {sys.argv[3]}")


if __name__ == "__main__":
    main()
