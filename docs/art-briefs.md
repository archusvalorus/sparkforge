# Art Briefs — v2.0

*Companion to `character-art-playbook.md`. The playbook explains **how** we cut
and wire assets; this file records **what we asked for and why**. Written Jul 27
2026 with the panda kaiju freshly shipped and the context hot across all three
of us — deliberately drafted in one sitting so the thread doesn't get lost
between chunks.*

**How to use:** send the SHARED TECHNICAL block plus the one brief you're
working on. Order below is leverage order — each brief reuses what the one
before it established.

---

# SHARED TECHNICAL — attach to every brief

- **Transparent background.** Double-check on export: a white matte and true
  alpha look identical in a viewer and behave completely differently over a dark
  arena.
- **No baked effects** — no fire, glows, auras, shadows or ground contact
  shading. The game draws every effect in code so it can pulse and react. This
  also means art never needs re-doing when an effect changes.
- **Same canvas size for every frame in a set.** 1024×1536 works well.
- **Consistent registration — the critical one.** Every frame in a set needs the
  same ground contact and the same body centre on the canvas. If frames drift,
  the character visibly teleports between them and walk cycles jitter. Anchor
  deliberately.
- **Walk and attack frames face RIGHT.** The game mirrors for left. Idle may be
  front-facing.
- **Pixel-art rendering style**, matching the panda kaiju.
- **Silhouette first.** Render sizes are small (each brief states its own); fine
  detail below ~4px on screen does not survive the downsample.

---

# 1. Ordinary Pandas — Panda tree T1–T4 · 76pt across (~228px @3x)

The pandas that wander in at tiers 1–4, before the T5 kaiju transformation.
Same species as the kaiju — **deliberately not the same character.**

### Creative direction

Ordinary pandas are **the joke**. They amble into an active battlefield, do one
mildly useful thing, and leave. Sometimes the mildly useful thing is standing
there looking pleased with themselves.

- **Vacant, content, faintly unhelpful.** Comfortable. Unbothered. Mild.
- **No aggression** — no snarl, no bared teeth, no combat readiness.
- **No fire, no glowing eyes.** Those belong to the transformation.
- **No regalia** — no gold belt, sigil, armbands or red cord. The kaiju's
  ornaments mark it as *transformed*; an ordinary panda is just a panda who
  turned up.

Keep the kaiju's construction, proportions and black/white masses so they read
as the same species. If it looks like a smaller kaiju it's wrong; if it looks
like it wandered out of a nature documentary and hasn't noticed the fighting,
it's right.

### Frames

- **Idle ×3, front-facing** — neutral / inhale / exhale. Plays `1 → 2 → 1 → 3`.
  Keep differences restrained; code adds breathing scale on top.
- **Walk ×4, right-facing** — a lumbering, unhurried amble. Heavy, waddling, in
  no hurry whatsoever.
- **No attack frames.** Ordinary pandas don't fight.

---

# 2. Panda Samurai — Panda tree T4, 5% · 76pt across

The crown jewel of the secret tree. Walks **calmly** to one target, strikes
once, **bows**, and leaves. It is never explained in-game, ever.

### Creative direction

**Played completely straight.** This is the only panda with intent, and the
comedy comes entirely from its sincerity — a solemn ritual execution conducted
in the middle of chaos, by a panda, who then bows and leaves without comment.

- **Gravitas and absolute calm.** Composed, unhurried, certain.
- **It should not look funny.** The moment it mugs for the camera, the joke
  dies. Play it as though it belongs in a different, much more serious game.
- **Minimal marks of station** — a bamboo sword, and at most a simple headband
  or plain sash. Not the kaiju's full regalia. Restraint reads as discipline.
- Level gaze or eyes half-closed. No snarl. No glowing eyes.

### Frames

- **Approach ×4, right-facing** — a *measured, deliberate* walk. Distinctly
  different cadence from the ordinary panda's amble: this one knows where it's
  going.
- **Strike ×3, right-facing** — draw (blade raised, weight settling) / cut (full
  extension, follow-through) / sheathe (returning to stance). Same slow-fast-slow
  rhythm as the kaiju's swing.
- **Bow ×2** — upright, then bowed. **The bow is essential**; it's the punchline
  of the entire sequence.

---

# 3. Mountain Lion — Nature Canon jackpot pet · 76pt across

The 5% tier of the Tree capstone's animal roster. Roams the arena ~10s mauling
on contact, then leaves.

### Creative direction

**Play this one straight too.** It arrives among rabbits, squirrels and a
bluebird — the contrast *is* the joke, so the lion itself should be genuinely
impressive rather than comic.

- **A real predator.** Low, powerful, prowling. Shoulders working.
- Tawny and muscular; it should feel like the arena just got more dangerous.
- No cartoon exaggeration, no goofy expression. It has no idea it's in a comedy.

### Frames

- **Prowl ×4, right-facing** — a stalking walk cycle, low to the ground.
- **Maul ×2, right-facing** — lunge and strike. Brief and violent.
- **Idle ×2, right-facing** — a settled standing pose for when nothing's in
  reach. Minimal.

---

# 4. Nature Canon Animals — nine, ONE frame each · 50pt across (~150px @3x)

Launched from the Tree's canopy at a target, ~0.45 seconds of flight, then
impact. **One frame each — they are projectiles, not characters.** Nine animals
× a full animation suite would be ~100 assets nobody can perceive.

### Creative direction

Each one is drawn **mid-action, in the pose that expresses its move**, always
right-facing. Comic energy, slight exaggeration, absurd conviction. These need
to read as their species instantly at a glance — silhouette is everything.

The set (with its in-game move, for pose reference):

| Animal | Move | Pose |
|---|---|---|
| 🐰 Rabbit | "Ninja Kick" | mid-flying-kick, leg fully extended, absolute commitment |
| 🐿️ Squirrel | "Scatter" | mid-leap, arms flung wide, about to fling acorns |
| 🦊 Fox | "Homing Fur-Missile" | streamlined, ears flat, legs trailing — an actual missile |
| 🦌 Deer | "Trample" | antlers-first, head lowered, charging |
| 🦫 Boar | "BOAR GORE!" | head down, tusks forward, full barrel-charge |
| 🦔 Hedgehog | "Needle Barrage" | braced and squat, spines flared — it posts up and fires |
| 🐦 Bluebird | "WTFROFLSTOMP" | tiny, wings spread, diving. **Small — the mismatch with its enormous blast is the joke** |
| 🦨 Skunk | "Persist" | tail raised high — the universal skunk tell, readable at any size |
| 🦡 Badger | "Thief" | mouth open, lunging, unreasonably confident |

The emoji placeholders these replace were genuinely funny at this size, and
players giggled at them in testing. **Match that energy** — do not make them
serious or realistic.

---

# 5. Skins — two Spark cosmetics · 32pt across (~96px @3x)

Both unlock by reaching Panda T5 once. **Cosmetic only** — they never change
hitbox, speed, or anything mechanical (studio canon).

⚠️ **These are TINY.** 32pt is the smallest thing in this document — roughly
96px at @3x. Silhouette and two or three high-contrast shapes are the entire
budget. Anything finer is invisible.

### 5a. Earned — "Panda Mask" (free)

Spark wearing **only a panda mask**, otherwise completely normal. That's the
whole gag: the ember Spark you've played for five versions, now with a panda
mask on, and nothing else about him has changed. Deliberately low-key,
deliberately ridiculous.

- Essentially: two black ear shapes and two black eye patches, fitted to Spark's
  round body.
- Should read as *"he's wearing a mask"*, not as *"he became a panda."*
- One frame. No animation.

### 5b. Premium — "Mini Kaiju" (purchase)

A **miniaturised flaming panda kaiju** as Spark's body. Higher fidelity, badass,
absurd at this scale — the whole appeal is that it's the T5 monster shrunk to
the size of a marble and taken completely seriously.

- Derive from the kaiju art. Keep the glowing eyes and the forehead mark; drop
  everything that won't survive 96px.
- **No baked fire** — the game already draws it.
- Idle ×2 if a subtle breathe is cheap; otherwise one frame is fine.

---

## Sequencing note

Leverage order, as drafted: ordinary pandas establish the non-transformed panda,
the samurai is that plus a sword and gravitas, the lion is standalone, the nine
animals are cheap single frames, and the skins derive from work already done.
Each brief reuses the one before it — worth keeping that order if the set gets
split across sessions.
