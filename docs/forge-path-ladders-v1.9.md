# Sparkforge Forge Path — Authored Ladders, Levels 1–20

*From: Brandon + Lyra · To: Claude · Version target: **v1.9 "The Deepening"** ·
Status: creative design LOCKED, numbers configurable for playtest. Preserved
verbatim in-repo. Supersedes the [strawman](forge-path-tree-strawman.md) and
builds on the shipped Unit 7 foundation (any-time screen + free respec +
"mastery points").*

## 1. System structure

Replace the infinite two-node cycle with **three authored vertical ladders** —
Vitality (endure), Ferocity (strike), Cunning (outplay). Each Forge Level grants
**one mastery point**; the player chooses the branch. **Milestone forks occur
every 5th point invested *within a branch*, not every 5th global Forge Level**
(so FL15 could reach one branch's 3rd fork, or the first fork in all three).

**v1.9 scope:** author + ship Vitality/Ferocity/Cunning **1–20**, four forks each
(at 5, 10, 15, 20). Architecture must stay **expandable without data-model
changes**. Long-term: up to 50 authored nodes/branch · **100 mastery points max**
across all branches · free respec any time · **Forge Level 100** = account summit.
Do NOT author 21–50 yet — let player data inform later ladders.

## 2. Guiding principles

- **Permanent power is a tailwind, not a replacement** for card drafting,
  synergies, tiers, capstones, movement skill, arena/boss mastery. A developed
  account feels *more capable*, not *exempt*.
- **Behavioral depth beats stat inflation.** Ordinary nodes = restrained,
  predictable stats. Forks + behavioral nodes carry the personality.
- **No elemental prescription** — never favor Fire/Shock/Bleed/Guard/Void/Chill/
  Growth or any future tree.
- **No synergy/capstone contamination** — Forge Path grants no tags, advances no
  synergy thresholds, improves no specific capstone, guarantees no cards, never
  bypasses breadth-vs-depth. Permanent and in-run progression stay separate.
- **Forks are preferences, not answers** — two viable forms of power
  (prevention/recovery, swarms/bosses, consistency/volatility, planning/adaptation),
  never useful-vs-weak or fun-vs-required-tax.
- **Free respec is part of the design** — adapt for arenas, Boss Mode, seasonal
  mechanics, preference, experimentation. Meaningful choices are safe when not
  permanently punished.

## 3. Global number & tuning rules

**Ten-level stat bands** — standard node values step up only when entering a new
ten-level band; all nodes in a band share the base value. Avoids stat bloat.

| Category | 1–10 | 11–20 | 21–30 | per +10 band |
|---|---|---|---|---|
| Vitality Max HP | +5 | +6 | +7 | +1 |
| Vitality DEF | +2 | +3 | +4 | +1 |
| Ferocity flat ATK | +1 | +2 | +3 | +1 |
| Ferocity % damage | +1% | +1.5% | +2% | +0.5pp |
| Cunning crit/move % | +1% | +1.5% | +2% | +0.5pp |

Pickup radius / other utility may use separate values but the same restrained
philosophy.

**Stacking philosophy:** Forge Path bonuses stack **additively** with each other;
major in-run multipliers combine separately/multiplicatively; damage reduction
uses a defined stacking order + **effective cap**; permanent crit/move/reroll
grants get **sensible ceilings**; internal-cooldown effects stay configurable.
Goal: no pile of small permanent bonuses combining into accidental invulnerability,
runaway speed, or runaway damage.

## 4. Vitality — "How do you prefer to endure?"

Supports Max HP · DEF · healing efficiency · impact prevention · pressure
resistance · emergency recovery. Must not make the player immortal or replace Guard.

1. **Tempered Vessel** — +5 Max HP
2. **Iron Bones** — +2 DEF
3. **Deep Reserve** — +5 Max HP
4. **Reinforced Frame** — +2 DEF
5. **FORK — Recovery or Prevention**
   - A. **Regenerator** — recover 1 HP every 8s.
   - B. **Braced Impact** — the first damaging hit every 12s deals 25% less.
6. **Tempered Blood** — +5 Max HP
7. **Layered Plating** — +2 DEF
8. **Durable Core** — +5 Max HP
9. **Hardened Shell** — +2 DEF
10. **FORK — Preserve Strength or Survive Danger**
    - A. **Vital Surplus** — while above 75% HP, +5% damage reduction.
    - B. **Last Stand** — while below 35% HP, +10% damage reduction.
11. **Deepened Vessel** — +6 Max HP
12. **Forged Spine** — +3 DEF
13. **Restoration** — +5% healing received (all sources; generates no healing itself).
14. **Steady Pulse** — after 10s without damage, recover 2 HP.
15. **FORK — Crowd Pressure or Priority Threats**
    - A. **Hold the Line** — with 5+ enemies nearby, +8% damage reduction.
    - B. **Giantkiller's Guard** — take 10% less damage from bosses/minibosses/elites.
16. **Iron Lungs** — +6 Max HP
17. **Tempered Plate** — +3 DEF
18. **Defiant Recovery** — after taking damage, +10% healing received for 4s.
19. **Unshaken** — −10% duration of slows/roots/stuns/supported impairments.
    *Fallback if broad status-duration reduction unsupported: −10% slow duration only.*
20. **FORK — Emergency Recovery or Impact Insurance**
    - A. **Second Breath** — once/45s, falling below 25% HP restores 10% Max HP.
    - B. **Unyielding** — once/45s, the next hit >20% Max HP is halved.
    *Neither is a revive / death-prevention mechanic.*

## 5. Ferocity — "How do you prefer to finish the fight?"

Supports restrained ATK/damage growth · aggression under pressure · swarm/boss
preference · momentum · burst · repeated-target pressure. Not an elemental branch.

1. **Whetted Edge** — +1 ATK
2. **Stoked Furnace** — +1% damage
3. **Honed Point** — +1 ATK
4. **Bellows** — +1% damage
5. **FORK — Risk or Reliability**
   - A. **Berserker** — while below 50% HP, +5% damage.
   - B. **Executioner** — +2 ATK.
6. **Tempered Edge** — +1 ATK
7. **Furnace Pressure** — +1% damage
8. **Keen Steel** — +1 ATK
9. **Full Bellows** — +1% damage
10. **FORK — Swarms or Priority Targets**
    - A. **Cleaver** — +8% damage while 4+ enemies nearby.
    - B. **Headsman** — +10% damage to bosses/minibosses/elites.
11. **Forged Edge** — +2 ATK
12. **White Heat** — +1.5% damage
13. **Rising Heat** — a kill grants +1% damage for 3s, stacks to 5, kills refresh.
14. **Opening Blow** — +10% damage to enemies above 90% HP (not an execute).
15. **FORK — Momentum or Patience**
    - A. **Bloodrush** — a kill grants +5% attack speed for 4s, stacks to 3, refresh.
    - B. **Cold Fury** — every 8s without a kill, +10% damage to the next enemy hit (consumed on hit).
16. **Hammered Point** — +2 ATK
17. **Roaring Furnace** — +1.5% damage
18. **Relentless Pressure** — repeatedly hitting the SAME enemy: +1%/stack to that
    target, up to +5%. Rules: ≤1 stack / 0.5s; reset on target change; reset after
    a configurable no-damage gap. (Prevents multihit/DOT from instantly maxing it.)
19. **Overkill** — on kill, transfer up to 25% of excess damage to nearby enemies
    (cap relative to ATK). Executions / extreme capstone hits must not chain-explode.
20. **FORK — Sustained Assault or Decisive Impact**
    - A. **Warpath** — after 6s of continuous damage, +10% damage; expires 2s after damage stops.
    - B. **Killing Stroke** — every 12s, the next eligible DIRECT attack deals +75%.
      Not consumed by DOT / summons / environmental / passive-aura / unrelated effects.

## 6. Cunning — "How do you prefer to control the run?"

Supports crit consistency · movement · pickup comfort · timing · volatility · draft
flexibility · threat response. Must not become universally-correct by combining
combat + economy + draft control too efficiently.

1. **Keen Eye** — +1% crit chance
2. **Light Step** — +1% move speed
3. **Sharp Focus** — +1% crit chance
4. **Fleet Footing** — +1% move speed
5. **FORK — Precision or Mobility**
   - A. **Deadeye** — +10% critical damage.
   - B. **Windrunner** — +3% move speed.
6. **Clear Sight** — +1% crit chance
7. **Quickened Step** — +1% move speed
8. **Long Reach** — +5% pickup radius
9. **Practiced Motion** — +1% move speed
10. **FORK — Collection or Escape**
    - A. **Magnetized** — +15% pickup radius.
    - B. **Slipstream** — after a near-miss (contact/projectile), +8% move speed for 2s (rec CD 4s).
      *Fallback if near-miss unsupported: after 6s avoiding damage while enemies near, +8% move speed 2s.*
11. **Trained Eye** — +1.5% crit chance
12. **Swift Form** — +1.5% move speed
13. **Opportunist** — +5% damage to enemies in a recognized control/impairment state
    (slow/freeze/root/stun/pull/containment/mark/etc.). Broad + modest; favors no one tree.
14. **Efficient Sweep** — collecting XP grants +5% pickup radius for 2s, stacks to 3,
    refresh (does NOT increase XP quantity).
15. **FORK — Consistency or Volatility**
    - A. **Calculated Strike** — every 5th eligible DIRECT attack is a guaranteed crit
      (not DOT/summons/environmental/passive-aura).
    - B. **Lucky Break** — crits have a 10% chance to deal +50% crit damage.
16. **Refined Focus** — +1.5% crit chance
17. **Effortless Motion** — +1.5% move speed
18. **Read the Room** — when an elite/miniboss/boss enters, +8% move speed for 4s
    (once per qualifying appearance).
19. **Salvager** — Forge XP Coins / meta drops attracted from 10% farther.
    *Fallback if they use normal pickup radius: they move 10% faster after entering range.*
    Improves comfort, not quantity.
20. **FORK — Planned Flexibility or Emergency Adaptation**
    - A. **Foresight** — +1 reroll per run.
    - B. **Second Look** — once/run, passing on a whole card offer regenerates a fresh offer free.
    *Neither guarantees a particular card/tag/tree/capstone.*

## 7. Branch identity summary

- **Vitality** (endure): recovery/prevention · preserve/survive · crowd/priority · emergency-recovery/impact-insurance.
- **Ferocity** (finish): risk/reliability · swarms/priority · momentum/patience · sustained/decisive.
- **Cunning** (control): precision/mobility · collection/escape · consistency/volatility · planned/emergency.

Branches should feel like **philosophies, not colored stat columns.**

## 8. Forge Level 100 — Eternal Ember

After all 100 mastery points are spent, unlock **Eternal Ember**: a *modest* flat
% to all base stats (rec **+2%**), a unique cosmetic/aura, a Codex/profile frame,
a prestige title/emblem. Gameplay bonus stays restrained; cosmetic + prestige
carry the emotional weight. Don't force every future arena/boss to be balanced
around a huge permanent advantage.

## 9. Implementation notes

**Persistence:** preserve `sf_forge_path_picks` (live key — never rename). Add a
**companion record for fork selections**. Respec clears branch allocation + stored
fork choices + applied bonuses.

**Data shape:** each branch = an ordered list of authored nodes. A node identifies:
branch · branch level · display name · effect type · effect value · isFork ·
fork option A · fork option B · optional cooldown · optional condition · optional
cap · optional engine-support note.

**UI:** each branch = a vertical ladder — node 1 top, connecting lines, clear
current position, locked future nodes visible, every 5th node a fork, selected
fork path highlighted, free respec accessible, confirm modal reused for forks.

**Configuration:** ALL numbers configurable — especially damage reduction, regen,
cooldowns, conditional damage, attack/move speed, crit chance/damage, pickup
radius, reroll grants, trigger thresholds.

## 10. Final thesis

The Forge Path is **not a second card system** — it's the player's permanent
handwriting beneath every run. Ordinary nodes = restrained, reliable progression;
forks = the player's stated preferences. Visible, personal, freely revisable, and
bounded enough that the arenas stay dangerous.

> **Permanent progression should make the player feel prepared, not preordained.**

---

*Build note (Claude): ships on the Unit 7 foundation (any-time screen, free
respec, mastery-point economy). Biggest lifts: (1) data-model swap — authored
ordered ladders + fork storage replacing `ForgePathManager` cycles; (2) ~two
dozen new behavioral effects wired into PlayerStats + the game loop; (3) the
vertical-ladder viz replacing the 3-row list. Engine-feasibility flags to confirm
before building: status-duration reduction (Vitality 19), near-miss detection
(Cunning 10B), per-target stacking + reset (Ferocity 18), excess-damage transfer
(Ferocity 19) — each already carries a fallback in the spec.*
