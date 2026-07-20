# Sparkforge v1.9 Capstone Design Packet

*From: Brandon + Lyra · To: Claude · Version: v1.9 "The Deepening" · Scope: one
five-tier capstone card per existing synergy tree. This is the canonical build
spec — implement against it. Wires into Unit 3's `isCapstone` hooks + the
capstone reveal. Fills the six `[awaiting Lyra]` slots.*

## Design thesis

Each capstone represents deep devotion to one card and one combat fantasy.
Synergies reward *breadth* across a tree; capstones reward repeatedly investing
in ONE ability until it becomes something **qualitatively different**. The six
are intentionally distinct from their trees' existing synergy ladders. Several
introduce new mechanics — flagged rather than abstracted away, because the
strange mechanics are the point. These should feel like genuine Tier-5 EVENTS,
not larger numbers.

---

## 🔥 Fire — Everglow  ·  *"Become the fire at the center of the arena."*

- **T1 Inner Heat** — damage pulse every 2s, 50% ATK to enemies in a short radius.
- **T2 Burning Reach** — pulse radius doubled.
- **T3 Ragekindled** — taking damage permanently +1% pulse damage, per-run cap (rec **+100%**).
- **T4 Living Furnace** — base pulse damage doubled; taking damage now also grants +1% pulse dmg AND +0.5% ATK (configurable per-run caps; rec ATK cap **+50%**).
- **T5 Everglow** — every 15s, erupt: **1,000% ATK to all enemies in the arena** (brief visual buildup before detonation).

**Distinct from Fire synergies:** not burn propagation — the player becomes a persistent close-range heat source whose rage escalates through damage taken, culminating in periodic arena-wide eruptions.

**Flags:** persistent per-run scaling from damage taken · separate configurable caps for pulse growth and ATK growth · repeating arena-wide eruption · eruption telegraph + visual.

---

## ⚡ Shock — Skybeam  ·  *"Lasso your prey. Call judgment from above."*

- **T1 Lightning Lasso** — attach a lasso to the nearest valid enemy: 15% ATK Shock/1s. Retargets if the target dies/invalidates.
- **T2 Extended Circuit** — lasso damage doubled; acquisition + retention range doubled.
- **T3 Homing Beacon** — summons + eligible secondary effects prioritize the lassoed target (only effects that already support target selection).
- **T4 Heaven's Call** — after 2s continuously lassoed, target becomes **Called**: +35% damage taken from all other sources (configurable); removed when lasso breaks/changes.
- **T5 Skybeam** — a target lassoed 2 uninterrupted seconds is struck from above for **500% ATK** Shock. Repeats while lassoed, internal cooldown (rec **5s**).

**Distinct from Shock synergies:** not chaining/aura — creates a designated PREY target the whole build coordinates around, then calls repeated vertical strikes.

**Flags:** persistent nearest-target tether · retarget logic · target-priority hook for summons/secondary effects · continuous-attachment timer · temporary vulnerability state · repeating sky-strike with internal cooldown.

---

## 🩸 Bleed — Apex  ·  *"Feed the familiar. Become the hunt."*

- **T1 Blood Familiar** — summon an invulnerable bat familiar. Starts at 10% player ATK, attacks independently; kills raise its damage up to 50% player ATK (rec **+1% player ATK / 5 kills**; cadence configurable, rec **1 atk / 1.5s**).
- **T2 Bloodfed** — every 10 kills: +5 max HP AND +5 current HP (per-run cap rec **+100 max HP**). Also convert 1% of max HP into bonus ATK.
- **T3 Bloodhound** — bat prioritizes bleeding enemies. Normal enemies <20% HP are executed when struck; elites/minibosses/bosses instead take bonus damage (rec boss-class **+100% bat damage**).
- **T4 Marked for Death** — any enemy alive 10s after entering the arena becomes **Marked**: +35% damage from all sources; persists until death.
- **T5 The Hunter** — fuse permanently with the bat (it stops being an independent summon). Current hunted target becomes active **prey**. Prey that survives 4 uninterrupted seconds while directly engaged is **pounced** for **750% ATK**. Normal enemies executed if the pounce leaves them <50% HP. Elites/minibosses/bosses can't be executed — instead take a configurable multiplier (rec **1,125% ATK total**); pounce cooldown rec **8s**; boss-class briefly pinned/staggered, not fully paralyzed.

**Distinct from Bleed synergies:** not stronger bleed — a growing predator companion that marks lingering prey and ultimately fuses player + familiar into a dedicated hunting state (familiar → apex predator).

**Flags:** independent invulnerable summon · kill-based summon scaling · kill-based max-HP growth · max-HP→ATK conversion · target-priority rules · enemy lifetime tracking · persistent Marked state · familiar fusion state · active prey tracking · pounce timer + cooldown · separate normal vs boss-class execution.

---

## 🛡️ Guard — Iron Maiden  ·  *"Turn every impact into stored punishment."*

- **T1 Iron Skin** — convert 10% DEF into bonus ATK; +5% DEF; gain **Thorns** (5 flat damage to enemies making damaging contact).
- **T2 Barbed Armor** — Thorns +250%; DEF→ATK conversion up to 20%.
- **T3 Retaliate** — when an enemy damages the player, counter that enemy for **150% of incoming pre-mitigation damage**; 1s cooldown (may be global, not per-enemy, for perf/balance).
- **T4 Kinetic Reserve** — each damaging hit adds a Kinetic stack. At 5 stacks, release a radial burst dealing **200% DEF**, consuming all stacks.
- **T5 Iron Maiden** — +15% DEF. Every 20s, release all stored Kinetic energy as a compressed projectile toward the nearest high-priority enemy (priority: Boss > Miniboss > Elite > nearest normal). Projectile deals the T4 Kinetic burst value + current Thorns; cannot miss; ignores normal collision obstruction. If no stacks stored, the timed projectile still deals current Thorns.

**Distinct from Guard synergies:** a specific retaliation engine — individual impacts trigger counters, repeated impacts become stored energy, stored energy is released as prioritized punishment. The player processes incoming force into ammunition.

**Flags:** DEF→ATK conversion · flat Thorns value · pre-mitigation incoming-damage reference · retaliation cooldown · Kinetic stack tracking · radial DEF-scaling burst · priority-targeted unavoidable projectile.

---

## 🕳️ Void — Erasure  ·  *"Destabilize reality. Accept the final cost."*

- **T1 Unstable** — player damage applies an **Unstable** stack (max 3). At 3, consume all + trigger one random effect from a curated weighted table:
  1. **Implosion** — pull nearby enemies toward the target.
  2. **Rift Burst** — bonus Void damage in a small radius.
  3. **Phase Lock** — briefly immobilize normal enemies, slow boss-class.
  4. **Damage Echo** — repeat a portion of the triggering hit after a short delay.
  5. **Displacement** — move the target a short random distance.
  6. **Fracture** — increase damage taken briefly.
  7. **Backwash** — fire a small Void projectile burst from the target.
  (All effects + weights configurable.)
- **T2 Void-Touched** — player projectiles bypass enemy armor/physical DR where supported. Unstable triggers at **2** stacks.
- **T3 Rift Cannon** — every 3rd Unstable activation opens a rift at a random valid position; a cannon fires along a random vector, hitting all enemies in its path (rec **300% ATK**).
- **T4 Echo** — Void-Touched projectiles echo 1.5s after firing, from a different valid arena position toward the original target area / trajectory; reduced damage (rec **50%**).
- **T5 Event Horizon** — after surviving **75s** with Event Horizon active: erase all current enemies, all hostile projectiles, all active hazards; stop spawning; arena goes silent/voided. Boss-class either erased outright or take catastrophic fixed damage (mode-dependent). After an **additional 30s**, the **player is erased and the run ends** — bypassing revives, Last Light, shields, invulnerability, DEF, damage reduction, and ALL normal death-prevention. *The Void gives. The Void takes.*

**Distinct from Void synergies:** not another gravity-well build — destabilizes individual enemies, attacks through impossible angles, repeats projectiles from alternate positions, and ultimately removes the arena from reality at the cost of the player's own existence.

**Balance/mode note:** Event Horizon is a deliberate risk-reward. Later arenas/modes may exceed five minutes — this lets a player take guaranteed battlefield erasure while accepting a hard upper run limit. **The timer begins when T5 is ACQUIRED, not at run start.**

**Flags:** stackable Unstable status · weighted 7-result RNG table · armor/mitigation bypass · count every 3rd Unstable activation · random-position rift cannon · delayed projectile echo from alternate origin · run timer tied to capstone acquisition · arena-wide entity removal · spawn shutdown state · scripted unavoidable run termination · mode-specific boss handling.

---

## ❄️ Chill — Polar Vortex  ·  *"Carry the storm. Freeze enemies to the soul."*

- **T1 Iceburst** — enemies that die while frozen explode into 3 ice shards (random directions, 15% ATK each).
- **T2 Brittle Cold** — shard count 3 → 5; slowed/frozen/mobility-impaired enemies take +40% damage (configurable).
- **T3 Windchill** — a localized cold storm follows the player; enemies inside gain Chill stacks at a fixed interval (rec **1/s**); modest starting radius.
- **T4 Glacial Condensation** — normal attacks no longer fire immediately; every 3 projectiles condense into one large **icicle** (200% ATK, straight line, shatters on first impact into 3 shards, each dealing DOUBLE normal Iceburst shard damage). Multishot projectiles count individually.
- **T5 Polar Vortex** — storm radius tripled. Enemies at 5 Chill stacks freeze for 3s. After the freeze, survivors become **Frostbitten** for 4s: +100% damage taken. Boss-class: reduced freeze + reduced vuln (rec **1s freeze/heavy slow, +50% while Frostbitten**).

**Distinct from Chill synergies:** not slow/shatter/control — a mobile weather system around the player that mutates projectile output into heavy icicle artillery, with a stacking cold lifecycle: **chill → freeze → frostbite**.

**Flags:** frozen-death shard generation · shared mobility-impaired vulnerability check · persistent player-following storm zone · Chill stack system · projectile condensation counter · large icicle projectile type · impact shatter · freeze→frostbite transition · separate normal vs boss-class status.

---

## Summary of new machinery (reusable systems)

Per-run capped stat scaling · continuous target tether · target-priority
weighting · summon/familiar framework · enemy lifetime tracking · persistent
marks + status stacks · delayed projectile duplication · arena-origin projectile
spawning · player-following zones · scripted run-ending effects · boss-specific
status substitutions · configurable execution exclusions.

**Implementation-complexity order (NOT creative priority):**
1. Erasure · 2. Apex · 3. Skybeam · 4. Polar Vortex · 5. Everglow · 6. Iron Maiden.

**Creative identities:** Everglow = the player becomes a volcano · Skybeam =
designate prey for heavenly judgment · Apex = familiar grows/hunts/fuses ·
Iron Maiden = incoming force becomes stored retaliation · Erasure = reality
destabilizes then consumes everything · Polar Vortex = the player becomes a
mobile freezing storm.

> "Twenty new mechanics — but twenty reusable mechanics wearing six excellent
> trench coats." — the packet
