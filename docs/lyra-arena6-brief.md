# Brief Request → Lyra: Arena 6 — the first non-circular arena (for v2.1)

*From: Brandon + Claude · July 28, 2026. Drafted while v2.0 sits in App Store
Connect's review queue, so Arena 6 is ready to build the moment v2.0 clears.
Same brief shape as `lyra-arena5-brief.md`.*

---

## ⚠️ BRANDON: settle this before sending

One fork is unresolved, and it changes what we're asking for. **See "The rooms
question" below.** This draft assumes the answer is *structural obstruction, not
a maze*. If you'd rather have true rooms, the brief needs rewriting before it
goes out, because it becomes a much larger engineering ask.

---

## Read this first — Arena 6 breaks a rule the whole game rests on

Every arena shipped so far has been a **bounded circle**. Arena 5 was 2.6× the
footprint of Arena 4, but it was still a circle, and every system in the game
assumes that: the movement clamp, spawn placement, orb scatter, boundary
physics, the lot.

**Arena 6 is the first non-circular arena.** It opens the "Geometry Arc"
(arenas 6–10), a deliberate engine-investment stretch where each arena teaches
the engine a new spatial concept before the first themed biome arrives at 11–20.
The forest weaponizes geometry; these five arenas are where the engine learns it.

That makes Arena 6 **a proof more than a spectacle.** It should feel like a new
kind of place, but its real job is to prove the boundary abstraction works so
arenas 7–10 get cheaper. Design accordingly: interesting, not maximal.

---

## The shape Brandon wants

**"One house with many rooms."**

A rectangular hall. Not a circle, not a single empty box. Internal structure
that reads as *chambers* — a forge-house, a workshop, a place that was built
rather than found.

**Size constraint, and this one is load-bearing:** *not too big.* The Growth
tree (Terra, cultivated ground, the Tree capstone) modifies the arena floor
itself. In an oversized arena, a Growth build's cultivated area becomes a
rounding error and the whole tree feels bad. Arena 6 should feel *dense*, not
sprawling. Internal structure is how it earns scale without square footage.

---

## The rooms question — the fork

**Option A (assumed here): structural obstruction.** Pillars, half-walls,
alcoves, a central mass, a raised platform. Rooms are *suggested* by geometry.
Enemies still path straight at Spark; walls are cover, framing and hazard.

**Option B: true rooms.** Full dividing walls with doorways. Enemies must
navigate. Line of sight matters.

**Why the draft assumes A:** Sparkforge auto-aims at the nearest enemy and
**never lets the player target manually** (locked design canon — being unable to
choose your target is what forces tactical build decisions). Full walls mean
auto-aim would happily fire into concrete, enemies would need real pathfinding
where today they beeline, and projectiles, spawns and orb scatter would all need
occlusion logic. That is a systems sprint wearing an arena costume.

Option A proves the non-circular boundary — the actual goal — without also
solving pathfinding in the same version. **True rooms then become Arena 7 or 8,
once the boundary layer is proven.**

---

## What we need from you

### 1. Identity

- **Name.** Arenas so far: The Ember Yard, The Coilworks, The Mirrorwound, The
  Star Anvil. Arena 6 is a built structure, a house of chambers.
- **Palette + motif.** It follows The Star Anvil's cosmic gravity. What is a
  forge-house *after* the star anvil? Grounded again? Industrial? Older?
- **One-line identity.** What does a player say this arena *is*?

### 2. The spatial concept, expressed as feeling

Each Geometry Arc arena teaches one spatial idea. Arena 6's is **enclosure** —
the first time the walls have corners, and the first time Spark can put
something solid between himself and a threat.

What does enclosure *mean* here emotionally, and how should the internal
structure be arranged to deliver it? Chambers of different sizes? A central
room ringed by smaller ones? Something asymmetric?

### 3. The hazard

**Every Geometry Arc shape carries its own hazard**, native to its geometry.
Arena 6's hazard should be something a *circle could not do* — something that
only makes sense because there are corners, walls and chambers.

Prompts, not prescriptions: something that uses corners as danger, or makes a
chamber periodically hostile, or rewards/punishes standing behind cover, or
moves along the walls.

### 4. Enemies

**Three new enemies** in the established pattern (Arena 5 shipped Gravemote /
Star Needle / Anvilborn). At least one should exploit the new geometry in a way
that would be meaningless in a circle.

**Studio canon to respect:**
- **Enemy colour taxonomy:** red = melee, purple = ranged, neon yellow =
  splitter, ash shield = Braceguard. **Ember/orange is Spark's colour and never
  appears on an enemy.** Purple always means danger.
- **Ranged shooters are now a staple in every arena** (an anti-turret tax), so
  assume at least one of the three is a shooter, flavoured for this place.

### 5. Cards

A set for Arena 6, **tier-aware** (1, 2, 3 or 5 tiers — never 4; tier 5 is a
capstone and there is only one capstone per tree). Cards should feel like they
belong to a place with walls.

**Hard constraint — no ghost cards:** every card must be fully true. Nothing
ships as text-only. If a mechanic can't be implemented, it isn't a card.

### 6. Optional, if it's in you

Arena 9 is planned as a **left-to-right scrolling stage** ("The Processional
Forge"), and Brandon has since locked a pattern: **scrolling arenas land on the
9s** — 9, 19, 29, and so on. It's a separate, much larger build and is NOT part
of this brief. But if Arena 6's identity naturally seeds that arc, plant it.

---

## Constraints worth knowing

- **No manual targeting, ever.** Auto-aim-nearest is locked canon. Design
  threats that are answered by *build choices*, not by aiming.
- **Non-magnetized health orbs.** Walking to them is a positioning decision.
  Consider how that reads in a space with walls: an orb behind cover is now a
  genuinely different decision than an orb in the open.
- **Arena 6 lets the player omit one element at run start.** Arenas 6–10 carry
  element-omission rules, so the card set must not assume any single element is
  present.
- **Growth exists now.** Terra cultivates the floor. A room-based arena has a
  more interesting relationship with floor-modification than a circle does —
  worth thinking about.
- **Monument bosses land every 5th arena** (5, 10, 15, 20). **Arena 6 has a
  standard mobile arena boss, not a monument.** The monument returns at 10.

---

## What happens next

Brief → Lyra designs → Claude builds → Lyra reviews → Brandon playtests.

v2.1 is scoped as **Arena 6 only**, paired with the Variegated Rainbow breadth
capstone as its meta-system. Arenas 7–10 follow at whatever cadence the
boundary abstraction earns once it exists.

**Marketing is paused indefinitely**, so this arc is free to be experimental. No
launch expectations ride on it. Build the blade first.
