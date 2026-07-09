# Lyra Creative Pass — Sparkforge v1.6 (CANON)

*Delivered July 8, 2026 via Brandon. This is the binding creative source for Units 3–6. Build annotations at the bottom are Claude's; everything above the annotation line is Lyra's design, preserved as delivered.*

---

## Arena 2 — The Quench

**One-line fantasy:** The place where fresh sparks are cooled, hardened, and judged by pressure instead of flame.

**Core idea:** Arena 1 says *survive the fire.* Arena 2 says *hold your shape after the fire leaves.* Cooler, quieter, more severe. Metal dropped into a black basin, steam gone silent, ash falling like verdicts.

**Palette:**
- Floor: `#11151A` — quenched iron, cool charcoal (deliberately not blue enough to read as pickup language)
- Boundary: `#6A6256` — ash-silver stone, dead metal rim
- Ambient particles: `#D8D0C4` — soft falling ash; slow downward drift, slight lateral sway, tiny fade-out puffs near the floor
- Accent flashes: pale amber sparks only on player-side progression (XP, level-ups)

**Color discipline (unchanged, LOCKED):** purple = enemy danger only · blue = magnet/utility only · green = health only · ember orange/gold = player/forge/XP/progression.

**Floor motif — quench rings and stress fractures:** three faint uneven concentric rings slightly offset from center; thin radial fracture lines; four shallow diagonal cooling channels (not a full grid); occasional ash flecks sliding along fracture paths. *"This place has cooled too quickly, and something beneath it remembers the heat."*

**First-impression mood:** the forge stopped roaring, and somehow that made everything worse.

## Arena 2 Enemies

1. **Ashling** (splitter) — small gray-black circle, ember-pin eyes, cracked mouth, sheds ash motes while moving. Beelines; on death splits into two faster, fragile **Ashling Shards** (single-dot faces). *Teaches: killing is no longer always clean.*
2. **Cinder Halo** (orbiter) — medium dark core with an offset rotating broken-halo ring, narrow slit eyes. Drifts into orbit around the player at medium range, tightening over time. *Creates movement pressure without copying ranged enemies.*
3. **Braceguard** (shield-bearer) — heavy circle with thick front-facing arc shield, one tiny eye visible above the shield line. Immune/heavily resistant from the front; vulnerable from behind and sides; slowly rotates toward the player while advancing. *Introduces positional thinking.*

## Arena 2 Boss — The Quench Warden

**Fantasy:** a cold forge sentinel. Measures, compresses, redirects, denies space. The Slag Titan feels like *impact*; the Quench Warden feels like *containment*. Personality: procedure, not rage.

**Silhouette:** dark quenched-iron disk; one large broken outer ring rotating clockwise; three smaller satellite nodes orbiting unevenly (part of the body language, NOT summons); a single horizontal slit eye that opens into a thin amber line during attacks.

**Pattern 1 — Pressure Lanes** (arena denial): outer ring stops rotating; thin pale ash lines appear in parallel lanes across the floor; after a warning, lanes ignite with cold-white pressure bands that damage on contact. Player reads safe lanes and moves with intention.

**Pattern 2 — Cinder Aperture** (projectile volley): satellites lock into a triangle; eye opens; each satellite fires slow ember-gray projectiles in rotating arcs with readable gaps — a spiral dodge pattern. Player threads volleys instead of fleeing.

**Pattern 3 — Quench Field** (pull/push field): floor rings brighten; expanding field pulses — pull inward, push outward, brief reverse. Player must correct momentum and avoid being shoved into enemies or lanes.

**Enrage — Final Temper** (low HP): ring cracks and spins faster. No new tools: lanes come faster, aperture arcs tighten, field warnings shorten. *Same tools, less mercy.*

## Twelve New Cards

| # | Name | Tag | Description | Intended effect |
|---|------|-----|-------------|-----------------|
| 1 | Arc Wake | Shock | Movement leaves brief damaging sparks. | Drop short-lived spark nodes while moving; minor Shock damage on touch |
| 2 | Static Crown | Shock | Level-ups release a Shock burst. | Circular damage pulse on level-up |
| 3 | Live Wire | Shock | Attacks chain to 1 nearby foe. | +1 chain target at reduced damage |
| 4 | Blood Price | Bleed | Deal more damage below half HP. | Damage bonus while HP ≤ 50% |
| 5 | Open Vein | Bleed | Bleed kills burst damage nearby. | Bleeding enemies explode on death |
| 6 | Iron Bloom | Guard | DEF sends damage back on contact. | Thorns scaling with DEF |
| 7 | Aegis Pulse | Guard | High DEF releases guard pulses. | Periodic pulse, damage scales with DEF |
| 8 | Null Bloom | Void | Kills leave brief slowing zones. | Chance on kill to spawn a short slow zone |
| 9 | Mass Tax | Void | Max HP adds Void damage. | Portion of max HP converts to bonus damage |
| 10 | Hoarfrost | Chill | Regen 1 HP every 12 seconds. | Fixed-timer regen |
| 11 | Whiteout | Chill | Chilled kills slow nearby foes. | Slow burst when a slowed enemy dies |
| 12 | Cauterize | Fire | Low HP slowly regenerates. | Regen while at low HP |

**Siphon redesign: APPROVED** — "Kills restore 1 HP." *"Bleed becomes the tag that turns violence into sustain… survival by extraction."* (Matches Unit 2 implementation exactly.)

**Creative throughline:** The Crucible tests whether you can survive. The Quench tests whether you can keep your shape. *"v1.6 should feel like the first proof that the game can keep unfolding without getting bigger for the sake of bigger."*

---

## Build Annotations (Claude, Unit 3+ implementation mapping)

Tag counts after this drop: every tag reaches exactly **7 cards** → all tier-7 synergies become reachable (requires full tag devotion — correct rarity for capstones).

**⚠️ Design collision flagged to Brandon/Lyra:** *Live Wire* is functionally identical to the existing *Arc* (shock_2, "Hits chain to 1 nearby enemy at 50% damage"). Implementation will be `chainTargets += 1` so the two STACK (Arc + Live Wire + Charged synergy = 3 chains) — mechanically sound and honest, but the near-duplicate card text is worth a naming/desc tweak if Lyra wants distinctness.

**Tuning values chosen at build time (adjust in playtest):**
- Arc Wake: spark node every 0.25s while moving, lives 1s, 1 dmg on touch (reuses chill-trail pattern)
- Static Crown: level-up burst radius 90, damage 2
- Blood Price: +30% damage while HP ≤ 50%
- Open Vein: burst radius 40, damage 2
- Iron Bloom: thorns = max(1, DEF / 3) on contact
- Aegis Pulse: every 4s, radius 70, damage = max(1, DEF / 5)
- Null Bloom: 30% chance, zone radius 35, 40% slow, 1.5s (reuses well visuals, no pull)
- Mass Tax: converts 20% max HP → +30% damage (Glass-Engine-family risk card)
- Hoarfrost: +1 HP / 12s · Cauterize: +1 HP / 3s while HP < 30%
