// GameConfig.swift
// Sparkforge
//
// Single source of truth for all game tuning values.
// Tweak here, not scattered across files.
//
// v1.4: Arena resize (device-aware), HP/ATK/DEF system,
// enemy damage values, health orbs, magnet orbs, boss config.

import CoreGraphics
import Foundation

enum GameConfig {

    // MARK: - Boss Mode (v2.0, Unit B2)

    /// The gauntlet: one button, bosses back-to-back, in their OWN home arenas,
    /// until you clear them all or die. Not a practice selector.
    enum BossMode {
        /// Arena bosses ramp with the stage you meet them at. The ramp does NOT
        /// compound — each stage's buff applies to that boss's own base HP.
        static let arenaRampPerStage: Double = 0.125      // +12.5% × stage

        /// Monuments are DECOUPLED from the stage ramp — flat, stage-independent.
        /// A monument's base is already multiples of an arena boss, so handing it
        /// the biggest multiplier makes a CLIFF, not a curve. Bias the wall LOW:
        /// an unbeatable final boss silently kills the mode, a too-easy one just
        /// gets buffed next patch. Asymmetric risk.
        static let monumentFlatRamp: Double = 0.25        // +25%, always

        /// Boss HP scaling in normal play is `Int(elapsed/30) * step`. Boss Mode
        /// has no elapsed-time pressure, so it converts its ramp into the same
        /// currency: rampFraction × this budget.
        static let hpScalingBudget: Double = 60

        /// Stage 1 awards 5× XP, growing +1× per stage thereafter.
        static let baseXPMultiplier: Double = 5
        static let xpMultiplierPerStage: Double = 1

        /// Beat time between a boss falling and the next arena resolving.
        static let interstitialDuration: TimeInterval = 2.4

        // --- B2b lands these; declared here so the design reads in one place ---

        /// Opener size — how many levels the gauntlet grants before boss 1.
        ///
        /// Calibrated against the XP curve, not picked by feel. Levels 2-6 cost
        /// 43 XP combined — under a fifth of one boss reward — so a level-1
        /// start meant boss 1's shower cascaded through ~10 levels at once and
        /// every later stage felt flat by comparison. Opening at level 9 puts
        /// the player roughly where a normal run MEETS the Slag Titan, which
        /// lands each boss at a steady +2 to +4 levels instead of +10 then +1.
        ///
        /// Halving the XP multiplier does NOT fix this — at 2.5x boss 1 still
        /// pays 8 levels. The starting level is the only real lever.
        static let openerCards: Int = 8
        /// HP orbs dropped between bosses — randomized; the variance is the point.
        static let interBossHealsMin: Int = 2
        static let interBossHealsMax: Int = 3
        /// Sandbox isolation: uncapped Forge XP would make Boss Mode the optimal
        /// farm and warp normal play; zero would make it pointless. This is the
        /// FULL-CLEAR reward — a run earns the share of it that it cleared.
        static let forgeXPCapPerRun: Int = 100

        /// Consolation for a gauntlet that felled nothing. Death here is final
        /// with no revives, so walking away with literally nothing is a harsh
        /// note to end on. Deliberately small — a fifth of what one boss pays,
        /// so it reads as "thanks for trying", never as a reason to farm
        /// deliberate quick losses.
        static let forgeXPConsolation: Int = 5

        // MARK: Dev-only playtest seams
        //
        // Boss Mode's lineup is gated on what the save has actually felled,
        // which makes the LATE stages — and the monument in particular —
        // expensive to reach when you only want to look at one fight. These two
        // flags open the gauntlet at any point without touching player data, so
        // a boss can be examined in its gauntlet context in seconds.
        //
        // Ship values are `false` / `1`. Both are DEBUG-only by construction:
        // release builds compile the normal path and can't read these.

        /// Offer every registered boss regardless of defeat records.
        static let debugForceFullRoster: Bool = false

        /// Open the gauntlet at this 1-based stage instead of stage 1.
        /// Clamped to the lineup, so an over-large value lands on the last boss.
        static let debugStartStage: Int = 1
    }

    // MARK: - Growth (v2.0 Phase C)
    enum Growth {
        /// Terra's starting footprint. Big enough to fight around, small enough
        /// that leaving it stays a real decision.
        static var terraRadius: CGFloat { 110 * DeviceScale.gameplay }
        /// Hard ceiling on simultaneous cultivated zones. The creative handoff
        /// warns explicitly about a "frame-rate extinction event" — Growth
        /// stacks zones, structures, projectiles and particles, so the cap is
        /// here from the first unit rather than retrofitted after a bad run.
        static let maxZones: Int = 4
        /// Enemy slow inside cultivated ground.
        static let enemySlow: CGFloat = 0.30
        /// How often ground effects tick (seconds). Damage is per-tick, so the
        /// DPS on a card means what it says.
        static let tickInterval: TimeInterval = 1.0

        /// Terra's baseline nourishment: Spark regains this much HP for every
        /// `regenInterval` seconds spent standing on cultivated ground.
        ///
        /// Deliberately a trickle. It has to be felt without stepping on the
        /// Tree capstone's T3 "Shelter" tier, whose whole job is to make the
        /// ground genuinely restorative — T3 must scale clearly above this or
        /// the capstone rung stops landing.
        static let baseRegenHP: Int = 1
        static let regenInterval: TimeInterval = 10.0

        /// Path A: every Growth card AFTER Terra grows the garden by this
        /// fraction of its current radius. The expansion is the universal
        /// Growth heartbeat — structure cards add their payload on top.
        static let expansionPerCard: CGFloat = 0.16
        /// The garden is capped at this fraction of the arena radius. If it
        /// could swallow the whole floor, "leaving cultivated ground stays a
        /// real decision" (handoff §8) dies — the tension IS the tradeoff.
        static let maxZoneRadiusFactor: CGFloat = 0.55

        // --- Defensive Flowers (C1.3) — structures ROOTED to the ground ---
        /// Hard ceiling on live flowers. Permanent-up-to-cap: they never expire,
        /// so the cap is what keeps a Growth build from becoming an AFK turret
        /// farm (handoff §8).
        static let maxFlowers: Int = 3
        /// A flower's shot as a fraction of a normal player shot (~25% ATK).
        static let flowerDamageFraction: CGFloat = 0.25
        /// Seconds between a flower's shots.
        static let flowerFireInterval: TimeInterval = 1.4
        /// A flower only engages targets within this reach.
        static var flowerRange: CGFloat { 240 * DeviceScale.gameplay }

        // --- Seed Spore Shot (C1.4) — embed → kill → reproduce ---
        static let seedFragmentsT1: Int = 3      // burst count at tier 1
        static let seedFragmentsT2: Int = 5      // tier 2: more seeds
        static let seedFragmentsT3: Int = 6      // tier 3: more still, and re-embed
        /// A burst fragment's damage as a fraction of a normal shot.
        static let seedFragmentDamage: CGFloat = 0.30
        /// Fragments fly farther at T2+ (a shorter base range keeps T1 local).
        static var seedFragmentRange: CGFloat { 150 * DeviceScale.gameplay }
        static let seedFragmentRangeT2Mult: CGFloat = 1.6

        // --- Vine Wall (C1.5) — a thorny hedge around the garden ---
        // Rooted to Terra: the wall is the garden's own perimeter, not a loose
        // placeable barrier. Zone-based fallback (Brandon's call): it heavily
        // SLOWS and REPELS normal enemies crossing in; bosses/elites pass.
        /// Band around a zone's edge where the hedge acts, as a fraction of radius.
        static let vineBandFraction: CGFloat = 0.16
        /// Heavy slow applied inside the band (vs the ambient 30% ground slow).
        static let vineSlow: CGFloat = 0.65
        /// Outward shove per second on a normal enemy in the band (points/s).
        static var vineRepel: CGFloat { 90 * DeviceScale.gameplay }
        static let vineRepelT2Mult: CGFloat = 1.5
        /// T3: the hedge also catches enemy projectiles crossing it.
        static let vineBlocksProjectiles = true
    }

    // MARK: - The Tree (Growth capstone, C1.6)
    enum Tree {
        /// Move-speed bonus while standing on cultivated ground (T2 Rootreach).
        static let moveBonusT2: CGFloat = 0.15
        /// HP regenerated per `regenInterval` on cultivated ground (T3 Shelter).
        /// Clearly above Terra's baseline (1 HP / 10s) so the tier lands.
        static let regenHPT3: Int = 3
        static let regenInterval: TimeInterval = 4.0
        /// The garden grows as the Tree matures (fraction of current radius).
        static let growthT1: CGFloat = 0.10   // Sapling settles in
        static let growthT2: CGFloat = 0.15   // Rootreach
        static let growthT4: CGFloat = 0.35   // Wild Domain — substantial

        // --- T5 The Forest Wakes: the animal launcher ---
        /// Cadence of launches. Shown on the CapstoneTimerHUD.
        static let animalInterval: TimeInterval = 4.5
        /// Base damage as a fraction of Spark's effective ATK (~150%).
        static let animalDamageMult: CGFloat = 1.5
        /// Chance a launch is the RARE mountain-lion PET instead of a projectile.
        static let lionChance: CGFloat = 0.06
        static let lionDuration: TimeInterval = 10.0
        /// How wide the pet renders. The jackpot should read as a BEAST next to
        /// the launched animals, not as another one of them.
        static let lionSize: CGFloat = 76
        /// Union-box width ÷ standing-body width across the lion's frames.
        static let lionFrameBoxRatio: CGFloat = 1.040
        static var lionSpeed: CGFloat { 210 * DeviceScale.gameplay }
        /// Lion contact damage per maul, as a fraction of Spark's ATK.
        static let lionMaulMult: CGFloat = 0.6
        /// Seconds between mauls. Before this existed the lion dealt its maul on
        /// EVERY frame of contact — "per maul" was ~60× per second. If the pet
        /// now feels toothless, raise `lionMaulMult`; don't remove the cooldown.
        static let lionMaulInterval: TimeInterval = 0.45
        /// Contact reach (a boss's targetingRadius is added on top).
        /// Contact reach (a boss's targetingRadius is added on top).
        ///
        /// Tracks `lionSize`: at 76pt across the pet's body radius is ~38, so a
        /// 26pt reach meant enemies could stand visibly ON the lion without
        /// being mauled. When a body grows, what it can touch has to grow with
        /// it — a hitbox that disagrees with the art reads as a bug, not as
        /// balance.
        static var lionMaulReach: CGFloat { 44 * DeviceScale.gameplay }
    }

    // MARK: - Nature Canon (the Tree T5 roster — v2.0 Phase C part 2)
    /// Per-animal tuning for the launcher's roster. The BASE machine stays in
    /// `Tree` above (cadence, the ~150% damage mult, the lion's own numbers);
    /// everything here is what makes one animal differ from another.
    ///
    /// Read the multipliers as "on top of Tree.animalDamageMult", so a mult of
    /// 1.0 is the roster's baseline ~150% of Spark's ATK.
    enum NatureCanon {
        // --- Tier weights (Brandon, locked) ---
        // Normalized at roll time, so these are RATIOS, not percentages that
        // must sum to 1.
        static let weightCommon: CGFloat   = 0.50
        static let weightUncommon: CGFloat = 0.25
        static let weightRare: CGFloat     = 0.15
        static let weightLion: CGFloat     = 0.05

        /// How wide a launched animal renders.
        ///
        /// v2.0 art pass (Brandon, Jul 27): 26 -> 50. Comically oversized next to
        /// a 32pt Spark, which is the joke, and — more practically — 26pt is
        /// roughly 78 pixels at @3x, which cannot carry enough silhouette for a
        /// player to tell a rabbit from a badger. The size ladder is deliberately
        /// set BEFORE any art is drawn, so the sprites are commissioned against a
        /// footprint that's already been felt in play.
        ///
        /// Ladder (points across, iPhone): Spark 32 · animal 50 · lion and
        /// ordinary panda 76 · kaiju 96.
        static let bodySize: CGFloat = 50

        /// Per-animal width. Sized RELATIVE to each other around the 50pt
        /// average rather than uniformly (Brandon): a boar and a bluebird at
        /// identical width would flatten the roster, and the bluebird's entire
        /// gag is that the smallest body delivers the biggest blast. Same total
        /// presence, much funnier distribution.
        static func bodyWidth(for id: String) -> CGFloat {
            switch id {
            case "bluebird": return 34
            case "squirrel", "hedgehog": return 44
            case "skunk", "rabbit": return 46
            case "badger": return 52
            case "fox": return 58
            case "deer": return 62
            case "boar": return 64
            default: return bodySize
            }
        }

        // --- 🐰 Rabbit "Ninja Kick" ---
        /// The rabbit AUTO-CRITS, and its crit is worth 300% rather than the
        /// normal 200% — so the kick lands at 1.5 × 3.0 ≈ 450% of Spark's ATK on
        /// a single target. Deliberately ridiculous (a ninja assassin rabbit);
        /// this is the number NOT to quietly balance away.
        static let rabbitCritMult: CGFloat = 3.0
        /// A shorter flight than the rest of the roster — an assassin snaps in.
        static let rabbitFlight: TimeInterval = 0.28

        // --- 🐿️ Squirrel "Scatter" ---
        /// The squirrel's own landing is modest; its payload is the acorns.
        static let squirrelImpactMult: CGFloat = 0.7
        static let squirrelRadiusMult: CGFloat = 0.9
        static let acornCount: Int = 5
        /// An acorn as a fraction of a normal player shot (the Seed Spore
        /// fragment precedent — it rides the same projectile pipeline).
        static let acornDamageFraction: CGFloat = 0.35
        static var acornRange: CGFloat { 165 * DeviceScale.gameplay }

        // --- 🦊 Fox "Homing Fur-Missile" ---
        /// It stays a fox: it doesn't arc to a spot, it CHASES. The steering
        /// blend below is the reusable homing primitive (Panda samurai next).
        static var foxSpeed: CGFloat { 300 * DeviceScale.gameplay }
        /// How hard it turns toward its mark each second. High enough to catch a
        /// runner, low enough that it visibly arcs instead of snapping.
        static let foxTurnRate: CGFloat = 7.0
        /// How close counts as arrival (added to a boss's targetingRadius, so a
        /// monument's surface counts rather than its far-off origin).
        static var foxImpactDistance: CGFloat { 26 * DeviceScale.gameplay }
        /// Failsafe: a missile whose mark dies mid-flight detonates instead of
        /// flying forever.
        static let foxLifetime: TimeInterval = 3.0
        static let foxImpactMult: CGFloat = 1.1
        static let foxRadiusMult: CGFloat = 1.2

        // --- 🦌 Deer "Trample" ---
        /// ~220% of Spark's ATK once the launcher's 1.5× is applied.
        static let deerDamageMult: CGFloat = 1.47
        static var deerKnockback: CGFloat { 54 * DeviceScale.gameplay }

        // --- 🦫 Boar "BOAR GORE!" ---
        /// Per-enemy damage as it barrels through. Lower than the Deer's single
        /// hit because a good charge line collects a whole crowd.
        static let boarDamageMult: CGFloat = 0.9
        static var boarSpeed: CGFloat { 460 * DeviceScale.gameplay }
        /// How wide the charge's goring band is.
        static var boarGoreRadius: CGFloat { 34 * DeviceScale.gameplay }
        /// Sideways shove per enemy gored (applied once, not per frame).
        static var boarShove: CGFloat { 40 * DeviceScale.gameplay }
        /// Long enough to cross the arena and exit the far side.
        static let boarLifetime: TimeInterval = 2.2

        // --- 🦔 Hedgehog "Needle Barrage" ---
        static let hedgehogDuration: TimeInterval = 3.0
        /// Fires at this multiple of Spark's CURRENT attack speed.
        static let hedgehogFireRateMult: TimeInterval = 5.0
        /// Each needle as a fraction of a normal shot — spectacle over damage.
        static let hedgehogNeedleDamage: CGFloat = 0.65
        static var hedgehogRange: CGFloat { 260 * DeviceScale.gameplay }

        // --- 🐦 Bluebird "WTFROFLSTOMP" ---
        /// ~350% of Spark's ATK once the launcher's 1.5× is applied.
        static let bluebirdDamageMult: CGFloat = 2.33
        /// ~3× the AREA of a starting Terra zone — so √3 × its radius. Big, and
        /// deliberately still short of an Everglow eruption.
        static var bluebirdRadius: CGFloat { Growth.terraRadius * 1.732 }

        // --- 🦡 Badger "Thief" ---
        static let badgerMeals: Int = 3
        static var badgerRadius: CGFloat { 120 * DeviceScale.gameplay }
        /// Heal as a fraction of a devoured normal mob's HP. THE tuning lever if
        /// a dense crowd turns the badger into a full heal — drop this, not the
        /// meal count (three is the flavour).
        static let badgerHealFraction: CGFloat = 1.0
        /// What a bite costs a boss-class target it can't swallow.
        static let badgerBiteMult: CGFloat = 1.6

        // --- 🦨 Skunk "Persist" — the propagating poison ---
        static var skunkRadius: CGFloat { 82 * DeviceScale.gameplay }
        static let skunkDuration: TimeInterval = 6.0
        static let skunkTickInterval: TimeInterval = 0.5
        /// Damage per tick as a fraction of Spark's ATK. At a 0.5s tick this is
        /// ~60% ATK per second — potent, and clearly above burn or bleed, which
        /// is what the poison is supposed to be. THE damage lever.
        static let skunkTickFraction: CGFloat = 0.30
        /// Propagation leash #1 — how many generations deep a chain may go.
        /// 0 is the skunk's own cloud, so 3 means three inherited hops.
        static let skunkMaxGeneration: Int = 3
        /// Propagation leash #2 — a hard ceiling on live clouds, the frame-rate
        /// backstop independent of depth.
        static let skunkMaxClouds: Int = 12
        /// Children are smaller and shorter-lived than their parent, so a chain
        /// visibly runs out of steam even before it hits the caps.
        static let skunkChildRadiusFactor: CGFloat = 0.72
        static let skunkChildLifeFactor: TimeInterval = 0.75

        // --- Shared impact ---
        /// Baseline AoE footprint of a landing animal, before its radius mult.
        static var impactRadius: CGFloat { 46 * DeviceScale.gameplay }
    }

    // MARK: - The false ending (v2.0, Arena 5)
    enum FalseEnding {
        /// How long "THE FORGE IS QUIET" holds after Mote has had his chance,
        /// before the run resolves into the standard result screen.
        ///
        /// Long enough that the silence still lands as a beat; short enough that
        /// it never becomes the limbo it used to be, where the card hung forever
        /// waiting for a Mote that 10,000 kills hadn't earned yet.
        static let cardHold: TimeInterval = 3.2
    }

    // MARK: - Panda. (v2.0 C2)
    /// The secret tree. Numbers only — nothing here explains anything, and the
    /// player never sees any of it.
    enum Panda {
        static let cardID = "v20_panda"

        /// The run-mutation roll. LOCKED at 9.27% (Brandon): erratic on purpose.
        /// Not 10%. Not 9%. Do not round it.
        static let eligibilityChance: CGFloat = 0.0927
        /// Levels at which the first offer may appear. Early enough that a
        /// player who commits can still climb all the way to T5.
        static let firstOfferWindow: ClosedRange<Int> = 2...5

        #if DEBUG
        /// DEV SEAM — force every run Panda-eligible. Iterating against a 9.27%
        /// roll is not iterating. An active seam paints a badge in the run HUD;
        /// remember to reinstall the sim after switching it back off, or you'll
        /// be feel-testing a stale build. (Release never compiles this.)
        static let debugAlwaysEligible: Bool = false
        #endif

        // --- T1 "Pandas." — a panda wanders in and does one mildly useful thing
        /// Seconds between arrivals, per tier. Long at T1: a panda is an event,
        /// not a pet. Tightens as the rungs climb — "more frequent, more
        /// proactive" is most of what T2 actually is.
        static func arrivalInterval(tier: Int) -> TimeInterval {
            switch tier {
            case ...1: return 9.0
            case 2:    return 6.5
            case 3:    return 5.5
            case 4:    return 4.5
            default:   return 4.0
            }
        }
        /// How long a panda hangs around after doing its one thing.
        static let lingerDuration: TimeInterval = 3.5
        static var walkSpeed: CGFloat { 74 * DeviceScale.gameplay }
        /// How wide an ordinary panda renders. Same footprint as the mountain
        /// lion: both are "a large animal has wandered in", and both are more
        /// than twice Spark, which is most of the comedy.
        static let bodyWidth: CGFloat = 76
        /// Union-box width ÷ standing-body width for the ordinary panda frames.
        /// Frames share one crop box so nothing shifts between them; the box is
        /// wider than the body, so scale by this and the BODY lands on 76pt.
        static let frameBoxRatio: CGFloat = 1.048
        /// Same idea for the samurai, whose union box is wider because the
        /// overhead sword raise reaches well past the standing silhouette.
        static let samuraiFrameBoxRatio: CGFloat = 1.198
        /// Ceiling on live pandas, per tier growth and for frame rate.
        static let maxPandas: Int = 6

        /// A roll's damage as a fraction of Spark's ATK, and how far it travels.
        static let rollDamageMult: CGFloat = 0.55
        /// Tracks `bodyWidth`: a 76pt panda has a ~38pt body radius, so these
        /// contact radii scale with it. A panda that visibly rolls THROUGH an
        /// enemy without touching it looks broken, however correct the number
        /// was before the body grew.
        static var rollRadius: CGFloat { 38 * DeviceScale.gameplay }
        static var rollDistance: CGFloat { 150 * DeviceScale.gameplay }
        static var rollSpeed: CGFloat { 320 * DeviceScale.gameplay }
        /// A sitting panda eats enemy shots that hit it.
        static var sitRadius: CGFloat { 36 * DeviceScale.gameplay }
        /// A briefly-interesting panda pulls nearby enemies toward it.
        static var aggroRadius: CGFloat { 170 * DeviceScale.gameplay }
        static let aggroDuration: TimeInterval = 2.2
        static var aggroPull: CGFloat { 60 * DeviceScale.gameplay }

        // --- T2 "Panda!" ---
        static let bodyCheckDamageMult: CGFloat = 0.9
        static var bodyCheckKnockback: CGFloat { 70 * DeviceScale.gameplay }

        // --- T3 "Panda...?" ---
        /// How long the second panda in a stack stays up there.
        static let stackLinger: TimeInterval = 4.0
        /// How long a panda shadows an elite without doing anything about it.
        static let followDuration: TimeInterval = 6.0
        /// Stalks per bamboo shower. Exactly one of them is a real pickup — the
        /// rest are set dressing, which is the joke.
        static let rainStalks: Int = 5

        // --- T4 "Panda." ---
        static let pinDuration: TimeInterval = 3.5
        static let napDuration: TimeInterval = 6.0
        static var napRadius: CGFloat { 92 * DeviceScale.gameplay }
        static let napHealInterval: TimeInterval = 1.5
        static let napHealHP: Int = 2
        /// How many pandas are in a badly-coordinated avalanche, including the
        /// one that started it.
        static let avalanchePandas: Int = 4

        // --- The Panda Samurai ---
        /// It appears at T4. It is 5%. That is the whole trigger, it is not
        /// conditional on anything, and if the Internet works it out we change
        /// the backend logic rather than confirm it.
        static let samuraiMinTier: Int = 4
        static let samuraiChance: CGFloat = 0.05
        /// It never hurries.
        static var samuraiWalkSpeed: CGFloat { 46 * DeviceScale.gameplay }
        /// What a strike does to something the execute rules won't let it
        /// delete. Catastrophic, not fatal.
        static let samuraiCatastrophicMult: CGFloat = 14.0

        // --- T5 "PANDA." — the kaiju ---
        /// How long Spark stops being Spark.
        static let kaijuDuration: TimeInterval = 10.0
        /// The clock between transformations. Long: it has to stay an event.
        static let kaijuInterval: TimeInterval = 45.0
        /// How much bigger. This is a visual + reach change only — the physics
        /// body is untouched, so the collision world never shifts underfoot.
        static let kaijuScale: CGFloat = 3.0
        /// Union-box width ÷ standing-body width across the frame set.
        ///
        /// Animation frames are cropped to a SHARED box so nothing shifts
        /// between them, and that box is wider than the body because action
        /// poses reach past the standing silhouette. Scaling the box by this
        /// ratio puts the BODY on the ladder's 96pt instead of the box, so the
        /// creature is the size it was tuned to be and the swing gets its room.
        static let kaijuFrameBoxRatio: CGFloat = 1.089
        /// Contact reach while transformed.
        static var kaijuReach: CGFloat { 96 * DeviceScale.gameplay }

        // --- The rampage (Brandon, Jul 26) ---
        // A kaiju does not fire a gun. While transformed, Spark STOPS shooting
        // and commits entirely to melee: an ambient fire aura for everything
        // standing too close, and a heavy periodic strike that's the actual
        // punch. Two rhythms instead of one uniform tick, so it reads as a
        // rampage rather than a damage field with a big sprite on it.

        /// The aura: ambient, frequent, low per-tick. This is the cost of being
        /// NEAR a kaiju, not the reason to fear one.
        static let kaijuAuraInterval: TimeInterval = 0.5
        static let kaijuAuraMult: CGFloat = 1.5
        /// How much a kaiju SLOWS. Something this size sprinting at Spark's
        /// normal pace looks like a scaling bug, not a monster.
        static let kaijuMoveScale: CGFloat = 0.7
        /// The strike: rare, telegraphed, enormous. This is the reason.
        static let kaijuMeleeInterval: TimeInterval = 2.5
        static let kaijuMeleeMult: CGFloat = 3.5
        /// A swipe lands across an arc, not on one target — a kaiju connecting
        /// with exactly one enemy would look absurd.
        static var kaijuMeleeReach: CGFloat { 108 * DeviceScale.gameplay }
        /// What boss-class takes from a strike — heavy STAGGER, never deletion.
        static let kaijuStaggerMult: CGFloat = 2.6
        static var kaijuKnockback: CGFloat { 90 * DeviceScale.gameplay }
        /// Incoming damage is mostly irrelevant while transformed. Applied
        /// outside the Forge Path DR cap on purpose.
        static let kaijuDamageReduction: CGFloat = 0.85

        /// How long the panda that witnessed the revert stays, eating.
        static let witnessLinger: TimeInterval = 6.0
        /// Ordinary pandas left milling around afterwards.
        static let afterKaijuPandas: Int = 3
    }

    // MARK: - Card Drafting (v2.0 Phase C)
    enum Drafting {
        /// A GATEWAY card (one that unlocks a whole pool — Terra) is guaranteed
        /// a slot if it hasn't been offered for this many level-ups.
        ///
        /// Needed because `drawCards` weights trees by how many cards they still
        /// have: a brand-new tree with one draftable card surfaces ~5% of the
        /// time, so Terra appeared about once every 20 levels and the Growth
        /// tree was effectively unreachable. A gateway you can't find is a tree
        /// that doesn't exist.
        static let gatewayPityLevels: Int = 3

        /// v2.0 (E1, Brandon): COLOURS per run. Neutral is always in and is not
        /// a colour, so a run draws from this many trees + Neutral.
        ///
        /// Seven tagged trees plus Neutral spread a 3-card spread too thin —
        /// Terra surfaced once in a whole run, which is a tree that effectively
        /// doesn't exist. This is the structural fix, and it's the lever that
        /// keeps working as more trees ship: expressed as ACTIVE COLOURS rather
        /// than as "how many we exclude", so the pool stays the size it was
        /// tuned at no matter how many trees exist to exclude from.
        static let activeColorFamilies: Int = 5

        /// v2.0 (E3, Brandon): how many arenas a save must have unlocked before
        /// a tree joins the draft at all.
        ///
        /// Two jobs. It PACES the game — a new player meets six trees, not
        /// nine, and each new arena hands them something genuinely new to learn.
        /// And it keeps the colour cap meaningful as the roster grows: without
        /// unlocks, every future tree would dilute the early game it was never
        /// designed for.
        ///
        /// Growth goes first (Brandon): it arrives with Arena 5, the version it
        /// shipped in. The original six are the game you learn on and stay at 1.
        ///
        /// A tree gated here is invisible, not greyed — it should be a discovery,
        /// not a locked door you stare at for ten hours.
        static func unlockArena(for tag: UpgradeManager.Tag) -> Int {
            switch tag {
            case .growth:  return 5
            case .fire, .shock, .bleed, .guardT, .voidT, .chill, .neutral: return 1
            }
        }
    }

    // MARK: - Arena
    enum Arena {
        /// Radius of the circular arena in points — device-aware.
        /// v1.8 (Unit 11): folds in the selected arena's radiusScale so a
        /// bigger playfield (e.g. the Mirrorwound) flows to every consumer —
        /// player clamp, spawn distance, boss positioning, orb scatter — from
        /// one place. Arena is fixed for a run, so this is stable per-run.
        static var radius: CGFloat { DeviceScale.arenaRadius * ArenaConfig.current.radiusScale }
        /// Color of the arena floor
        static let floorColorHex: UInt32 = 0x1A1A1A
        /// Color of the arena boundary ring
        static let boundaryColorHex: UInt32 = 0x3A1A0A
        /// Boundary ring line width
        static let boundaryLineWidth: CGFloat = 3.0
        /// How much beyond the boundary the player is pushed back
        static let boundaryPushback: CGFloat = 2.0
    }
    
    // MARK: - Player
    enum Player {
        /// Player movement speed in points per second
        static let speed: CGFloat = 250
        /// Visual radius of the player spark
        static let visualRadius: CGFloat = 16
        /// Collision radius — smaller than visual for forgiving hitbox
        static let collisionRadius: CGFloat = 10
        /// Base glow intensity (scales with level)
        static let baseGlowWidth: CGFloat = 8
        /// Core color
        static let coreColorHex: UInt32 = 0xFFAA33
        /// Glow color
        static let glowColorHex: UInt32 = 0xFF6600
        
        // v1.4: HP System
        /// Starting max HP
        static let baseMaxHP: Int = 100
        /// Starting ATK (base projectile damage)
        static let baseAttack: Int = 10
        /// Starting DEF (flat damage reduction)
        static let baseDefense: Int = 0
        /// Invulnerability frames after taking damage (seconds)
        static let damageCooldown: TimeInterval = 0.5
    }

    // MARK: - Everglow (v1.9 Fire capstone)
    /// The player becomes a persistent close-range heat source whose rage
    /// escalates through damage taken, culminating in periodic eruptions.
    /// v1.9 Polar Vortex (Chill capstone) — carry the storm, freeze to the soul.
    enum PolarVortex {
        // T1 Iceburst — frozen enemies that die burst into ice shards.
        static let iceburstShardsT1: Int = 3
        static let iceburstShardsT2: Int = 5
        static let iceburstShardsT5: Int = 7   // shots slow at T4, so the spread widens
        static let shardMult: CGFloat = 0.15       // 15% ATK per shard
        // T2 Brittle Cold
        static let brittleColdVuln: CGFloat = 1.4  // +40% damage vs slowed/frozen/stunned
        // T3 Windchill — a cold storm follows the player, stacking Chill.
        static let windchillInterval: TimeInterval = 1.0   // 1 Chill stack/s
        static var windchillRadius: CGFloat { 130 * DeviceScale.gameplay }
        static let windchillRadiusT5Mult: CGFloat = 2.1    // storm ×2.1 at T5 (broad, not full-arena)
        // v2.0 (Brandon, Jul 24): the storm now also SLOWS what stands in it —
        // "entering the vortex" should immediately cost the enemy tempo, not
        // just tick Chill toward a far-off freeze.
        static let windchillSlow: CGFloat = 0.30
        // Gale winds — bigger, faster, more frequent swooshes (Brandon).
        static let galeInterval: TimeInterval = 0.055     // was 0.11 — ~2× denser
        static let galeSpeedMin: CGFloat = 55             // was 28
        static let galeSpeedMax: CGFloat = 100            // was 52
        // T4 Glacial Condensation — every 3 shots condense into one icicle.
        static let glacialEveryN: Int = 3
        static let icicleMult: CGFloat = 2.0       // 200% ATK
        static let icicleShards: Int = 3
        static let icicleShardMult: CGFloat = 0.30 // double a normal Iceburst shard
        // T5 Polar Vortex — Chill → freeze → frostbite.
        static let freezeStacks: Int = 5
        static let freezeDuration: TimeInterval = 3.0
        static let frostbiteDuration: TimeInterval = 4.0
        static let frostbiteVuln: CGFloat = 2.0    // +100% damage taken (boss-class reduced)
    }

    /// v1.9 Erasure (Void capstone) — destabilize reality, accept the final cost.
    enum Erasure {
        // T1 Unstable — EVERY player hit (any target) charges a global meter;
        // at capacity + off an internal CD, one random effect from the 7-entry
        // table fires at the nearest foe. Reuses StackGaugeNode.
        static let unstableGaugeCapacity: Int = 4         // hits to charge the meter
        static let unstableStackCooldown: TimeInterval = 0.15  // rate-limit the fill
        static let unstableTriggerCooldown: TimeInterval = 2.0 // internal CD between events
        static let unstableTriggerCooldownT2: TimeInterval = 1.2  // faster chaos at T2
        static var effectRadius: CGFloat { 110 * DeviceScale.gameplay }  // shared AoE reach
        static let implosionPull: CGFloat = 55           // Implosion gather force
        static let riftBurstMult: CGFloat = 1.0          // Rift Burst: 100% ATK void burst
        static let phaseLockDuration: TimeInterval = 1.0 // immobilize normals
        static let phaseLockBossSlow: CGFloat = 0.5      // slow boss-class instead
        static let damageEchoFraction: CGFloat = 0.6     // Damage Echo: repeat 60% of the hit
        static let damageEchoDelay: TimeInterval = 0.35
        static let displacementDistance: CGFloat = 85    // Displacement: shove the target
        static let fractureVulnerability: CGFloat = 1.4  // Fracture: +40% damage taken (brief)
        static let fractureDuration: TimeInterval = 3.0
        static let backwashCount: Int = 6                // Backwash void-shard burst
        static let backwashMult: CGFloat = 0.3
        // T3 Rift Cannon — every Nth activation, an arena rift fires a beam.
        static let riftCannonEveryN: Int = 3
        static let riftCannonMult: CGFloat = 3.0         // 300% ATK along the beam
        static var riftCannonWidth: CGFloat { 46 * DeviceScale.gameplay }
        // T4 Echo — Void-Touched projectiles echo from an alternate position.
        static let echoDelay: TimeInterval = 1.5
        static let echoFraction: CGFloat = 0.5
        // T5 Event Horizon — timer starts at ACQUISITION. Base (full) values;
        // scaled by arena via eventHorizonScale (earlier/shorter-run arenas get
        // tighter timers so the mechanic stays usable).
        static let eventHorizonEraseTime: TimeInterval = 75.0   // erase the arena
        static let eventHorizonEndTime: TimeInterval = 105.0    // +30s → the player is erased
        static let eventHorizonPeaceDuration: TimeInterval = 3.5  // breather after the wipe, then spawns resume

        /// Arena-scaled Event Horizon timer factor (Brandon, Jul 20). Preplanning
        /// for future arenas — currently only ~1-4 exist, so runs use 0.5×.
        static func eventHorizonScale(arena: Int) -> CGFloat {
            switch arena {
            case ...10:   return 0.5    // halved
            case 11...20: return 0.65   // 35% reduced
            case 21...30: return 0.8    // 20% reduced
            default:      return 1.0    // full timer (arena 31+)
            }
        }
    }

    // MARK: - The Unmade Star (v2.0 Arena 5 monument boss)
    /// Axis: INEVITABILITY. The arena stops asking and starts deciding. Every
    /// mechanic is telegraphed — a monument is huge, so tells must be
    /// exceptionally clean or the spectacle becomes unfair soup.
    enum UnmadeStar {
        static let baseHealth: Int = 900
        static let contactDamage: Int = 22
        static let xpValue: Int = 260

        // Collapse Marks — delayed ground markers that implode where you stood.
        static let collapseInterval: TimeInterval = 3.4
        static let collapseDelay: TimeInterval = 1.25          // telegraph window
        static var collapseRadius: CGFloat { 78 * DeviceScale.gameplay }
        static let collapseDamage: Int = 20

        // Starfall Sequence — ordered descending impacts (read the order, move).
        static let starfallInterval: TimeInterval = 6.5
        static let starfallCount: Int = 4
        static let starfallStagger: TimeInterval = 0.35
        static let starfallDelay: TimeInterval = 1.1
        static var starfallRadius: CGFloat { 66 * DeviceScale.gameplay }
        static let starfallDamage: Int = 16

        // Weight of the Center — phase 2's gravitational assertion (pulls you UP
        // toward the monument, i.e. into danger). Boss-scale Gravemote grammar.
        static let pullInterval: TimeInterval = 8.0
        static let pullDuration: TimeInterval = 1.8
        static let pullStrength: CGFloat = 95

        // Accretion ORBIT (2c.2) — the orbiting fragments are a moving hazard,
        // not scenery. They were built decorative with a note that this unit
        // would arm them, and that unit never landed: the monument's most
        // visible moving parts were the only ones that couldn't hurt you.
        //
        // Contact damage is modest on purpose. These sweep continuously and are
        // easy to brush, so they're a POSITIONING tax that shapes where you can
        // stand — the sharp punishment stays with the telegraphed abilities.
        // Player i-frames throttle repeat contacts, so this can safely fire on
        // every frame of overlap.
        static let orbitFragmentDamage: Int = 12
        static var orbitFragmentRadius: CGFloat { 22 * DeviceScale.gameplay }

        // Accretion fragment strikes — orbital fragments break off and descend.
        static let fragmentInterval: TimeInterval = 5.0
        static let fragmentDelay: TimeInterval = 0.9
        static var fragmentRadius: CGFloat { 58 * DeviceScale.gameplay }
        static let fragmentDamage: Int = 14

        // Cadence: every timer is multiplied by these as the star comes apart.
        static let phase2Cadence: CGFloat = 0.85
        static let phase3Cadence: CGFloat = 0.70
        static let enrageThreshold: CGFloat = 0.15   // Final Compression
        static let enrageCadence: CGFloat = 0.55
    }

    // MARK: - Mote (v2.0 Unit 3) — the mascot who enters by deleting you
    /// The joke must be EARNED: the first appearance gates behind real mastery so
    /// it never punishes a new player. See docs/mote-v2.0-handoff.md.
    enum Mote {
        static let requiredLifetimeKills: Int = 10_000
        static let requiredBossKills: Int = 10
        /// Beats of the scripted sequence.
        static let dreadDelay: TimeInterval = 1.0      // he does not wait politely
        static let resolveDuration: TimeInterval = 0.45 // he fades into existence
        static let regardPause: TimeInterval = 0.5     // he looks at you (just long enough to register)
        static let crossDuration: TimeInterval = 0.18  // impossible speed
        /// Dev-only: skip the mastery gate to test the sequence.
        static let debugForceEntrance: Bool = false
    }

    enum Everglow {
        static let pulseInterval: TimeInterval = 2.0
        static var baseRadius: CGFloat { 70 * DeviceScale.gameplay }   // short; ×2 at T2
        static let basePulseMult: CGFloat = 0.5        // 50% ATK per pulse (×2 at T4)
        static let rageGainPerHit: CGFloat = 0.01      // +1% pulse dmg per hit taken
        static let pulseGrowthCap: CGFloat = 1.0       // +100% pulse (T3 cap)
        static let furnaceAtkGainPerHit: CGFloat = 0.005  // +0.5% ATK per hit (T4)
        static let atkGrowthCap: CGFloat = 0.5         // +50% ATK (T4 cap)
        // v2.0 tuning (Brandon, Jul 22): 15s → 20s. The longer wait also SHARPENS
        // the turtle-then-boom rhythm the countdown HUD created. Damage held at
        // 500% for now — the interval alone is already a 25% throughput cut.
        static let eruptionInterval: TimeInterval = 20.0
        static let eruptionMult: CGFloat = 5.0         // 500% ATK, arena-wide (T5)
        static let eruptionTelegraph: TimeInterval = 0.8
    }

    /// v1.9 Iron Maiden (Guard capstone) — incoming force → stored punishment.
    enum IronMaiden {
        // T1 Iron Skin. NOTE: the packet says "convert DEF into bonus ATK," but
        // in this engine projectile damage is driven by the damage MULTIPLIER,
        // not baseAttack (baseAttack only feeds the HUD + ATK%-scaled capstone
        // abilities). To make "weaponize defense" actually bite, Iron Skin routes
        // DEF→offense through the same multiplier lever Unbroken Core uses
        // (defAsDamageMult). Flagged for Brandon's balance pass.
        static let defToDmgT1: CGFloat = 0.0125    // +1.25% damage per DEF (~+25% at 20 DEF)
        static let defBonusT1: CGFloat = 0.05      // +5% DEF, one-time at pickup
        static let thornsT1: Int = 5               // flat damage to touchers
        // T2 Barbed Armor
        static let defToDmgT2: CGFloat = 0.025     // +2.5% damage per DEF (~+50% at 20 DEF)
        static let thornsT2: Int = 17              // Thorns +250% → 5 × 3.5 ≈ 17
        // T3 Retaliate
        static let retaliateMult: CGFloat = 1.5    // 150% of pre-mitigation incoming
        static let retaliateCooldown: TimeInterval = 1.0  // global, not per-enemy
        // T4 Kinetic Reserve
        static let kineticThreshold: Int = 4       // stacks before a burst releases
        static let kineticBurstDefMult: CGFloat = 2.0     // 200% DEF radial burst
        static var kineticBurstRadius: CGFloat { 130 * DeviceScale.gameplay }
        // T5 Iron Maiden
        static let defBonusT5: CGFloat = 0.15      // +15% DEF, one-time at pickup
        static let projectileInterval: TimeInterval = 20.0
    }

    /// v1.9 Skybeam (Shock capstone) — designate prey; call judgment from above.
    enum Skybeam {
        static let tickInterval: TimeInterval = 1.0
        static let tickMultT1: CGFloat = 0.15      // 15% ATK Shock per second
        static let tickMultT2: CGFloat = 0.30      // doubled at T2
        // Lasso reach as a fraction of the arena radius so it scales with the
        // playfield. T2 (max, doubled) stays under half the arena's width — no
        // grabbing mobs across the whole arena.
        static let acquireFracT1: CGFloat = 0.35
        static let acquireFracT2: CGFloat = 0.70
        static var acquireRangeT1: CGFloat { acquireFracT1 * Arena.radius }
        static var acquireRangeT2: CGFloat { acquireFracT2 * Arena.radius }
        static let retentionFactor: CGFloat = 1.4  // lasso holds a bit past acquire range
        static let calledThreshold: TimeInterval = 2.0    // continuous secs → Called + first bolt
        static let calledVulnerability: CGFloat = 1.35    // Called: +35% damage taken
        static let strikeMult: CGFloat = 2.00      // 200% ATK sky-strike
        static let strikeCooldown: TimeInterval = 3.0     // then a bolt every 3s while lassoed
        static let strikeWindup: TimeInterval = 1.0       // channel/telegraph before the bolt lands
    }

    /// v1.9 canon (Brandon, Jul 20): capstone abilities are LESS effective on
    /// boss-class (miniboss + arena boss) than on normal/elite mobs — strong vs
    /// the horde, fair vs the big targets. Unifies the packet's scattered
    /// per-capstone boss caveats into two independent 50% levers:
    ///   • debuffScale — stat-reduction effects (vulnerability, slow, freeze…)
    ///   • damageScale — capstone ability DAMAGE (Skybeam bolt/tick, etc.)
    /// Reused by Skybeam (Called + bolt), later Apex / Polar Vortex.
    enum BossClass {
        static let debuffScale: CGFloat = 0.5   // stat-reduction effects at 50%
        static let damageScale: CGFloat = 0.5   // capstone ability damage at 50%
        /// Boss-class (miniboss + boss) can be EXECUTED by a capstone finisher
        /// (e.g. Apex's pounce) only at/below this HP fraction — a rare "holy
        /// shit" finish, never a shortcut. Normal enemies use each capstone's
        /// own (higher) execute threshold.
        static let executeThreshold: CGFloat = 0.10

        /// Scale a multiplicative debuff (e.g. vulnerability 1.35) for boss-class:
        /// halves the bonus above 1.0. Non-boss returns the base unchanged.
        static func scaledDebuff(_ base: CGFloat, isBossClass: Bool) -> CGFloat {
            isBossClass ? 1.0 + (base - 1.0) * debuffScale : base
        }

        /// Scale an additive-magnitude debuff (e.g. a 0.4 slow) for boss-class.
        static func scaledMagnitude(_ base: CGFloat, isBossClass: Bool) -> CGFloat {
            isBossClass ? base * debuffScale : base
        }

        /// Scale capstone ability DAMAGE for boss-class targets.
        static func scaledDamage(_ base: Int, isBossClass: Bool) -> Int {
            isBossClass ? max(1, Int((CGFloat(base) * damageScale).rounded())) : base
        }
    }

    /// v1.9 Apex (Bleed capstone) — feed the familiar, become the hunt.
    /// NOTE: the packet's per-capstone boss caveats (+100% bat dmg on boss,
    /// 1125% boss pounce) are SUPERSEDED by the global BossClass rule — bosses
    /// take capstone damage at 50% and can't be executed. So no boss damage
    /// bonuses here; the global factor handles boss-class.
    enum Apex {
        // T1 Blood Familiar
        static let familiarAttackInterval: TimeInterval = 1.5
        static let familiarBaseFrac: CGFloat = 0.10     // 10% ATK
        static let familiarMaxFrac: CGFloat = 0.50      // up to 50% ATK
        static let familiarFracPerStep: CGFloat = 0.01  // +1% ...
        static let familiarKillsPerStep: Int = 5        // ... per 5 familiar kills
        // v2.0 (Brandon, Jul 22): 50% of ALL damage the familiar deals heals
        // Spark — the bat becomes the build's sustain engine, not just offense.
        static let familiarLifestealFrac: CGFloat = 0.50
        static var familiarRange: CGFloat { 0.6 * Arena.radius }
        static var familiarHomeOffset: CGFloat { 46 * DeviceScale.gameplay }
        // T2 Bloodfed
        static let bloodfedKills: Int = 10              // every 10 kills…
        static let bloodfedHP: Int = 5                  // …+5 max & current HP
        static let bloodfedMaxHPCap: Int = 100          // per-run cap
        static let hpToAtkFrac: CGFloat = 0.01          // 1% of max HP → bonus ATK
        // T3 Bloodhound
        static let executeThreshold: CGFloat = 0.20     // normals <20% HP executed on bite
        // T4 Marked
        static let markLifetime: TimeInterval = 10.0    // alive 10s → Marked
        static let markVulnerability: CGFloat = 1.35    // +35% from all sources
        // T5 The Hunter — the pounce gauge (reuses StackGaugeNode). Attacking
        // INJURED foes charges it; when full the bat leaps to a weakened enemy
        // and executes it. The bat keeps its normal bites at EVERY tier.
        static let pounceExecuteThreshold: CGFloat = 0.50  // normals executable below this
        static let pounceGaugeCapacity: Int = 4            // attacks to charge the gauge
        static let pounceStackCooldown: TimeInterval = 0.2 // rate-limit the gauge fill
        static let pounceCooldown: TimeInterval = 2.0      // min time between pounces (paces it)
    }

    /// v1.9 Forge Path behavioral nodes (rework Unit 2). All configurable.
    enum ForgePath {
        // Damage-reduction bucket (Vitality) — defined order, effective cap.
        static let drCap: CGFloat = 0.6                 // max stacked DR
        static let vitalSurplusDR: CGFloat = 0.05       // above 75% HP
        static let vitalSurplusThreshold: CGFloat = 0.75
        static let lastStandDR: CGFloat = 0.10          // below 35% HP
        static let lastStandThreshold: CGFloat = 0.35
        static let holdLineDR: CGFloat = 0.08           // 5+ enemies near
        static let holdLineEnemies: Int = 5
        static var holdLineRadius: CGFloat { 150 * DeviceScale.gameplay }
        static let giantkillerDR: CGFloat = 0.10        // vs boss-class
        static let bracedReduction: CGFloat = 0.25      // first hit every 12s
        static let bracedCooldown: TimeInterval = 12.0
        // Emergency nodes (once every 45s).
        static let emergencyCooldown: TimeInterval = 45.0
        static let secondBreathThreshold: CGFloat = 0.25
        static let secondBreathFraction: CGFloat = 0.10 // restore 10% max HP
        static let unyieldingThreshold: CGFloat = 0.20  // hit > 20% max HP
        static let unyieldingReduction: CGFloat = 0.5
        // Recovery.
        static let restorationBonus: CGFloat = 0.05     // +5% healing received
        static let defiantBonus: CGFloat = 0.10         // +10% healing for 4s after a hit
        static let defiantDuration: TimeInterval = 4.0
        static let regeneratorInterval: TimeInterval = 8.0
        static let regeneratorHeal: Int = 1
        static let steadyPulseDelay: TimeInterval = 10.0
        static let steadyPulseHeal: Int = 2
    }

    // MARK: - Level-Up Stats (v1.9 Unit 4)
    /// Per-award stat increments for the level-up cadence: even levels let the
    /// player CHOOSE one of these, odd levels auto-award a random one. Starting
    /// values — balance-sensitive; tuned against the stable post-v1.8 baseline.
    enum LevelUp {
        // v2.0 tuning (Brandon, Jul 24): ATK 2→5, DEF 1→5. The old values were
        // undertuned out of caution — clears leaned on revives once the arena
        // filled. HP held at 10 for now (its late-run scaling is still open).
        //
        // DEF 5→3 (Brandon, Jul 26, from a feel pass). +5 worked — arguably too
        // well: past ~15 DEF, hits were landing for almost nothing, and that
        // didn't make turtling a viable CHOICE so much as the state you drifted
        // into whether you meant to or not. A choice you can't opt out of isn't
        // one. +3 keeps flat reduction genuinely strong while leaving damage on
        // the table, so committing to defence stays a decision with a cost.
        static let hpBonus: Int = 10        // +max HP (also heals for the same)
        static let attackBonus: Int = 5     // +base projectile damage
        static let defenseBonus: Int = 3    // +flat damage reduction
    }
    
    // MARK: - Enemy
    enum Enemy {
        /// Global multiplier on every spawned enemy's HP (Brandon, Jul 27).
        ///
        /// Enemies ramp on hardcoded time brackets in each arena's spawn table,
        /// and past ~1:45 they were reading as too chunky — Arena 5's Anvilborn
        /// elite arrives at 90s carrying baseHP + 3, so a fifth of spawns were
        /// 5 HP while normals were 2. The pressure Brandon wants comes from
        /// SPAWN FREQUENCY, not from bodies that take longer to chew through.
        ///
        /// One dial instead of editing five per-arena tables — those brackets
        /// are scattered magic numbers that would drift apart the moment anyone
        /// tuned one of them in isolation. Applied centrally in EnemyNode.init,
        /// so subclasses (Anvilborn, Gravemote, Star Needle, Ashling…) inherit
        /// it without touching their spawners.
        ///
        /// Mini-bosses are EXEMPT — they scale on their own curve and weren't
        /// part of the complaint.
        static let healthScale: CGFloat = 0.75

        /// Apply the scale, never below 1 — a 0 HP enemy would die to nothing
        /// and break every on-kill path that assumes a real kill happened.
        static func scaledHealth(_ base: Int) -> Int {
            max(1, Int((CGFloat(base) * healthScale).rounded()))
        }

        /// Base enemy speed — must be slower than player
        static let baseSpeed: CGFloat = 130
        /// Base enemy visual radius
        static let visualRadius: CGFloat = 14
        /// Base enemy collision radius
        static let collisionRadius: CGFloat = 12
        /// Base enemy health
        static let baseHealth: Int = 1
        /// Body color (darker for menacing look)
        static let bodyColorHex: UInt32 = 0x1A1A1A
        /// Rim glow color (subtle red)
        static let rimGlowColorHex: UInt32 = 0x661111
        
        // v1.4: Enemy damage to player
        /// Base melee contact damage
        static let baseMeleeDamage: Int = 25
        /// Additional melee damage per 30s elapsed
        static let meleeDamageScaling: Int = 5
        /// Base ranged projectile damage
        static let baseRangedDamage: Int = 15
        /// Additional ranged damage per 30s elapsed
        static let rangedDamageScaling: Int = 3
        /// Mini-boss contact damage
        static let baseMiniBossDamage: Int = 40
        /// Additional mini-boss damage per 30s elapsed
        static let miniBossDamageScaling: Int = 8
    }
    
    // MARK: - Projectile
    enum Projectile {
        /// Auto-attack fire rate (seconds between shots)
        static let fireInterval: TimeInterval = 0.5
        /// Projectile speed
        static let speed: CGFloat = 400
        /// Projectile radius
        static let radius: CGFloat = 4
        /// Projectile color
        static let colorHex: UInt32 = 0xFFCC44
        /// Max range before despawn (in points) — bumped for larger arena
        static let maxRange: CGFloat = 400
        /// v1.9: multishot fan (3+ pellets). Total cone = spreadAngle × this,
        /// held STATIC as pellets increase — more pellets pack denser into the
        /// same fan, not wider. 1.5 = 25% narrower than the old count-scaled
        /// 3-shot spread (which was spreadAngle × 2). 2 pellets stay parallel.
        static let multishotFanWidthFactor: CGFloat = 1.5
    }
    
    // MARK: - Joystick
    enum Joystick {
        /// Radius of the joystick base (touch zone)
        static let baseRadius: CGFloat = 60
        /// Radius of the joystick knob (thumb indicator)
        static let knobRadius: CGFloat = 25
        /// Dead zone — input below this normalized magnitude is ignored
        static let deadZone: CGFloat = 0.1
        /// Opacity of the joystick when active
        static let activeAlpha: CGFloat = 0.5
        /// Opacity when idle (hidden — appears on touch)
        static let idleAlpha: CGFloat = 0.0
        /// Base color
        static let baseColorHex: UInt32 = 0x444444
        /// Knob color
        static let knobColorHex: UInt32 = 0xAAAAAA
    }
    
    // MARK: - Wave / Pacing
    enum Wave {
        /// Time between enemy spawns at start (seconds)
        static let initialSpawnInterval: TimeInterval = 1.2
        /// Minimum spawn interval before late game kicks in
        /// v1.6 tuning: 0.4 → 0.55 — old floor arrived at ~66s, turning the
        /// 70–75s window into a wall of bodies (Brandon playtest 7/9/26)
        static let minimumSpawnInterval: TimeInterval = 0.55
        /// How fast spawn interval decreases per second of game time
        /// v1.6 tuning: 0.012 → 0.010 — gentler ramp into the floor
        static let spawnAcceleration: TimeInterval = 0.010
        /// Late game (90s+): faster acceleration
        static let lateGameAcceleration: TimeInterval = 0.02
        /// Late game minimum spawn interval (v1.6 tuning: 0.2 → 0.25)
        static let lateGameMinInterval: TimeInterval = 0.25
        /// v1.6 tuning: from this mark, some Crucible melee spawns are
        /// skipped to thin the crowd
        static let meleeThinningStart: TimeInterval = 30
        /// Chance a melee spawn is skipped after the thinning mark
        /// v1.8 (B1): 0.30 → 0.22 — Arena 1 played "stand still and machine
        /// gun"; thin fewer spawns for a slightly denser Crucible crowd
        static let meleeThinningChance: CGFloat = 0.22
        /// Mini-boss spawn time
        static let miniBossSpawnTime: TimeInterval = 90.0
        /// Spawn distance from arena center (just outside boundary)
        static let spawnDistance: CGFloat = Arena.radius + 40

        /// v2.0 (Brandon, Jul 24): the arena's real boss now answers a PER-RUN
        /// mob count, not a lifetime tally. You must clear this many enemies IN
        /// THE CURRENT RUN before the boss appears — "master the arena before
        /// the next lesson." Unlocking the next arena then requires felling that
        /// boss the same run. Replaces the old lifetime `<arena>Unlocked` gates,
        /// which let a grind-heavy save skip straight through.
        static let bossSpawnKills: Int = 100

        /// v2.0 (E4, Brandon): the boss now needs BOTH gates — the mob count
        /// AND a minimum elapsed time.
        ///
        /// Kills alone made arrival a function of build strength: a strong build
        /// hit 100 kills at ~2:00 and a stronger one earlier, so the run kept
        /// getting shorter exactly when it was going best. The floor buys the
        /// levels back and makes "the boss answers at 2:30" mean 2:30.
        ///
        /// It also PROTECTS a feeling rather than smoothing one. Spawning stops
        /// the moment the boss lands, but whatever is already on the floor stays
        /// — so a fast player who cleared the kill gate early spends the
        /// remaining seconds still being swarmed, and meets the boss with a
        /// dirty field. That "boss AND forty mobs" moment is the good outcome,
        /// not an accident to tune out.
        ///
        /// Keyed to BOSS GRAMMAR, not to the arena: a monument is an anchored
        /// set-piece worth banking more levels for, a mobile arena boss isn't.
        /// New arenas inherit the right pacing from whichever grammar their boss
        /// registers with — there is deliberately no per-arena table here to
        /// drift out of sync with BossRegistry.
        static func bossTimeFloor(for grammar: BossGrammar) -> TimeInterval {
            switch grammar {
            case .arena:    return 120   // 2:00 — matches the feel it already had
            // 2:30 (Brandon, Jul 26, after feel passes). A decent chunk of time
            // without being crazy — and the board WIPES when the monument drops,
            // so arriving late doesn't compound into an unwinnable field.
            case .monument: return 150
            }
        }
    }

    // MARK: - Ashling splitter (v1.6; v1.8 B2 shard protection)
    enum Ashling {
        /// v1.8 (B2): beat between an Ashling parent's death and its shards
        /// gaining physics, so the parent's death-AoE (Open Vein / Whiteout
        /// bursts, splash) can't insta-kill the trio at spawn.
        /// v1.8 (Unit 2 follow-up): 0.5 → 0.15 — the longer beat let players
        /// move on ("dead!") then get surprised when shards popped into their
        /// path. Shards now appear almost immediately after the kill, but the
        /// deferral still lands them a beat AFTER the death-frame burst, so the
        /// protection holds. NOT 0.0 — a true zero would re-break B2.
        static let shardSpawnDelay: TimeInterval = 0.15
        /// Telegraph ring at the split point during the delay — reads as the
        /// parent bursting, then shards appear. Neon yellow = shard tell.
        static let splitTelegraphRadius: CGFloat = 20
        static let splitTelegraphColorHex: UInt32 = 0xE6FF33
    }

    // MARK: - Chain Lightning VFX (Shock)
    enum ChainLightning {
        /// v1.8: bigger, bolder, longer-lived arc between chained enemies
        /// (Brandon playtest 7/13 — was 1.5 / 3 / 0.8α / 0.15s: too faint & brief)
        static let colorHex: UInt32 = 0x44BBFF
        static let alpha: CGFloat = 0.95
        static let lineWidth: CGFloat = 3.0
        static let glowWidth: CGFloat = 7.0
        static let fadeDuration: TimeInterval = 0.30
    }

    // MARK: - XP & Leveling
    enum Leveling {
        /// XP required for level 2
        static let baseXPRequired: Int = 5
        /// XP scaling per level (multiplied by level)
        static let xpScalingFactor: Double = 1.3
        /// XP dropped by base enemy
        static let baseEnemyXP: Int = 1
        /// Number of upgrade choices presented
        static let upgradeChoiceCount: Int = 3
    }
    
    // MARK: - Physics Categories (bitmask)
    enum Physics {
        static let player:          UInt32 = 0x1 << 0  // 1
        static let enemy:           UInt32 = 0x1 << 1  // 2
        static let projectile:      UInt32 = 0x1 << 2  // 4
        static let boundary:        UInt32 = 0x1 << 3  // 8
        static let xpOrb:           UInt32 = 0x1 << 4  // 16
        static let enemyProjectile: UInt32 = 0x1 << 5  // 32
        static let healthOrb:       UInt32 = 0x1 << 6  // 64   — v1.4
        static let magnetOrb:       UInt32 = 0x1 << 7  // 128  — v1.4
        static let forgeCoin:       UInt32 = 0x1 << 8  // 256  — v1.8 (Unit 2)
        // Next free bit: 0x1 << 9 — update the Notion App Portfolio Registry
    }
    
    // MARK: - Ranged Enemy
    enum RangedEnemy {
        /// Distance at which ranged enemy stops and fires — bumped for larger arena
        static var engageRange: CGFloat { 250 * DeviceScale.gameplay }
        /// Seconds between shots
        static let fireInterval: TimeInterval = 2.0
        /// Projectile speed
        static let projectileSpeed: CGFloat = 180
        /// Projectile radius
        static var projectileRadius: CGFloat { 5 * DeviceScale.gameplay }
        /// Projectile max range
        static var projectileRange: CGFloat { 450 * DeviceScale.gameplay }
        /// Body color — distinct from melee enemies
        static let bodyColorHex: UInt32 = 0x1A0A1A
        /// Rim glow — purple tint
        static let rimGlowColorHex: UInt32 = 0x551166
        /// Eye color — purple
        static let eyeColorHex: UInt32 = 0xBB44FF
        /// Projectile color
        static let projectileColorHex: UInt32 = 0x9933CC
        /// First spawn time — ranged enemies appear after this many seconds
        /// v1.8 (B1): 45 → 40 — earlier purple pressure so Arena 1 can't be
        /// camped in one spot (Crucible-only path; Quench/Coilworks gate their
        /// own ranged spawns and are unaffected)
        static let firstSpawnTime: TimeInterval = 40
        /// Chance a spawn is ranged (vs melee) after firstSpawnTime
        /// v1.8 (B1): 0.25 → 0.30 — a touch more ranged to keep the player moving
        static let spawnChance: CGFloat = 0.30
    }
    
    // MARK: - Health Orb (v1.4)
    enum HealthOrb {
        /// Min time between spawns (seconds)
        static let minSpawnInterval: TimeInterval = 20
        /// Max time between spawns (seconds)
        static let maxSpawnInterval: TimeInterval = 30
        /// HP restored on pickup
        static let healAmount: Int = 20
        /// Visual radius — v1.8: 10 → 14 for legibility (bigger, easier to
        /// read). Pickup is pinned separately below, so a larger visual does
        /// NOT make the orb easier to grab.
        static let visualRadius: CGFloat = 14
        /// Interactible/pickup radius — decoupled from the visual so the art
        /// can grow without changing how easy the orb is to collect (was
        /// visualRadius + 20 = 30 when the visual was 10; pinned here).
        static let pickupRadius: CGFloat = 30
        /// Despawn timer (seconds)
        static let despawnTime: TimeInterval = 10
        /// Color
        static let colorHex: UInt32 = 0x44DD66
        /// Glow color
        static let glowColorHex: UInt32 = 0x22BB44
    }
    
    // MARK: - Coilworks Enemies (v1.7)
    enum CoilworksEnemies {
        // Relay Imp — danger arcs between nearby imps
        /// Max distance between two imps for an arc to form
        static let relayArcRange: CGFloat = 140
        /// Seconds the arc charges (faint, harmless tell)
        static let relayArcChargeTime: TimeInterval = 1.1
        /// Seconds the arc is live (bright, damaging)
        static let relayArcFireTime: TimeInterval = 0.45
        /// Damage on crossing a live arc
        static let relayArcDamage: Int = 8
        /// Distance from the arc line that counts as crossing
        static let relayArcHitDistance: CGFloat = 16

        // Grounder — plants itself, periodic danger pulses
        /// Distance from the player at which it roots
        static let grounderPlantRange: CGFloat = 170
        /// Seconds the expanding tell ring shows before the pulse fires
        static let grounderPulseTell: TimeInterval = 0.9
        /// Pulse damage radius
        static let grounderPulseRadius: CGFloat = 85
        /// Damage inside the pulse
        static let grounderPulseDamage: Int = 10
        /// Rest between pulses
        static let grounderPulseRest: TimeInterval = 2.2

        // Circuit Wasp — angular snap-orbiter
        /// Orbit distance from the player
        static let waspOrbitRadius: CGFloat = 120
        /// Seconds drifting toward the current angle slot
        static let waspDriftTime: TimeInterval = 0.7
        /// Seconds paused between moves (the metronome's rest)
        static let waspPauseTime: TimeInterval = 0.35
        /// Speed multiplier during the snap to the next slot
        static let waspSnapMultiplier: CGFloat = 4.5
    }

    // MARK: - Mirrorwound Enemies (v1.8 Unit 12)
    // Lyra canon: perception pressure taught in layers. Hostile purple
    // (#8E44FF) is reserved for danger actions only — never a resting body.
    enum MirrorwoundEnemies {
        /// The one hostile purple — tells, echo shots, danger contact flashes.
        static let hostilePurpleHex: UInt32 = 0x8E44FF
        /// Pale glass body tone shared by the mirror family.
        static let glassBodyHex: UInt32 = 0x2A2830
        /// Pale glass edge/outline highlight.
        static let glassEdgeHex: UInt32 = 0xD6CCC2

        // Shard Twin — false/real body. The real body has the face + brighter
        // core + the only hitbox; the decoy is visual-only (no physics), so
        // attacks pass through it for free. The decoy re-forms periodically so
        // the "which is real?" read stays live.
        /// Offset between the real body and its decoy reflection.
        static let shardTwinDecoyOffset: CGFloat = 34
        /// Seconds the decoy holds before it fades and re-forms at a new angle.
        static let shardTwinDecoyHold: TimeInterval = 2.0
        /// Decoy fade in/out duration (the flicker).
        static let shardTwinDecoyFade: TimeInterval = 0.3

        // Pane Stalker — phase shift / offset re-entry. Only player-contact is
        // disabled while phased (still shootable); no full-invuln machinery.
        /// Seconds moving normally before a phase begins.
        static let paneStalkerSolidTime: TimeInterval = 2.4
        /// Seconds spent phased-out (low alpha, contact off, repositioning).
        static let paneStalkerPhaseTime: TimeInterval = 0.7
        /// How far it slides to a new offset angle during a phase.
        static let paneStalkerReentryDistance: CGFloat = 130
        /// Low alpha while phased.
        static let paneStalkerPhaseAlpha: CGFloat = 0.28

        // Echo Leech — fires ONE purple echo shot on a loose cadence. Never
        // clones every attack; the tell implies a copy even simplified.
        /// Average seconds between echo shots (loose, not metronomic).
        static let echoLeechShotInterval: TimeInterval = 3.2
        /// Random +/- jitter applied to the cadence so it never feels timed.
        static let echoLeechShotJitter: TimeInterval = 1.1
        /// Distance at which the leech stops closing and starts echoing.
        static let echoLeechEngageRange: CGFloat = 240
    }

    // MARK: - Spark Visuals (v1.7)
    enum Spark {
        /// How large a SPRITE skin renders relative to Spark's visual diameter.
        /// Slightly over 1.0 so art reads at 32pt without implying a bigger
        /// hitbox — skins are cosmetic only (studio canon).
        static let skinSpriteScale: CGFloat = 1.06

        /// White-hot inner core color
        static let innerCoreColorHex: UInt32 = 0xFFF6E0
        /// Inner core radius as a fraction of the player's visualRadius
        static let innerCoreRadiusFactor: CGFloat = 0.55
        /// Ember trail: particles per second at full stick deflection
        static let trailMaxBirthRate: CGFloat = 40
        /// Ember trail: fleck lifetime (seconds)
        static let trailLifetime: CGFloat = 0.38
        /// Ember trail: fleck drift speed opposite movement (points/sec)
        static let trailSpeed: CGFloat = 26
        /// Level-up flare ring color
        static let flareRingColorHex: UInt32 = 0xFFCC66
        /// Outer glow level scaling cap (never implies a larger hitbox)
        static let maxGlowScale: CGFloat = 2.2

        // v1.8: base-Spark eyes. Two small black dots that drift toward the
        // direction of travel — the spark "looks" where it floats. This is the
        // BASELINE face; the earned Arena-5 skin evolves these into focused,
        // flame-detailed eyes (future sprint). All as fractions of visualRadius.
        static let eyeRadiusFactor: CGFloat = 0.17
        /// Half the center-to-center gap between the two eyes.
        static let eyeSpacingHalfFactor: CGFloat = 0.26
        /// Resting vertical bias — eyes sit slightly above center (a face).
        static let eyeBaseYFactor: CGFloat = 0.14
        /// How far the eye pair slides toward the travel direction (leading edge).
        static let eyeMaxShiftFactor: CGFloat = 0.30
        /// Eye color — flat black for the base spark.
        static let eyeColorHex: UInt32 = 0x0A0A0A
        /// Follow smoothing (higher = snappier); framerate-normalized in code.
        static let eyeFollowRate: CGFloat = 12
    }

    // MARK: - Analytics (v1.7)
    enum Analytics {
        /// Max runs kept in the on-disk ring buffer
        static let maxStoredRuns = 200
    }

    // MARK: - Magnet Orb (v1.4)
    enum MagnetOrb {
        /// Min time between spawns (seconds)
        static let minSpawnInterval: TimeInterval = 25
        /// Max time between spawns (seconds)
        static let maxSpawnInterval: TimeInterval = 35
        /// Visual radius — v1.8: 10 → 14 for legibility (see HealthOrb).
        static let visualRadius: CGFloat = 14
        /// Interactible/pickup radius — decoupled from the visual (was
        /// visualRadius + 20 = 30). Pinned so bigger art ≠ easier pickup.
        static let pickupRadius: CGFloat = 30
        /// Despawn timer (seconds)
        static let despawnTime: TimeInterval = 8
        /// Color
        static let colorHex: UInt32 = 0x44AAFF
        /// Glow color
        static let glowColorHex: UInt32 = 0x2288DD
    }

    // MARK: - Forge XP Coin (v1.8 Unit 2)
    enum ForgeCoin {
        /// FLAT forge XP per coin — intentionally NOT routed through
        /// pendingForgeXP (which the XP Boost ad doubles), so coins bank
        /// immediately and are never boosted (decided at kickoff).
        static let forgeXPValue: Int = 5
        /// Coins that erupt and scatter arena-wide on a boss's death (tune).
        static let scatterCount: Int = 12
        /// Seconds before an uncollected coin despawns.
        static let despawnTime: TimeInterval = 12
        /// Visual radius — a large disc (medallion), clearly bigger than the
        /// small XP pebbles.
        static let visualRadius: CGFloat = 15
        /// Pickup radius — NO magnet; a forgiving contact body so walking over
        /// the coin collects it. Walking to them is the point (health-orb canon).
        static let pickupRadius: CGFloat = 22
        /// Seconds for one xScale spin oscillation (narrow → wide).
        static let spinPeriod: TimeInterval = 1.1
        /// Ember burst radius shown at pickup.
        static let pickupBurstRadius: CGFloat = 16
        // Lyra palette (Ask 4a) — spark-stamped forge token:
        static let coreColorHex: UInt32 = 0xFFAA33
        static let rimColorHex: UInt32 = 0xFF6600
        static let stampColorHex: UInt32 = 0xFFD27A
        static let shadowColorHex: UInt32 = 0x7A2F00
    }
}
