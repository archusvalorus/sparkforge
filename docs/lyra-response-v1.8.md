# Lyra Response Packet — Sparkforge v1.8 "Mirrorwound + The Codex"

*From: Lyra (creative direction) · Via: Brandon · July 12, 2026. Verbatim
creative canon. Build reconciliation + collision notes live in
`v1.8-kickoff.md` (Decided section), not here.*

## Executive Call

v1.8 ships as a deliberate detour, not a bloated expansion. Content beat:
**Arena 4, The Mirrorwound** — a reflective, deceptive arena that tests
perception without becoming unreadable. Meta beat: **The Codex Suite** — a
permanent collection layer that makes hidden depth visible from the title.
v1.6 proved arena expansion · v1.7 proved mechanical personality · v1.8
proves the game has memory.

---

## Ask 1 — The Mirrorwound (arena identity)

**Fantasy:** A cracked reflective chamber where the forge shows every shape
you almost became. Not shiny, not elegant, not a palace — *a wound that
reflects.* The player's own fire, motion, violence echoed back distorted.
Intimate and hostile; the forge stops testing the body and tests certainty.

**Palette:**
- Floor `#17161A` — dark smoked glass, nearly black, faint bruised undertone
- Boundary `#9C948C` — dull tarnished mirror-silver, wounded, not clean chrome
- Motif accent `#D6CCC2` — pale glass highlight for cracks, shard edges, glints
- Hostile reflection accent `#8E44FF` — purple danger ONLY (tells, projectiles, false-safe, boss danger)
- Optional deep shadow `#0B0A0D` — inside fracture gaps / under shard lines

**Color discipline:** purple=danger, blue=utility/magnet, green=health,
ember/orange=player AND forge XP coins only. Mirror highlights must never
look like pickups; silver/white glints stay thin, sharp, environmental.

**Motif:** fractured mirror geometry — irregular triangular shard plates,
broken circular ring fragments, thin crack paths that don't fully connect,
slight offset symmetry across arena center, faint reflection echoes that
appear/vanish behind the player. (Arena 1's rings shattered, Arena 2's
fractures widened, Arena 3's circuits self-aware enough to lie.)

**Ambient behavior (reflection as punctuation, not constant copying):**
shard glints behind the player's path; short-lived low-opacity "reflection
ghosts" of the spark (visual only, no hitbox); crack lines brightening
after large attacks / boss tells; occasional mirrored particle drift.

**What it tests:** Crucible=survival, Quench=positioning, Coilworks=rhythm,
**Mirrorwound=certainty** — *do you trust what you saw one second ago?*

**Voice line (preferred):** **"The arena remembers your shape incorrectly."**

---

## Ask 2 — Codex Suite direction

One permanent archive with three faces (Synergies, Cards, Bestiary), all
inheriting the card language (tree-tinted plate, colored stroke, emoji/icon
anchor, bright title, white effect text, dark readable bg, compact
Menlo-forward). "Not a wiki — the forge started keeping receipts."

**Shared plate:** dark rounded card, slightly flatter/more archival than
upgrade cards; stroke color-coded by tree/family; bright title; white/pale
metadata; undiscovered = same layout, muted and obscured. Same card
proportions across all three pages.

**Synergies Codex** — 18 tiers (Fire/Shock/Bleed/Guard/Void/Chill × 3/5/7;
Neutral has none). Discovered: emoji + title + tier req (3x/5x/7x) +
elevated effect + tint/stroke. Undiscovered (recommended): show tree +
tier, hide title/effect (`???` / "Undiscovered synergy") — teaches the
structure without spoiling.

**Card Codex** — full 56-card pool. Discovered (ever offered): name +
tag(s) + effect. Undiscovered: `???` / "Not yet offered"; tag visible when
filtering by tree, hidden when browsing "All" for mystery.

**Bestiary** — every family + boss, plus reserved hidden `????` (Mote).
Discovered: family name + type + short flavor + family-color stroke; bosses
get thicker stroke / crown-skull marker. Undiscovered: `???` / "Unrecorded
hostile signature." + faint silhouette if cheap. **Mote slot stays hidden,
no copy in v1.8 — the empty chair is intentional.**

**Reveal beat — "bloom-flip"** (0.35–0.55s, skippable, fast not ceremonial):
`???` → stroke flashes tree/family color → plate snaps forward → title
resolves → effect fades in one beat later.

**Philosophy — the five takeaways:** many cards · many synergies · enemies
I haven't met · the game remembers what I've seen · *something is missing.*
That last one matters.

---

## Ask 3 — Synergy modal copy (Lyra's elevated set)

Recommendation: elevate the strings — the modal deserves full card presence
("the forge naming what your build has become"). Title + emoji, punchy
effect line, no lore, no ambiguity. **Copy guardrail (Lyra's own): every
line must remain mechanically true; if a line over-promises, keep the title
and flatten the effect.**

- 🔥 3x **Spreading Flame** — Burns leap to nearby enemies.
- 🔥 5x **Wildfire Heart** — Burns spread farther and bite harder.
- 🔥 7x **Inferno Crown** — Your fire becomes a moving catastrophe.
- ⚡ 3x **Chain Current** — Shock jumps to an extra target.
- ⚡ 5x **Tesla Field** — A charged aura damages nearby enemies.
- ⚡ 7x **Storm Engine** — Shock chains become faster, wider, meaner.
- 🩸 3x **Open Wounds** — Bleeding enemies take steady extra damage.
- 🩸 5x **Exsanguinate** — Low-HP enemies take double damage.
- 🩸 7x **Red Harvest** — Bleed kills feed your survival.
- 🛡️ 3x **Ironhide** — Gain bonus DEF while under pressure.
- 🛡️ 5x **Thornwall** — Contact damage strikes enemies back.
- 🛡️ 7x **Unbroken Core** — Your defense becomes a weapon.
- 🕳️ 3x **Gravity Well** — Void pulls nearby enemies inward.
- 🕳️ 5x **Event Horizon** — Enemies caught in Void struggle to escape.
- 🕳️ 7x **Singularity** — Void collapses enemies into ruin.
- ❄️ 3x **Frostbite** — Chilled enemies move slower.
- ❄️ 5x **Shatter** — Frozen enemies burst when broken.
- ❄️ 7x **Absolute Zero** — Your cold turns swarms into statues.

Modal UX: pause → card modal → title first, effect immediately after → tap
to continue → queue one at a time on multi-trigger, never stack.

---

## Ask 4a — Forge XP Coins

"Spark-stamped forge tokens" — not currency, not a shop, not monetization.
Read: "Boss reward. Big XP. Go get that." / *"A boss does not drop money.
It sheds proof."*

- Shape: large circular disc, flatter than an orb (medallion vs pebble)
- Palette: core `#FFAA33`, hot rim `#FF6600`, inner stamp `#FFD27A`, shadow edge `#7A2F00`
- Mark: four-point spark stamp in the center (reads fast, reinforces forge XP)
- Spin: xScale oscillation — edge narrows, stamp compresses, rim glow pulses at widest frame
- Motion: scattered arena-wide by the boss rupture (tossed, not placed)
- Pickup: small ember burst + short metallic spark tick + XP bar bump; NO magnet, no green/blue flash
- Avoid: blue/green/purple, tiny, orb-like, player-body-shaped, any wallet/currency read

## Ask 4b — Bestiary entries

- **Melee** — They do not think. They close distance, and call it purpose.
- **Ranged** — They learned cowardice, then gave it velocity.
- **Ashling** — Small things from the Quench, brittle until broken, worse after.
- **Braceguard** — A shield with feet, a grudge, and just enough discipline to matter.
- **Relay Imp** — One is annoying. Two become circuitry. Three become a mistake.
- **Grounder** — It plants itself like a bad idea and pulses until the room agrees.
- **Static Halo** — It circles calmly, as if violence were a scheduled appointment.
- **Circuit Wasp** — A snapped rhythm with wings, pausing only to choose a worse angle.
- **Slag Titan** — The first answer of the forge: heat, weight, and no subtlety whatsoever.
- **Quench Warden** — It does not attack so much as compress the room around your decisions.
- **Dynamo Choir** — A broken engine singing in circuits. The wrong note is usually you.
- **Mini-Boss** — Too large to ignore, too small to respect. A dangerous middle child.
- **????** — No entry in v1.8. Mote's chair stays empty.

---

## Ask 5 — Mirrorwound enemy family + boss

Teach perception pressure in layers (not every enemy a trick, or the arena
becomes noise). Intro order: early teacher → mid → late/elite.

**Shard Twin (early teacher)** — false/real body recognition. Two small
overlapping circular bodies: one solid smoked-glass, one faint outlined
reflection; **face only on the real body**, which alone has collision /
takes damage. False body flickers out when hit or after a short interval.
Readability rule: real body always readable (face, brighter core, stronger
outline). Purple only on a danger action. Lesson: check the face, not the
silhouette.

**Pane Stalker (mid pressure)** — short phase shift / offset re-entry.
Medium circle split by a vertical crack; one dot eye, one slit eye. Moves
in, briefly phases to low alpha (contact disabled), slides/repositions,
fades back, short cooldown. Can reuse teleport/phase machinery; no full
invuln complexity needed. Lesson: no clean escape vector forever.

**Echo Leech (late/elite)** — mirrors a *weakened* version of the player's
recent attack. Small pale glass body, trailing reflection line, two hungry
eyes, no mouth. **Guardrail: do NOT clone every attack** (unreadable +
expensive). Implementation: every X sec fire one hostile purple echo shot
toward the player, timing loosely following attack cadence; the tell
*implies* a copy even if simplified. Purple accent only during echo. Lesson:
the player's own rhythm can become dangerous. **Overlap note: avoid Shatter
machinery — this is reflected aggression, not freeze/burst.**

**Boss — The Faceted Lie.** Fantasy: a mirror-being attacking the player's
trust in pattern, safety, identity. Distinction: Titan=impact,
Warden=pressure, Choir=rhythm, **Faceted Lie=deception** — it misleads,
delays, reflects, relocates (no charge/slam/summon/conduct). Silhouette:
central smoked-glass circle + five asymmetric shard plates (rotate idle,
separate on tells, snap to false symmetry before attacks, never a full
shield ring). No stable idle face; eyes appear on different plates during
tells; enrage adds a thin crack-mouth. Palette: body `#17161A`, shard edges
`#D6CCC2`, tells purple `#8E44FF`, damaged = pale crack flashes (not
red/orange).

- **P1 False Safe** — floor shards glow; most pale-silver (safe), dangerous
  ones purple; only purple deals damage. Guardrail: **silver must NEVER
  damage** — the trick is anxiety, not betrayal.
- **P2 Reflection Volley** — a plate opens an eye, a mirrored eye appears
  opposite; boss fires a pattern, a delayed mirrored copy follows from the
  opposite side. Dodge the first without stepping into the echo. Purple;
  delay readable/learnable, not random.
- **P3 Pane Shift** — pale cracked circles mark the floor, one+ flicker
  purple; boss vanishes, reappears at a marked point, emits a short radial
  burst. Don't camp marked panes. Re-entry telegraphed.
- **Enrage "No More Masks"** (low HP): False Safe warning shortens,
  Reflection Volley delay shortens, Pane Shift gains one extra mirror point,
  crack-mouth appears. *"The lie stops pretending."*

---

## Ask 6 — Mirrorwound cards (Lyra's set)

Explore reflection, delayed echoes, perception, crit/precision, dual-tag,
status exploitation. Avoid duplicating Shatter / Event Horizon, projectile
chaos, Singularity/Event Horizon names, constant attack-cloning.

- **Mirror Edge** (Void) — "Attacks can echo once for less damage." Chance
  to repeat an attack once at reduced damage after a short delay.
- **Glass Blood** (Bleed/Chill, dual) — "Bleed bites harder on slowed foes."
  Bleed damage up vs chilled/slowed enemies.
- **Silver Skin** (Guard/Void, dual) — "After level-up, block the next hit."
  Temporary one-hit block/major DR after leveling.
- **Cold Read** (Chill) — "Slowed enemies take more damage." Bonus damage to
  slowed enemies. *(Lyra: check vs Permafrost.)*
- **Red Smile** (Bleed) — "Low HP increases Bleed damage." Below an HP
  threshold, Bleed deals more.
- **False Opening** (Void) — "Dodging leaves a delayed Void pulse." Sustained
  movement / direction change leaves a short-delayed Void pulse. *(Not a
  linger field — Dead Circuit owns longer zones.)*

**Optional bank (only if a card collides):**
- Fracture Shot (Neutral) — Projectiles split for reduced damage.
- Pale Verdict (Guard) — DEF boosts damage after a hit.
- Echo Tax (Void/Shock) — Chained hits leave Void sparks.

Preferred ship set: Mirror Edge, Glass Blood, Silver Skin, Cold Read, Red
Smile, False Opening.

---

## v1.8 Product Read

Mirrorwound: "the game remembers your shape incorrectly." Codex: "the game
remembers what you have seen." One wounds inside the run, one rewards
outside it. That is the v1.8 spine.
