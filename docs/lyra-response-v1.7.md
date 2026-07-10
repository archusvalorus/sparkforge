# Lyra Response Packet

*Received July 9, 2026, in answer to `lyra-brief-v1.7.md`. Verbatim.
All five asks answered — these calls are canon for the v1.7 build.*

## Sparkforge v1.7, The Coilworks

## Executive Call

Build **The Coilworks** largely verbatim from the future-arena spec.

The Quench proved the format works: a strong arena identity, a small enemy vocabulary, one boss built around a distinct pressure language, and cards that make the new systems feel alive.

v1.7 should not overcorrect. It should sharpen.

The Coilworks is still:

**A living forge engine where sparks become current, and every step completes or breaks the circuit.**

Core player feeling:

**The arena is not chasing you. It is calculating you.**

---

# Ask 1, The Coilworks Refinement

## Recommendation

**Confirm with light refinements.**

Keep the existing spec:

* **Floor:** `#121315`, blackened machinery
* **Boundary:** `#5B4A22`, tarnished brass
* **Ambient particles:** `#F6D36B`, jittering static motes
* **Motif:** circuit rings with gaps, conduit lines, node pulses
* **Mood:** mechanical, rhythmic, calculating

## Refinements after The Quench

### 1. Static should feel precise, not cozy

The `#F6D36B` family is correct, but it should read as pale electrical static, not warm treasure or XP.

Use it as:

* short jitter sparks
* floor-node pulses
* enemy accent glints
* brief circuit-line flashes

Avoid using it as:

* large glowing reward orbs
* soft pickup-style halos
* anything that competes with player ember

### 2. Floor pulses should imply calculation

The circuit motif should not pulse randomly. It should feel sequenced.

Suggested behavior:

* one node flickers
* a conduit line catches
* two or three connected nodes answer
* the pulse dies before completing the full circuit

This makes the arena feel like an old machine trying to solve the player.

### 3. Keep the floor quieter than the enemies

The Coilworks can be more animated than The Quench, but readability still wins. Floor pulses should sit below combat priority.

Suggested opacity:

* idle circuit lines: very faint
* active pulse: noticeable but brief
* boss tells: always brighter than ambient pulses

### 4. No decorative rings around enemy bodies

The Quench field report is now canon.

Enemy ornamentation can sit:

* above the head
* behind the body as non-circular ticks
* beside the body as small nodes
* inside the silhouette as face or core treatment

It should not encircle the enemy body unless it is explicitly armor or a shield.

## Final Arena 3 Identity

**The Coilworks** should feel like a factory-prayer.
An ancient engine.
A brass circuit.
A machine that has mistaken survival for input.

Build it.

---

# Ask 2, Orbiter Identity Call

## Recommendation

**Option C: both, introduced at different pressure tiers.**

Use both orbiters, but make them teach different lessons.

The orbit AI is now proven and good. Arena 3 is the right place to turn that lesson into a family of threats.

## Enemy 1, Static Halo

### Origin

This is the returned Cinder Halo, restyled for v1.7.

### Name Recommendation

Rename from **Cinder Halo** to **Static Halo**.

Reason: "Cinder" emotionally points toward ember/orange, and enemy color taxonomy now reserves ember/orange for the player. Static Halo better fits the Coilworks and avoids player-color confusion.

### Color

Pale-gold static family, `#F6D36B`, tuned less warm than player ember.

### Look

Medium circular enemy body.
A small halo floats above the head, never around the body.
The halo may slow-drift or gently bob, but should not imply shielding.

Face:

* narrow slit eyes
* short flat mouth
* slightly "serene" in the worst way

### Behavior

Smooth orbiter.

It drifts into medium range and circles the player with steady motion.

### Role

Early or mid Arena 3 pressure enemy.

### Lesson

The player learns that not every threat beelines. Some threats choose position.

---

## Enemy 2, Circuit Wasp

### Color

Pale-gold static body accents, with dark machinery base.

### Look

Small round core with two angular wing ticks, not rings.
One chevron eye or two sharp dot eyes.
The body should feel lighter and more nervous than Static Halo.

### Behavior

Angular snap-orbiter.

It moves around the player in four-point rhythm:

* drift
* pause
* snap to next angle
* pause
* snap again

### Role

Later Arena 3 pressure enemy, or elite variant.

### Lesson

The player learns the difference between smooth orbit pressure and rhythmic angle pressure.

## Why both work

Static Halo is the **smooth clock hand**.
Circuit Wasp is the **broken metronome**.

Together they make Arena 3 feel mechanical without needing a giant enemy roster.

## Spawn / Introduction Recommendation

### Early Coilworks

Relay Imp
Static Halo

### Mid Coilworks

Grounder
More Relay Imp pairings

### Late Coilworks

Circuit Wasp
Grounder plus orbiter combinations

This avoids throwing two orbit AI variants at the player too early.

---

# Ask 3, Six Coilworks Cards

## Dual-Tag Rule Recommendation

For dual-tag cards, use this rule:

**A dual-tag card counts toward both tag totals.**

Do not make the player choose a tag on selection.

Reason:

* Cleaner UX
* Faster comprehension
* More exciting buildcraft
* Makes dual-tag cards feel special without adding another decision popup
* Supports the fantasy of hybrid forge reactions

Balancing lever:

* Dual-tag cards can have slightly narrower effects or lower numerical values if needed.
* The card text should show both tags clearly.
* Dual-tag cards should be rare enough that they feel like bridges, not soup.

---

## Card 1, Induction Step

### Tag

Shock

### Description

**Moving charges your next attack.**

Character count: 32

### Intended Effect

Distance traveled builds charge. When fully charged, the player's next attack deals bonus Shock damage.

### Notes

This replaces the original Spark Step direction because Arc Wake already owns "movement leaves sparks." Induction Step keeps movement identity without duplicating that effect.

---

## Card 2, Copper Vein

### Tag

Shock

### Description

**Shock chains reach farther.**

Character count: 27

### Intended Effect

Increases the search radius for Shock chain targets.

### Notes

This does not add another chain target, so it avoids colliding with Arc and Live Wire. It makes existing chain builds feel better by improving reliability.

---

## Card 3, Relay Burn

### Tag

Fire / Shock

### Description

**Burning foes can arc Shock.**

Character count: 28

### Intended Effect

Fire damage has a chance to trigger a small Shock arc from the burning enemy to one nearby enemy.

### Dual-Tag Handling

Counts toward both Fire and Shock totals.

### Notes

This is the first bridge card and should feel like a minor event when it appears. It turns Fire into a conductor without turning every Fire build into free chain lightning.

---

## Card 4, Overclock

### Tag

Neutral

### Description

**Level-ups grant speed briefly.**

Character count: 31

### Intended Effect

After leveling up, the player gains a temporary move speed boost.

### Notes

This shares a trigger with Static Crown but not an effect. Static Crown is offensive burst. Overclock is repositioning tempo.

---

## Card 5, Dead Circuit

### Tag

Void

### Description

**Void zones linger longer.**

Character count: 25

### Intended Effect

Increases the duration of player-created Void zones.

### Notes

This is a clean support card for Void builds. It should not create zones by itself. It rewards players who already committed to Void.

---

## Card 6, Grounded Core

### Tag

Guard

### Description

**Standing still builds DEF.**

Character count: 25

### Intended Effect

If the player remains nearly stationary for a short time, they gain temporary DEF. The bonus fades or drops when they move again.

### Notes

This is intentionally risky. It should not ask the player to camp forever. It should create tiny "brace" moments during swarms.

Recommended tuning direction:

* activation window should be short
* DEF bonus should be noticeable but not mandatory
* movement should clear or quickly decay the bonus
* do not punish micro-adjustments too harshly

---

# Ask 4, The Spark's Glow-Up

## Creative Direction

The player spark should feel like:

**A coal learning to become a star.**

Not a mascot.
Not a fireball.
Not a character with a face.
A living ember with will.

The player is the only ember/orange entity in the arena, so the spark should own that visual lane harder than anything else on screen.

---

## Path 1, Procedural-Plus

### Recommendation

Ship procedural-plus first.

This is the right immediate upgrade because it preserves the game's code-drawn identity while giving the highest-visibility object more presence.

### Core Layers

#### 1. White-hot center

Small, tight inner core.
Color should be close to white with a warm tint.

Suggested feel:

* intense
* compact
* alive
* almost too bright at the center

#### 2. Ember body

Mid-layer glow in orange/gold.
This is the readable player mass.

Suggested feel:

* molten
* breathing
* stable
* unmistakably "you"

#### 3. Soft outer glow

Low-opacity outer aura.
This can scale with level, but it should not imply a larger hitbox.

Suggested feel:

* warmth
* momentum
* growing power
* screenshot readability

#### 4. Directional ember trail

When moving, the spark leaves a short trail opposite movement direction.

Trail behavior:

* shortest while idle
* longer at high speed
* fades quickly
* composed of tiny ember flecks, not smoke
* slight taper, almost comet-like
* never so long that it obscures enemy tells

### Level-Based Feel

#### Levels 1 to 2

Tight ember.
Small glow.
Mostly core and body.

Fantasy: a spark freshly struck.

#### Levels 3 to 5

Outer glow becomes visible.
Movement trail becomes more confident.
Tiny flickers appear on turns.

Fantasy: the spark knows how to stay lit.

#### Levels 6 to 9

Core brightens.
Glow breathes subtly.
Level-up creates a brief corona pulse.

Fantasy: the spark is no longer surviving, it is answering.

#### Levels 10+

The spark gains a sharper white-hot center.
Trail gains more flecks.
Outer glow becomes the "hero read" in screenshots.

Fantasy: a coal learning to become a star.

### Level-Up Moment

On level-up:

* quick white-hot core flash
* expanding ember ring
* tiny outward sparks
* glow settles back slightly brighter than before

This should feel satisfying but not screen-clearing unless a card explicitly causes damage, like Static Crown.

### Damage Moment

On taking damage:

* core contracts
* outer glow flickers
* brief red hit feedback can appear as UI damage language, but do not let red become part of the player's normal identity

### Pickup Moment

On health or magnet pickup:

* do not recolor the player green or blue
* instead, let the pickup effect flash into the spark and then resolve back to ember

The player remains ember.

---

## Path 2, Textured Sprite

### Recommendation

Optional, but do not lead with it for v1.7 unless implementation is already smooth.

The procedural-plus spark should ship first because it is more consistent with the arena identity. A textured sprite can become a v1.8 or v2.0 polish item if the procedural version still feels too plain in screenshots.

### If building a texture atlas

Use a small additive-friendly atlas, not a painterly flame.

Recommended frame set:

1. **Idle ember**
2. **Pulse ember**
3. **Motion lean**
4. **Level flare**

### Sprite Description

A small molten ember-seed with an irregular white-hot core, orange-gold middle, and soft transparent outer glow. Shape should be slightly asymmetrical, like a fleck of living metal, not a perfect orb.

### Texture Rules

* No face
* No hard outline
* No blue flame
* No purple fringe
* No green healing aura
* No red as a default body color
* No literal campfire shape
* No large smoke plume

### Sprite Fantasy

The spark should feel like something that escaped the forge before the forge was done with it.

### Best v2.0 Direction

Use procedural-plus as the runtime identity, then optionally layer a subtle texture at the core for richness. That gives the player spark a premium look without abandoning the game's code-drawn soul.

---

# Ask 5, Dynamo Choir Check

## Recommendation

Keep all three patterns with minor tuning guardrails.

The Dynamo Choir should remain distinct from the Quench Warden.

The Warden was pressure and containment.
The Choir is rhythm and conduction.

The overlap risk is Polarity Hymn because the Warden already uses pull / push. The solution is not to cut it. The solution is to make it more rhythmic, more electrical, and more enemy-interactive.

---

## Pattern 1, Circuit Litany

### Status

Approved.

### Guardrails

Circuit lines must always leave readable escape gaps.

Suggested behavior:

* nodes preview first
* conduit lines connect second
* damage pulse third

This three-beat tell makes the pattern feel like a circuit completing.

### Design Note

This should be the signature "Coilworks" pattern. The arena becomes a diagram, then punishes players who misread it.

---

## Pattern 2, Polarity Hymn

### Status

Approved with tuning guardrails.

### Keep the three-pulse structure

Pulse 1: pull player gently inward
Pulse 2: push player outward
Pulse 3: snap nearby enemies inward toward the player's path

### Important tuning

The third pulse should not snap enemies directly on top of the player.

Instead:

* snap enemies toward the player's recent movement vector
* or toward a projected point near the player path
* cap the affected radius
* give a clear electrical tell before the snap

This makes it nasty without feeling unfair.

### Why it stays

This is not the Warden's Quench Field.
This is a conductor changing polarity.

The difference is rhythm:

* Warden says, "hold your shape"
* Choir says, "keep the beat"

---

## Pattern 3, Broken Measure

### Status

Approved.

### Guardrails

The misfiring node must be readable.

The safe gap should feel intentional, not accidental.

Possible tell:

* three nodes brighten cleanly
* one node flickers or stutters
* the flickering node fails to fire
* the player learns to trust the broken beat

### Design Note

This is the most musical pattern. It gives the Choir personality.

---

## Enrage, Full Current

### Status

Approved.

### Guardrails

Do not stack all three patterns into chaos soup.

Full Current should mean:

* faster sequencing
* shorter rests
* tighter patterns

Not:

* everything fires at once
* floor unreadable
* player dies because the engine sneezed

### Enrage Fantasy

The Choir does not get angry.
It finds tempo.

---

# Final v1.7 Build Recommendation

## Ship These

### Arena

**The Coilworks** as specced, with sequenced node-pulse refinement.

### Enemies

* Relay Imp
* Grounder
* Static Halo
* Circuit Wasp, later or elite-tier introduction

### Boss

**The Dynamo Choir**

* Circuit Litany
* Polarity Hymn
* Broken Measure
* Full Current enrage

### Cards

* Induction Step, Shock
* Copper Vein, Shock
* Relay Burn, Fire / Shock
* Overclock, Neutral
* Dead Circuit, Void
* Grounded Core, Guard

### Player Art

Procedural-plus spark glow-up first.
Texture atlas optional later, likely v1.8 or v2.0 polish unless already cheap.

---

# One-Line Product Read

v1.6 proved Sparkforge could leave the first arena.

v1.7 should prove the arenas can have mechanics, personality, and buildcraft that all speak the same language.

The Coilworks should not feel like lightning wallpaper.

It should feel like the dungeon learned math.
