# Lyra Creative Brief — Sparkforge v1.7 "The Coilworks"

*From: Claude (build) · To: Lyra (creative direction) · Via: Brandon · July 9, 2026*

Lyra — v1.6 shipped The Quench essentially verbatim from your pass: palette to the hex, Warden patterns as specced, Siphon exactly as you worded it. Two of your enemies got field-promoted lessons (below). v1.7 builds The Coilworks from your future-arenas spec, and this brief asks for refinements plus four new lanes.

## Field report from The Quench (what playtesting taught us)

1. **"Ornament, not armor"** — your Cinder Halo's rotating ring read as a *blocking shield* mid-swarm, so players avoided shooting it. It's benched, returning in v1.7 with a restyle: **the halo now floats ABOVE the head** (Brandon's call — "more halo-y"), static or slow-drift. Any decorative geometry on enemies must never encircle the body.
2. The Braceguard shipped with a **fixed cardinal shield at 50% reduction** instead of rotating full-block (too demanding mid-chaos). Your original rotating version is banked as an arena 4/5 elite.
3. **Enemy color taxonomy is now locked:** red = melee, purple = ranged, neon yellow = splitter, ash shield-arc = Braceguard. Ember/orange belongs to the player alone. New enemies need a color from outside those claims (Coilworks suggestion: your pale-gold static `#F6D36B` family for shock-flavored enemies is available and thematic).

## Ask 1 — The Coilworks, confirmed or refined

We're building from your spec as-is: `#121315` blackened machinery, `#5B4A22` tarnished brass, `#F6D36B` jittering static motes, circuit rings with gaps, conduit lines, node pulses. *"The arena is not chasing them, it is calculating them."* Anything you want to revise now that The Quench is real and playable, say so — otherwise we build verbatim.

## Ask 2 — The orbiter identity call

The orbit AI from Cinder Halo is built and good. Arena 3 wants an orbiter. Choose:
- **(a) Cinder Halo returns here** (above-head halo restyle) and Circuit Wasp waits, or
- **(b) Circuit Wasp ships** (your angular snap-orbiter — pauses at four directional points) and the Halo returns in a later arena, or
- **(c) both** — Halo as the smooth orbiter, Wasp as the angular one, introduced at different times.
Relay Imp (danger arcs between nearby imps) and Grounder (plants + pulses) ship as specced either way.

## Ask 3 — Six Coilworks cards (with collision guard)

Your Arena 3 direction stands: Spark Step, Copper Vein, Relay Burn, Overclock, Dead Circuit, Grounded Core. Deliverables: final names + ≤50-char descriptions + intended effects. **Collision appendix — the live pool now contains** (do not duplicate effects or names): Arc (chain +1), Live Wire (chain +1, stacks), Static Crown (level-up burst), Arc Wake (movement sparks), Permafrost & Cold Read overlap warning from your own v1.8 list, Event Horizon (already a Void synergy name — your Arena 5 card needs a rename eventually), plus the full 50-card pool in `UpgradeManager.swift`. Note: *Relay Burn* is our first dual-tag concept (Fire/Shock) — if you want it, we need a rule: counts toward BOTH tag totals, or player picks a tag on selection? Your call, we build it.

## Ask 4 — The spark's glow-up (new lane: art direction)

Brandon wants the player spark to step up visually. Constraint context: the game is 100% code-drawn geometry; we can now also ship real textures (sprite art) through the asset pipeline. Two paths, want your direction on both:
- **Procedural-plus** (ships first regardless): layered animated core — white-hot center, ember mid, soft outer glow — with a directional ember trail while moving. What should the spark *feel* like as it levels? (Current: glow radius grows per level.)
- **Textured sprite** (optional, your lane if you want it): if you'd rather paint the spark — a small set of frames or a single hero texture with additive glow — describe or generate it and we'll build the atlas. The spark is the center of every frame and every App Store screenshot; this is the single highest-visibility art in the game.

## Ask 5 — Dynamo Choir check

Building your three patterns as specced (Circuit Litany / Polarity Hymn / Broken Measure + Full Current enrage). The Polarity Hymn's third pulse "snaps nearby enemies inward toward the player's path" — confirmed buildable and *nasty*. Any second thoughts on any pattern now that the Warden's pull/push field is live and playable, flag them.

## Constraints recap

Every card true · purple stays danger, blue utility, green health, ember player-only · Shock leans yellow-white/pale gold, never blue · readability at speed beats cleverness · blade, not cathedral (but the blade got longer — DoD gates carry the weight now).
