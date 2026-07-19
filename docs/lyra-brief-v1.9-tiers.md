# Lyra Creative Brief — Sparkforge v1.9 "The Deepening" (card tiers + capstones)

*From: Claude (build) · To: Lyra (creative direction) · Via: Brandon · July 19, 2026*

Lyra — v1.9 is the **systems** version: cards stop being one-and-done. Each
card can now carry a **power-tier ladder** — a mini-progression *inside* a run.
Picking a card you already own **levels it up** instead of being excluded; at
max tier a card can bloom into a qualitative **capstone**. The engine, the Card
Codex tier rendering, and a starter set of mechanical ladders are already built
and live. What's left is the **creative core**, and it's yours. Three asks
below — Ask 1 (the capstones) is the big one.

## Field report — what shipped, so you build on solid ground

- **The tier engine is backward-compatible.** A card with no ladder is a 1-tier
  card = exactly today. Laddered cards add higher-tier *deltas* (each rung adds
  to additive `PlayerStats` — never re-sets the whole effect).
- **The tier matrix is 1 / 2 / 3 / 5 — NO 4-tier.** Each ability is judged for
  how many rungs it can carry while staying fun. The **5-tier cards are the
  capstones** (Ask 1). Everything else is 1/2/3.
- **Tiers are ORTHOGONAL to synergies.** Leveling a card does NOT advance tag
  counts — synergies stay a pure *breadth* axis (distinct cards per tree),
  tiers are a *depth* axis. The tension "go deep vs. spread wide" is the point.
  Depth must never feed synergy tiers.
- **Per-run only.** Tiers reset each run (zero save-data risk). The Codex shows
  a card's ladder as reference, not lifetime progress.
- **Signature ladders already in the pool (mechanical, "more of the same"):**
  Fire **Forge Breath** (dmg, 3) · Shock **Static** (atk speed, 3) · Bleed
  **Nick** (crit, 2) · Guard **Fortify** (slow, 2) · Void **Phase** (range +
  pierce, 2) · Chill **Frost Touch** (slow, 2) · Neutral **Scatter** — the
  canonical **multishot** ladder (3). These are placeholders for *copy*
  elevation (Ask 3); their mechanics are set.
- **The capstone reveal is built.** Reaching a capstone's max tier fires a
  grand card-modal that reuses the synergy-unlock modal but with distinct
  framing — **"CAPSTONE UNLOCKED · TREE CAPSTONE"** vs. a synergy's "SYNERGY
  UNLOCKED · TIER n." A maxed *non*-capstone ladder just gets a quiet "★ maxed"
  flourish. So capstones are a genuine event — design them to earn it.

## Ask 1 — The six capstones (one tier-5 per tree) — THE creative core

A **single 5-tier capstone card per tree** (🔥 Fire, ⚡ Shock, 🩸 Bleed, 🛡️
Guard, 🕳️ Void, ❄️ Chill). One capstone per tree **bounds the chaos** — it's
the deep-devotion payoff. For each, deliver:

- **Name** + **≤50-char description** (card voice).
- **The tier-1→5 ladder**: what each of the 5 rungs adds. Rungs 1–4 should feel
  like meaningful growth; **tier 5 is the qualitative bloom** — a new behavior,
  not just a bigger number. (Think of Scatter's shape-shift at 3 pellets, but
  as a whole *identity* arriving at 5.)
- **How it reads as distinct from that tree's synergy tiers.** This is the hard
  constraint — a capstone must NOT feel like a re-skinned synergy. For collision
  avoidance, the existing synergy identities per tree are:
  - **Fire:** Spreading Flame → Wildfire Heart → Inferno Crown
  - **Shock:** Chain Current → Tesla Field → Storm Engine
  - **Bleed:** Open Wounds → Exsanguinate → Red Harvest
  - **Guard:** Ironhide → Thornwall → Unbroken Core
  - **Void:** Undertow → Event Horizon → Singularity
  - **Chill:** Frostbite → Shatter → Absolute Zero
- Mechanically true (we can't ship flavor a rung can't back). Flag any rung that
  needs new machinery so we don't double-build against existing systems (burn
  spread, chain, shatter, gravity-well, thorns/DEF, execution).

Banked reference, not a mandate: the **attack-speed → living-laser** idea
(a Shock 5-tier ending in a beam) is one shape of a capstone ladder — an
example of the *arc*, not a spec. Use it or redirect.

## Ask 2 — Which cards want DEEP ladders (the retrofit map)

Beyond the starter set, the full ~65-card pool gets laddered **incrementally**
across v1.9+. Your creative call: **which cards want depth, and how much (2/3)?**
Some abilities are natural ladders (raw scaling); some are one-and-done by
nature (a binary flag) and should stay 1-tier. A rough map — "these 8 want
3-tier, these 12 want 2-tier, these stay 1-tier" — lets us retrofit in sane
batches. The full pool is in `UpgradeManager.buildCardPool()`; I'll paste it
for you.

## Ask 3 — Elevate the signature-ladder copy (optional)

The seven shipped ladders (field report) carry my **mechanical** per-tier
strings, e.g. Scatter: *"+1 projectile (wider spread)" → "+1 more projectile
(fans out)" → "+1 more projectile (denser fan)."* If you want them in the card
voice — a punchier line per rung — deliver replacements and I'll swap them.
Ship-as-is is fine too; this is polish, not a gate.

## Constraints recap

Tier matrix **1/2/3/5, no 4** · depth is **orthogonal to synergies** (tiers
never advance tag counts) · **one capstone per tree**, tier-5, reads distinct
from synergy tiers · per-run only, no save-data · every rung mechanically true ·
capstone reveal reuses the synergy modal with "CAPSTONE" framing · tag counts
stay **≥7** per tree (laddering adds tiers, never removes cards) · Neutral is a
tag with no synergy — a Neutral capstone is **open/optional**, your call.
