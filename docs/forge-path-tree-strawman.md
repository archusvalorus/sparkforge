# Forge Path — Skill-Tree Redesign Strawman

*Claude, July 20 2026. A strawman for Brandon + Lyra to react to — the
STRUCTURE is the proposal; names/numbers are placeholders for Lyra's pass.
Builds on the shipped Unit 7 foundation (any-time screen + free respec +
"mastery points"). See [[forge-path-skill-tree-vision]].*

## The vision (Brandon)

Each of the 3 branches becomes a **visual vertical ladder**: node **1** at the
top (a small "1" on the left), a **line** down to node 2, 3, … with the
player's current position marked. Every **×5 step is a 1-of-2 CHOICE node** —
a fork the player actually decides. Legibility (see the whole path) + depth
(felt milestone decisions), without changing the core playstyle.

## What changes vs. today

Today a branch is an **infinite 2-node cycle** (pick alternates A/B forever).
The tree needs an **authored, ordered ladder** — a defined node list with a
fork at each ×5. So the biggest shift is **data-model + a new choice mechanic**,
not just visuals.

## Strawman ladders (STRUCTURE — Lyra owns identities/flavor)

Each node ≈ the current "two levels of flat bonus" power budget; nodes can
escalate gently up the ladder. Numbers are placeholders.

### 💚 Vitality — endure
| # | Node | Effect |
|---|------|--------|
| 1 | Tempered Vessel | +4 Max HP |
| 2 | Iron Bones | +2 DEF |
| 3 | Second Wind | +6 Max HP |
| 4 | Bulwark | +2 DEF |
| **5** | **FORK** | **A: Regenerator** — regen 1 HP / 10s · **B: Bastion** — +3 DEF |
| 6–9 | (escalating HP/DEF nodes) | … |
| **10** | **FORK** | A: Last Stand — +DEF at low HP · B: Vital Surplus — +8 Max HP |

### ⚔️ Ferocity — strike
| # | Node | Effect |
|---|------|--------|
| 1 | Whetted Edge | +2 ATK |
| 2 | Stoked Furnace | +4% damage |
| 3 | Honed Point | +2 ATK |
| 4 | Bellows | +5% damage |
| **5** | **FORK** | **A: Berserker** — +8% dmg while below half HP · **B: Executioner** — +3 ATK flat |
| 6–9 | (escalating ATK/dmg nodes) | … |
| **10** | **FORK** | A: Overdraw — +crit dmg · B: Relentless — +% dmg |

### 🎯 Cunning — outplay
| # | Node | Effect |
|---|------|--------|
| 1 | Keen Eye | +4% crit chance |
| 2 | Light Step | +4% move speed |
| 3 | Sharp Focus | +4% crit chance |
| 4 | Fleet | +4% move speed |
| **5** | **FORK** | **A: Deadeye** — crits +25% dmg · **B: Windrunner** — +6% move speed |
| 6–9 | (escalating crit/mobility nodes) | … |
| **10** | **FORK** | A: Assassinate — crit vs low-HP · B: Phantom Step — dodge/iframe tweak |

The fork "flavors" a branch mid-run — e.g. Vitality-5 splits into *sustain*
(Regenerator) vs *armor* (Bastion); Ferocity-5 into *risk* (Berserker) vs
*steady* (Executioner). That's the felt decision.

## Design questions for Brandon + Lyra

1. **Is "×5" the 5th NODE in a branch** (per-branch milestone, my assumption)
   **or forge level 5** (a global milestone)? Per-branch reads cleaner as a
   tree, but confirm.
2. **Ladder depth.** Finite (say 10–15 nodes, then it stops offering) or
   effectively endless (forks every 5 forever)? Forge Level is uncapped, so a
   deep player keeps earning points — the ladder needs an answer for the deep
   end (cap, or keep escalating, or loop the tail).
3. **Fork identities + numbers** — Lyra's pass. Each fork wants two options
   that feel like a *real* branch, not a coin flip (one risky/one steady, or
   two playstyles).
4. **Do forks want to gate synergy-adjacent power** or stay pure stat/utility?
   Keep them from stepping on the in-run card synergies.

## Build notes (Claude, when the design lands)

- **Data model:** replace `ForgePathManager.cycles` with an authored ladder
  per branch (ordered nodes; fork nodes carry two options). `applyPathBonuses`
  walks each branch's spent count down its ladder, resolving forks by the
  stored choice.
- **Persistence (backward-compat is the constraint):** today `picks: [Branch]`
  → `sf_forge_path_picks`. A fork needs storing WHICH option was chosen at each
  milestone. Add a companion record (e.g. `sf_forge_path_forks`) so the old
  key still loads untouched; players mid-ladder default/re-choose forks
  cleanly. Never rename `sf_forge_path_picks` (live data).
- **Respec** already clears picks; it should also clear stored fork choices.
- **UI:** the tree-viz screen replaces the current three-row list — a vertical
  ladder per branch (scroll if deep), current position marked, fork nodes
  rendered as a two-option split; spend flows down the ladder; the free respec
  stays. Reuse the card-family tinting + the confirm-modal component.
- Ships on the Unit 7 foundation — the any-time entry, respec, and mastery-
  point economy don't change.
