# Sparkforge Growth Tree — Creative Handoff

*From: Brandon + Lyra · To: Claude · Version target: **v2.0** · Status: creative
direction established, mechanics still subject to feasibility & balance review.*

*Purpose: define **Growth** as Sparkforge's seventh skill tree and as the
preseason seed for the next biome content arc. Preserved verbatim in-repo
(delivered July 20 2026) alongside the [v1.9 capstone packet](capstones-v1.9-design-packet.md).
Build reference — but v2.0 scope; do not pull into the v1.9 capstone sprint.*

---

## 1. The Core Idea

Growth should not behave like a standard elemental tree. Its defining fantasy is
not poison, healing, roots, or generic plant damage. Growth is about:

> **Establishing a living habitat inside the arena, then cultivating it into a weapon.**

The existing trees primarily modify: the player · projectiles · enemies · damage
states · spatial forces. **Growth modifies the arena itself.** It creates:
cultivated terrain · living structures · defensive flora · walls and obstacles ·
expanding influence zones · environmental advantages for the player ·
environmental disadvantages for enemies.

The central verb for Growth is **Cultivate.** A Growth build should begin small
and become increasingly territorial. The player should feel like they are not
merely surviving the arena — they are **converting** it.

## 2. Growth's Unique Drafting Structure

**Terra is the entry card.** The first Growth card is always **Terra**. Terra
establishes cultivated ground and unlocks the Growth card pool for the remainder
of the run. Before Terra is acquired, Growth-specific cards should not appear.
After Terra, offerings may include: Growth attack cards · living structures ·
environmental utility cards · Terra+ modifiers · Growth dual-tag cards.

This makes selecting Terra functionally different from a normal card — the player
is choosing to **opt into a new build grammar.**

**Working Terra description:** *Cultivate the arena. Unlock Growth cards.*

Exact Tier 1 behavior remains open, but Terra should provide immediate value
rather than existing only as an unlock key. Potential baseline: create a small
cultivated zone around the player or at a fixed arena point; enemies inside
cultivated ground are mildly slowed; future Growth structures may only grow on,
or gain bonuses from, cultivated ground. Simplest implementation may begin with
one persistent Growth zone and expand later.

## 3. Growth Card Families

**A. Flora and Fauna cards** — create specific living objects, attacks, or
structures. Examples: Seed Spore Shot · Defensive Flowers · Vine Wall · Tree ·
future animal or fungus-based effects.

**B. Terra+ cards** — modify the cultivated habitat itself or improve compatible
Growth structures. Examples: increased zone size · improved healing · enemy slow
· player movement speed · structure durability · structure attack speed ·
additional planting capacity · terrain damage · shared bonuses between nearby
Growth objects. Terra+ should create ecosystem-wide value, not behave like
isolated attacks.

> Terra creates the habitat. Flora and fauna inhabit it. Terra+ determines what
> kind of ecosystem it becomes.

## 4. Visual Identity

Growth cannot use the same bright green language as health pickups. Recommended
split: deep forest green for terrain/vines/trunks/structural bodies · yellow-green
or seed-gold for active damage accents · pale spore-white for particles/pollen ·
bark brown as a secondary structural tone · brighter health green stays exclusive
to healing pickups.

Palette starting point (values open): forest body `#174A2A` · living accent
`#5FCF62` · seed highlight `#C9D96F` · spore light (pale green-white) · bark
support (dark warm brown).

**Readability rules:** Growth structures must read as player-owned at a glance ·
healing zones cannot resemble loose health pickups · impassable Growth terrain
must have a clear collision silhouette · damage-dealing flowers should use active
aiming / muzzle / pollen / projectile cues · cultivated terrain should stay
quieter than enemy attacks and hostile projectiles.

## 5. Early Growth Card Concepts

*Established creative concepts, not final numbers.*

**Terra** — Tree-unlock and environmental foundation. Create cultivated ground ·
mildly slow enemies inside the zone · unlock Growth cards for the run · act as the
shared dependency for Terra+ effects. May remain one-tier or carry a short ladder
if the engine supports pool-unlock behavior cleanly.

**Seed Spore Shot** — offensive propagation. A projectile embeds a seed into an
enemy; when the seeded enemy dies, the seed erupts and reduced-damage seed
projectiles fire outward; later tiers increase seed count / travel / secondary
embedding. Core loop: **embed → kill → reproduce.** No longer the likely capstone;
may instead be a 3-tier offensive ladder: (1) seeded targets burst into several
weak projectiles on death · (2) more seeds, farther · (3) secondary seeds may
embed new targets at reduced effectiveness.

**Defensive Flowers** — stationary mini-turrets. Grow flowers that auto-target
enemies. Baseline: ~25% of player ATK · stationary · rotate/visibly aim ·
"charming, innocent, and alarmingly armed." Ladder: (1) grow one · (2) increase
fire speed/range · (3) grow another or add a stronger pollen burst. Open
questions: permanent/timed/placement-capped? destructible? require cultivated
ground? does a new flower replace the oldest? **Recommended initial direction:**
invulnerable or timed · limited concurrent count · no babysitting · placement
restricted to valid arena positions.

**Vine Wall** — environmental defense & path control. Grow a temporary wall of
vines enemies cannot pass. Effects: redirect movement · create choke points ·
interrupt approach · protect zones/structures. **Implementation risk:** true
impassable terrain interacts with pathfinding, spawning, boss movement,
collision, arena-edge behavior. Fallbacks if full pathing is too expensive:
heavily slow enemies passing through · repel normal enemies · block projectiles
instead of bodies · let bosses/elites break through · segmented barriers with
safe gaps. Creative preference remains a real obstacle if feasible.

## 6. Growth Capstone — Tree

Card description: *Plant a sapling. Help it become a problem.* The literal name
**Tree** is intentional and preferred — its simplicity makes the eventual
absurdity funnier. The player begins with a sapling and grows it into a
territorial ecosystem.

- **T1 Sapling** — plant a small tree at a valid location. A small cultivated
  zone forms beneath it; enemies inside are slowed. Persists for the run unless
  implementation requires timed replacement.
- **T2 Rootreach** — influence zone expands; player gains increased move speed
  while inside cultivated ground.
- **T3 Shelter** — zone expands again; player slowly regenerates health while
  standing inside. (Percentage or flat; modest enough that leaving the zone stays
  necessary under pressure.)
- **T4 Wild Domain** — the Tree matures; influence radius increases
  substantially. All prior effects remain (slow · move speed · regen). Values may
  rise slightly, but T4's primary reward is stronger territorial control and a
  visibly mature Tree.
- **T5 The Forest Wakes** — full maturity. All prior effects remain. **Every 4–5s
  the Tree launches a woodland animal at a random enemy** dealing significant
  damage. Target priority may favor boss → miniboss → elite → random normal. The
  projectile must **visibly and unmistakably be a wholesome forest animal**
  (rabbit / squirrel / deer / rotating pool). NOT a generic spirit wolf, an
  abstract green projectile, or a thorn vaguely shaped like an animal. The joke
  and spectacle depend on the Tree forcibly launching an innocent-looking creature
  at tremendous speed into a hostile mob.

**Thesis:** the final tier reveals the Tree is no longer passive terrain — it has
become a complete ecosystem capable of defending itself.
**sapling → sanctuary → territory → awakened habitat.**

**Distinct from Growth synergies:** future Growth synergies describe how multiple
Growth cards interact across the ecosystem. Tree is a single deeply cultivated
organism telling one complete lifecycle, culminating in an actively defensive
living domain.

## 7. Potential Terra+ Cards

*Exploratory, not locked.* Rich Soil (expand zones + improve healing) · Thornsoil
(enemies in cultivated ground take damage) · Deep Roots (structures last longer,
Vine Walls stronger, movement penalties increase) · Pollination (flowers create
seedlings; nearby structures gain firing cadence) · Mycelial Web (structures
share buffs / reduce each other's cooldowns) · Spring Rain (periodically restore
or accelerate structures). Launch set should stay disciplined — establish a
reusable modifier framework, not every possible interaction at once.

## 8. Growth's Strategic Identity

Growth offers area control · environmental utility · stationary offense ·
defensive positioning · slow-building power · cultivated safe zones · arena
manipulation. It should **not** become a universal healing tree · poison under
another name · a better Chill · a Guard replacement · an effortless AFK turret
build · pure summon spam. Tradeoffs: setup time · location dependence · limited
structure count · reduced power outside cultivated zones · delayed payoff ·
vulnerability to highly mobile fights.

> Plant something small. Protect or exploit it. Let it change the battlefield.
> Eventually realize the arena belongs to it now.

## 9. Relationship to the Future Death / Decay Tree

Several biological mechanics are reserved for a later Death/Decay tree — corpse
propagation · parasitic infection · decomposition · death-triggered contagion ·
predatory blooming · rot · corpse-based projectiles · escalating biological harm.
The split gives both trees stronger identities.

- **Growth** — creation · territory · cultivation · shelter · living structures ·
  symbiosis · flourishing. *"Life takes root here."*
- **Death / Decay** — infection · decomposition · corpse use · parasites · rot ·
  contagious death · weakening · predation. *"Death does not end here."*

**Future dual-tag potential** (not v2.0 requirements): Compost (dead enemies
enrich cultivated ground) · Carrion Bloom (kills in Growth terrain produce
temporary hostile flowers) · Fertile Graves (deaths create seedbeds) · Rotroot
(roots gain power from injured/infected/dying enemies).

## 10. Growth as a Preseason Content Seed

Growth is not only a new skill tree — it is the first example of Sparkforge's
seasonal release structure. **v2.0 function:** Growth debuts alongside Arena 5 ·
the Unmade Star · Boss Mode · card tiers · capstones · Mote's first appearance ·
skin infrastructure · new card content. It gives players an early taste of the
next biome theme.

The following arc expands the theme outward: plant-themed arenas · enemy families
· environmental mechanics · bosses · additional Growth cards · Terra+ effects ·
Growth skins. **The player first learns the theme as a power they control; later,
they encounter the same thematic language as a world that opposes them.**

**Long-term release grammar:** (1) Preseason seed — new tree/mechanic family,
small card set, early premium skin, foundational engineering · (2) Season launch
— first arenas, enemy curriculum, environmental rules, earned skin · (3) Midseason
— advanced arenas, midpoint big bad, balance pass, new cards/dual-tags · (4)
Season finale — final arenas, biome boss, premium skin, next theme's seed
cards/mechanics. Growth is the first test of the paired model: **the skill tree
seeds the fantasy; the biome fulfills it.**

## 11. Seasonal Skin Structure

Three themed skins per season. **Preseason premium** — ships with the theme's
first cards/mechanics; visual preview + early opt-in + premium treatment.
**Earned seasonal** — unlocked through biome-arc progress; meaningful free reward
+ seasonal mastery identity. **Post-launch premium** — most elaborate expression
once the biome identity is established; richer particles/animation, optional
purchase without gameplay power. **No skin may change** hitbox · movement · attack
power · pickup behavior · survivability · any gameplay outcome.

## 12. Major Engineering Questions

**Terra & card-pool unlocking** — can acquiring Terra dynamically unlock Growth
cards for the run? Should Growth cards exist in the pool but stay gated until
Terra is owned? How does the Codex display gated Growth cards before discovery?

**Persistent structures** — can the engine support player-owned arena structures?
Timed/permanent/count-capped? Invulnerable? Can they select and attack targets?
Placed only on valid terrain?

**Cultivated ground** — can a persistent zone apply different effects to player vs
enemies? Can zones overlap? Can Terra+ modify all active zones? Should the zone
follow the player, stay fixed, or depend on the card?

**Vine Wall** — can enemy pathing respond to temporary impassable objects? Can
bosses ignore/destroy walls? Best fallback to preserve the fantasy if full
obstacle pathing is out of scope?

**Tree capstone** — can one persistent Tree evolve visually per tier? Can its zone
expand without replacing the Tree? Can it launch a rotating animal-projectile set?
Can targeting prioritize boss-class? Placed once per arena, or relocate between
arenas/runs?

**Performance** — Growth may create persistent zones, multiple flowers, walls,
projectiles, particles, animal shots, overlapping effects. First implementation
must use explicit caps and pooled objects to avoid a frame-rate extinction event.

## 13. Recommended v2.0 Minimum Viable Growth Set

1. **Terra** — foundational habitat card; unlocks Growth pool.
2. **Seed Spore Shot** — offensive propagation.
3. **Defensive Flowers** — stationary ranged structure.
4. **Vine Wall** — environmental defense / path disruption.
5. **Tree** — five-tier Growth capstone.
6. **One Terra+ utility card** — zone expansion, slow, healing, or structure buff.
7. **One dual-tag Growth card** — chosen for implementation compatibility with an
   existing tree.

Enough breadth for future 3 / 5 / 7 Growth synergies without shipping the whole
ecosystem in one pass. If Growth must launch with ≥7 distinct tagged cards for
synergy support, remaining slots should favor simple, reusable mechanics over new
large subsystems.

## 14. Final Creative Thesis

Growth should feel like the first tree that does not merely enhance the player —
it establishes a living claim on the arena. The run begins with Terra; then the
player chooses what to cultivate: weapons · barriers · sanctuary · territory ·
structures · eventual absurdity. At maximum devotion, a sapling has become an
awakened forest that heals the player, hinders the enemy, controls space, and
launches woodland creatures at hostile geometry.

> Plant something small. Let the arena become alive. Help it become a problem.

---

*Build note (Claude): the v1.9 capstones are the Growth engine in disguise —
cultivated-ground zones reuse the Everglow/Polar-Vortex player-zone primitive;
Defensive Flowers + the Tree's animal launcher reuse Apex/Iron-Maiden/Skybeam
priority-target auto-turrets; Tree's tier→T5-event shape is Everglow's; the animal
shot is Erasure/Iron-Maiden's arena-origin priority projectile. The single genuine
new subsystem is Vine Wall's impassable terrain (enemy pathing) — favor the
zone-based fallbacks first. See the forthcoming Capstone Systems Ledger.*
