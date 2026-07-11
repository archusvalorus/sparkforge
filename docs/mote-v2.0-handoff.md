# Sparkforge v2.0 Roadmap Insert — MOTE

*Lyra handoff via Brandon, July 11, 2026. Verbatim below the divider.
Slotted as the #1 v2.0 non-negotiable. Artwork incoming from Brandon.*

*Claude build-side dependency notes (for v2.0 scoping — not design
changes, the design is canon):*

1. **Bestiary is a hidden prerequisite.** No bestiary system exists
   yet — Mote's permanent ????-entry implies building the bestiary
   itself (likely its own v2.0 unit, and arguably a feature players
   want anyway for the 12+ enemy families we'll have by then).
2. **Revive-ad interplay must be decided at scoping.** The scripted
   first kill is an unlock-by-assassination — offering the rewarded
   revive on that death would break the bit (and a revive that Mote
   immediately re-kills is a different, crueler bit). Recommendation:
   the scripted Mote death suppresses the revive offer entirely; the
   special result copy IS the reward. Later rare appearances: decide
   per-trigger.
3. **Trigger plumbing mostly exists**: lifetime kills (totalKills),
   boss kills (bossKills), Arena 5 boss kill (unmadeStarKills — bank
   the key when Arena 5 ships, same pattern as warden/choir). The
   scripted sequence (wipe, quiet, entrance, one-shot) maps cleanly
   onto the existing boss-entrance + stage-clear machinery.
4. **Purple canon check**: purple = danger holds (Mote IS danger);
   the silhouette/behavior distinction from ranged enemies is the
   design requirement — Lyra already flagged it below.
5. **Analytics**: tag Mote encounters in run data — this is THE
   shareable moment; we'll want to know how many players have met him.
6. **Studio canon (source of truth):** Notion "Mote — Studio Mascot
   Canon" (39a87a89-786e-81c1-a24f-fd97a4f74cf4). Mote predates this
   handoff — live on the Forgebound Labs site hero art since ~May 2026,
   with planned roles in Delve (Floor 1000 companion) and Chaos
   Confluence (uncontrollable party member with hidden preferences).
   Sparkforge's assassination intro is one game's slice of a
   cross-project mythology. Visual DNA is canon there: floating body,
   black void face, glowing purple eyes, cracked horn crown, tattered
   cloak, THREE-fingered hands, purple arcane over greyscale, slight
   asymmetry GOOD — do not over-polish. Character sheet + hero render
   exist as Lyra exports (on the canon page).
7. **Asset pipeline note:** Mote is the natural first textured sprite
   in Sparkforge — the Assets.xcassets atlas pipeline we deferred from
   the spark glow-up (Phase B) has its real customer here. A code-drawn
   Mote would violate "don't over-polish" in the wrong direction; the
   character sheet exists, use it.

---

# Sparkforge v2.0 Roadmap Insert

## Non-Negotiable Feature: Mote Introduction

## Priority

**#1 v2.0 Non-Negotiable**

Mote must be introduced in v2.0 as Sparkforge's mascot, hidden nemesis, and first true "what the hell just happened?" mythology moment.

This is not optional polish. This is a brand-defining feature.

---

# Core Concept

Mote is the game's tiny whimsical murderbeast: small, white/purple, cute, rude, and catastrophically dangerous.

He should not enter as a tutorial guide, shop mascot, or friendly helper.

He enters by killing the player.

Specifically, after the player has proven deep mastery, Mote appears out of nowhere and one-shots them with prejudice.

The moment should feel funny, shocking, unfair in a clearly intentional way, and immediately memorable.

The player should understand:

**This was not a normal enemy.**
**This was not a normal death.**
**Something noticed me.**

---

# First Appearance Trigger

Mote's first appearance should require meaningful lifetime and run mastery so the joke does not punish new players.

Proposed unlock criteria:

* 10,000 lifetime kills
* 10+ lifetime boss kills
* Defeat the Arena 5 boss, The Unmade Star

After the Arena 5 boss dies, do not immediately overwhelm the player with normal post-boss bonus waves.

Instead:

1. Wipe active enemies.
2. Slow incoming waves or pause pressure briefly.
3. Let the player exhale.
4. Create a strange quiet.
5. Then Mote appears from offscreen.
6. Mote rushes the player.
7. Mote kills the player instantly.

This is a scripted death-reveal moment.

It is not a balance failure.
It is an unlock-by-assassination.

---

# First Appearance Feel

The sequence should feel like:

The player beat the deepest known challenge.
The arena went quiet.
The run seemed to enter bonus mode.
Then the game revealed there is something beyond bosses.

Mote is not introduced with a grand boss bar.

Mote should feel smaller than expected, faster than expected, and ruder than expected.

Design read:

**You were not defeated. You were interrupted.**

---

# Mote Voice

Mote speaks in short speech bubbles after killing or interrupting the player.

Tone:

* cheeky
* rude
* playful
* not edgy
* not cruel
* funny enough that the player laughs while saying, "you little shit"

Canonical first-line candidate:

**"Bet that hurt, heehee!"**

Additional possible lines:

* "Boop."
* "Found you."
* "Nope!"
* "That looked important."
* "You were doing great!"
* "Tiny but decisive."
* "Try dodging existence."
* "Aww, you had momentum."
* "Deleted with love."
* "The anvil said no."
* "I'm baby."
* "Anyway."
* "Mote wins."

Mote should be funny-rude, not mean-rude.

---

# Bestiary Entry

Mote should receive a bestiary entry, but it should never meaningfully unlock.

Permanent entry:

**Name:** Mote
**Family:** ????
**Age:** ????
**Abilities:** ????
**Description:** ??????????????????????????

This should remain unresolved forever.

Do not gradually reveal his lore.
Do not explain what he is.
Do not let the player solve him.

The mystery is part of the joke and part of the mythology.

---

# Post-First-Encounter Behavior

After the first scripted Mote death, Mote may become eligible for rare future appearances based on defined criteria.

Possible future appearance triggers:

* Rarely after boss kills
* Rarely during post-boss bonus phases
* After unusually high kill counts
* After extremely efficient screen clears
* After activating absurd synergy stacks
* After long survival streaks
* During special milestone runs
* Very rarely in menu or UI moments as a visual gag

Guardrail:

**Mote should almost never interrupt normal progression before the player has earned the joke.**

First appearance should be mythic and scripted.
Later appearances can be rare, stupid, hilarious, and rude.

---

# Mechanical Identity

Mote is not a normal enemy.

Mote is not a standard boss.

Mote is a hidden nemesis / mascot entity.

His primary function in v2.0 is:

* create a memorable milestone
* give Sparkforge a mascot with teeth
* establish that the game has secrets beyond visible progression
* add humor and mythology without adding exposition
* create screenshot/share/discussion bait

Player-facing interpretation:

**Mote is the thing that lives behind the game.**

---

# Visual Identity

Mote should be visually distinct from normal enemies and pickups.

Known direction:

* white and purple whimsical murderbeast
* tiny
* cute
* readable at speed
* dangerous despite size
* not confused with pickups
* not confused with normal purple ranged enemies

Because purple is already danger-coded, Mote can use purple as part of his danger identity, but he needs a distinct silhouette and behavior language so he does not read as a normal projectile/enemy.

He should feel like:

* cosmic lint
* murder fairy
* anti-tutorial mascot
* tiny impossible bastard
* cute thing that should not be able to do what it just did

---

# Death Screen / Result Copy

The Mote death should not use only the normal death presentation.

Possible special result copy:

* **MOTE FOUND YOU**
* **THE SPARK WAS SEEN**
* **YOU WERE COUNTED**
* **SOMETHING SMALLER THAN YOU ENDED THE RUN**
* **MOTE WINS**
* **THE FORGE GIGGLED**

Preferred tone: funny, ominous, and screenshot-worthy.

This should feel like the player unlocked a secret, not simply lost a run.

---

# Roadmap Role

Mote should be introduced in v2.0 because v2.0 is the product cohesion milestone.

By then the player has experienced:

* Arena 1, heat
* Arena 2, pressure
* Arena 3, current
* Arena 4, reflection
* Arena 5, gravity / mastery

Mote arrives after mastery.

He is the proof that mastery is not the end of Sparkforge's world.

---

# Design Thesis

Most mascots enter by waving.

Mote enters by deleting the player.

That is the joke.
That is the brand.
That is the hook.

Mote should become Sparkforge's mascot, nemesis, mystery box, and rude little signature.

Do not overexplain him.
Do not soften him.
Do not make him safe.

Mote waves after the hit.
