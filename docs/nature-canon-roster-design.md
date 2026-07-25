# Nature Canon — the Tree T5 animal roster (LOCKED design)

*Designed by Brandon + Claude, Jul 24 2026. The Tree capstone's T5 ("The Forest
Wakes") launches woodland animals via the NATURE CANON. The launcher
ARCHITECTURE shipped in C1.6 with a placeholder roster; this is the real roster,
locked and ready to build. Numbers are starting points, tunable in GameConfig.*

---

## The machine (already built, C1.6)

Every launch resolves as **`base timer (4.5s) · damage mod (~150% Spark) ·
per-animal modifier`**, with a rare roll for the pet. Today `TreeAnimal` is a
data tuple (damage/radius/thorns). **The real roster needs each animal to carry
a BEHAVIOUR** — an on-launch / on-impact action — because homing, timed turrets,
devour, and propagating poison aren't expressible as numbers. Extending
`TreeAnimal` from a tuple to a behaviour model (enum-dispatched or closure) is
the core build task; everything else hangs off it.

**Launch flow:** roll a TIER (weights below) → pick uniformly within the tier →
run that animal's behaviour. The lion is its own 5% tier.

## Tiers & weighting (Brandon, locked)

- **Common 50%** — Rabbit · Squirrel · Fox
- **Uncommon 25%** — Deer · Boar · Hedgehog
- **Rare 15%** — Bluebird · Skunk · Badger
- **Lion 5%** — Mountain Lion

---

## The roster

### Common (50%)
**🐰 Rabbit — "Ninja Kick."** Flies from the tree as a rabbit ninja and
super-kicks one target. **Auto-crits, and the crit does 300%** (vs the normal
200%) → ~450% Spark on a single hit. *Stays deliberately ridiculous* (ninja
assassin rabbit — Brandon's call). Reuses the crit pipeline; force `isCrit` + a
special crit multiplier.

**🐿️ Squirrel — "Scatter."** On impact, flings **5 acorns** outward, each a
small reduced-damage fragment. Reuses the Seed Spore fragment/scatter pattern.

**🦊 Fox — "Homing Fur-Missile."** Acts like a homing missile (stays a fox),
tracks the target, and on reach **explodes in an orange-and-white fur AoE**.
*New: homing projectile movement* + `damageEnemiesInRadius` on impact.

### Uncommon (25%)
**🦌 Deer — "Trample."** Flies **antlers-first**, heavy single-target (~220%
Spark) + knockback. Reuses knockback (Repulse card's plumbing).

**🦫 Boar — "BOAR GORE!"** Charges a **straight line, pierces**, and **knocks
all enemies aside** as it barrels through — and screams **"BOAR GORE!"**
(cartoonish, on-purpose). Reuses pierce + knockback; add the shout (text/audio).

**🦔 Hedgehog — "Needle Barrage."** Posts up on the terrain and becomes a
**needle machine-gun for 3s**: fires at **500% of Spark's current attack speed**,
**65% damage per needle**. More spectacle than damage, and delightful. Reuses
the Defensive-Flower turret (aim + fire) as a TIMED, high-fire-rate structure.

### Rare (15%) — the game-changers
**🐦 Bluebird — "WTFROFLSTOMP."** A tiny bird that delivers a **massive AoE:
350% Spark damage in a huge radius** (~3× Terra's base zone area — big, but not
Everglow-eruption big). The joyful absurdity: tiny body, enormous boom. Reuses
the eruption/AoE primitive.

**🦨 Skunk — "Persist."** Lays a **poison cloud** dealing potent DoT (stronger
than bleed/burn). **Enemies that die in the cloud leave a NEW small poison
cloud**, which can propagate to others; the poison persists as long as enemies
keep dying in the clouds — potentially till run end.
- **THE big subsystem, and the DECAY-TREE FOUNDATION.** Build v1 with a
  **generation/duration cap** (the way Seed Spore caps its chain) so it can't
  propagate infinitely (perf + balance). The full **Decay tree removes the
  leash** later — clean double-dip. Reuses the cultivated-ground zone primitive
  + a Thornsoil-style DoT + a propagation loop.

**🦡 Badger — "Thief."** The honey badger **eats up to 3 enemies and heals Spark
100% of their combined HP** — because it just takes what it wants.
- **Boss-class scaled (Brandon):** 100% heal off normal mobs, **≤50% off
  elites / minibosses / bosses** — maps straight onto the existing
  `GameConfig.BossClass` damage/debuff levers (same ones capstone resistance
  uses). Prevents a gauntlet heal-cheese.
- *New: devour (select + remove up to 3) + lifesteal.* Reuses `onEnemyKilled` +
  `PlayerStats.heal`.

### Lion (5%)
**🦁 Mountain Lion — "Prowl."** The jackpot. A **pet that roams ~10s, mauling on
contact.** Already prototyped in C1.6 (roaming maul); refine. A future pass can
reskin it onto FamiliarNode/Apex summon framework.

---

## The reuse map (every animal becomes plumbing)

- **Homing** (Fox) → Panda samurai targeting, the banked Familiar/Summoner set.
- **Timed turret** (Hedgehog) → any future time-limited structure.
- **Poison propagation** (Skunk) → **the Decay tree's core DoT system.**
- **Knockback** (Deer, Boar) → reuses Repulse.
- **Devour + lifesteal** (Badger) → reusable steal/heal mechanic.
- **Big AoE** (Bluebird) → reuses the eruption primitive.
- **Forced auto-crit** (Rabbit) → reuses the crit pipeline.

## Tuning watch (Brandon's device pass)
- Rabbit's ~450% single hit — **intended**, stays ridiculous.
- Badger heal — capped by boss-class scaling; watch the normal-mob case in a
  dense crowd.
- Skunk propagation — the cap value is the balance/perf lever.

## Art dependencies (the art pass, AFTER systems)
10 bespoke sprites + animations: 9 launched animals (launch + impact anims) and
the lion pet (idle/prowl/maul). Built alongside the Panda kaiju/samurai and the
skin roster in one art sprint.
