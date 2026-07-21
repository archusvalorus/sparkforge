# Forge Path Rework — Sprint Kickoff

*The build plan for turning the Forge Path from an infinite 2-node cycle into
authored vertical ladders with milestone forks. Content spec:
[forge-path-ladders-v1.9.md](forge-path-ladders-v1.9.md). Builds on the shipped
Unit 7 foundation (any-time screen + free respec + "mastery points"). One unit at
a time, DoD-gated, one commit per unit at DoD-pass with Brandon's approval.*

## Decided — do not relitigate

- Forks fire every **5th point within a branch** (per-branch milestone), not
  global forge level. Ladders authored **1–20**, forks at 5/10/15/20.
- **No upfront gate** — same as capstones; the system is always available.
- **Ten-level stat bands** (Vit HP +5→+6, DEF +2→+3; Fer ATK +1→+2, dmg
  +1%→+1.5%; Cun crit/move +1%→+1.5%).
- **100 mastery-point cap** long-term; FL100 "Eternal Ember" is a later add.
- Persistence: keep `sf_forge_path_picks` (live data, never rename); **add** a
  companion `sf_forge_path_forks`. Respec clears picks + forks + bonuses.
- Free respec stays. "Permanent progression should make the player feel
  prepared, not preordained."

## Unit sequence

### Unit 1 — Data model + authored ladders (the foundation)
Replace `ForgePathManager.cycles` (infinite 2-node) with **authored ordered
ladders** per branch (Vitality/Ferocity/Cunning, nodes 1–20). A node carries:
branch · level · name · effect text · `isFork` + fork A/B · optional
cooldown/condition/cap. `applyPathBonuses` walks each branch's spent count down
its ladder, resolving fork nodes via stored choices. Ten-level stat bands. New
`sf_forge_path_forks` persistence; `sf_forge_path_picks` untouched (existing
players' picks replay onto the new ladders). Stat nodes (HP/DEF/ATK/dmg/crit/
move/pickup) fully wired; behavioral nodes defined but their *effects* land in
Unit 2. Respec clears picks + forks.
**DoD:** builds clean (0 new warnings); an existing save loads + replays; stat
nodes apply correctly; fork choices persist + resolve; respec clears everything.

### Unit 2 — Behavioral node effects (~2 dozen)
Wire the non-stat nodes into `PlayerStats` + the game loop: regen, damage-
reduction buckets (defined stacking order + effective cap), kill-stacks (Rising
Heat, Bloodrush), Cold Fury, Relentless Pressure (per-target), Overkill (excess-
damage transfer), Opportunist (vs-impaired), crit rhythm (Calculated Strike /
Lucky Break), Read the Room, reroll grants (Foresight / Second Look), etc.
**Engine-feasibility flags (each has a spec fallback):** Unshaken (status-
duration reduction), Slipstream (near-miss detection), Relentless Pressure
(per-target stacking + reset), Overkill (excess-damage cap). Verify against code,
use the fallback where unsupported.
**DoD:** each node's effect fires in-run; caps/cooldowns/ceilings respected; no
new warnings.

### Unit 3 — The vertical-ladder viz + fork selection
Replace the 3-row list with a **vertical ladder per branch**: node 1 at top,
connecting lines, current position marked, locked future nodes visible, every 5th
node rendered as a **1-of-2 fork split**, selected fork path highlighted. Spend
flows down the ladder; the free respec + confirm-modal component stay. Fork
selection presents the two options and stores the choice.
**DoD:** all three ladders render; current position + forks legible; spend +
fork-choice work; respec + confirm modal intact; runs on the Unit 7 foundation.

### Unit 4 — Tuning / playtest pass
Balance node values (all configurable), stacking/caps, fork parity — through
Brandon's playtest sieve. Forks must feel like real preferences, not coin flips.
**DoD:** Brandon's on-device sign-off.

## Sequencing note
Units 1→3 are build (data → effects → viz); Unit 4 is tuning. This is its own
dedicated sprint (per the roadmap) — not interleaved with other content.
