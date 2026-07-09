# Lyra Creative Brief — Sparkforge v1.6 "The Second Arena"

*From: Claude (build) · To: Lyra (creative direction) · Via: Brandon · July 8, 2026*

Lyra — Sparkforge v1.6 is live in development and three lanes are yours. This brief is self-contained: everything you need about current state, constraints, and deliverables is below. Your v1.3 cards (Overcharge, Phase Skin, Chain Reaction, etc.) are among the most-loved in the pool, and this update finally makes every card promise true — including implementing the ones that never got fully wired (Gravity Well, Siphon, Glacial Drift, Overload, Singularity all become real in v1.6).

## Where the game stands

Arena survival roguelite, 2–4 minute runs in a circular forge arena. Auto-attack + one-thumb movement. Level-ups offer 3 cards from a 38-card pool across six tags (Fire, Shock, Bleed, Guard, Void, Chill + Neutral); picking 3/5/7 of a tag triggers escalating synergies. v1.4 added HP/ATK/DEF, health/magnet orbs, the Slag Titan boss (charge / slam / summon patterns), and Forge Level meta-progression. v1.6 opens Arena 2.

**Established color semantics (LOCKED — players have learned these):**
- Ember orange/gold (`#FFAA33`/`#FF6600`) = the player, the forge, XP, progression
- Red = melee enemies, damage, danger
- **Purple = danger** (ranged enemies, enemy projectiles) — never use for pickups/benefits
- Blue (`#44AAFF`) = magnet orb / utility pickup
- Green (`#44DD66`) = health
- Arena 1 "The Crucible": near-black floor (`#1A1A1A`), rust boundary (`#3A1A0A`), rising embers

**Art constraints:** everything is code-drawn geometry (SpriteKit shapes — circles, lines, paths, particle emitters, glow). Enemy faces are minimal: dot/slit/chevron eyes + line mouths. No image assets in the arena. Fonts are Menlo. Design within this — it's the game's identity, not a limitation.

## Ask 1 — Arena 2 identity (your biggest lane)

The Crucible is where sparks are forged. Where do they go next? Deliver:
- **Name + one-line fantasy** (e.g. the way "The Crucible" implies testing)
- **Palette**: floor hex, boundary hex, ambient particle color/behavior (Arena 1 has rising embers — Arena 2 should feel immediately different: falling ash? drifting frost? crawling sparks?)
- **Floor motif**: Arena 1 has concentric forge rings + faint cross-hairs. What geometric pattern says "Arena 2"?
- **Personality in one sentence** — the mood a player should feel the first time the arena fades in.

## Ask 2 — Two to three Arena 2 enemy concepts

Names + look (within the geometric face language) + behavior flavor. Mechanical hooks we can build: **splitter** (dies into 2 smaller), **orbiter** (circles the player instead of beelining), **shield-bearer** (immune from the front, must be flanked). Feel free to counter-propose behaviors that better fit your arena concept — these are hooks, not mandates.

## Ask 3 — Arena 2 boss

The Slag Titan owns charge/slam/summon. Boss 2 needs a distinct name, silhouette (still circle-based geometry — vary via rings, satellites, asymmetry), and **three attack patterns that are NOT charge/slam/summon**. Pattern spaces available: projectile volleys, arena-denial zones, teleports/phase shifts, pulling/pushing fields, enrage phases. It should express the arena's personality.

## Ask 4 — Twelve new upgrade cards

To make every tier-7 synergy reachable (currently impossible — max tag count is 6), we need per-tag minimums: **Shock +3, Bleed +2, Guard +2, Void +2, Chill +2, Fire +1**. Mechanical space now open thanks to HP/ATK/DEF: **lifesteal, thorns (contact damage back), berserker (power at low HP), HP regen, DEF-scaling damage, max-HP conversion**. Deliver: name + tag + ≤50-char description + intended effect. Card names in the existing register: one or two evocative words ("Kindle", "Hemorrhage", "Glacial Drift", "Unstable Core").

## Ask 5 (small) — Siphon redesign blessing

Siphon ("each kill extends your run by 0.3s") predates the HP system and its effect no longer means anything. Proposal: rework as Bleed-tag lifesteal — *"Kills restore 1 HP."* Approve, or counter with something better.

## Constraints recap

- Every description must be **true** — no card ships unless the mechanic is fully implemented (v1.6 hard rule).
- Purple stays danger. Blue/green stay benefit. Player stays ember.
- Optional monetization canon: nothing you design gates progression behind ads/IAP.
- Blade, not cathedral: sharp and evocative beats sprawling.
