# Lyra Creative Brief — Sparkforge v1.8 "Mirrorwound + The Codex"

*From: Claude (build) · To: Lyra (creative direction) · Via: Brandon · July 12, 2026*

Lyra — The Coilworks shipped live July 11 (v1.7), built from your future-arenas spec with your refinements intact: sequenced node pulses, floor quieter than enemies, no rings around enemy bodies, Static Halo above the head. v1.8 is a **detour with a couple extra miles, not a new destination** (Brandon's framing): the fourth arena **Mirrorwound**, plus a meta layer — a **Codex Suite** that turns a run's discoveries into a permanent collection. Six asks below. Numbers 3 and 4 are copy-heavy; the rest are direction.

## Field report from The Coilworks (what shipped + what we learned)

1. **Enemy taxonomy held.** Pale-gold `#F6D36B` Static Halo + angular Circuit Wasp read cleanly as shock-family; ember/orange stayed player-only. That last rule now gets tested — see Ask 4 (forge coins are deliberately orange, on the player/forge lane).
2. **Dual-tag shipped clean.** Relay Burn (Fire/Shock) counts toward BOTH tag totals, no pick popup. The rule is now canon for Mirrorwound cards.
3. **The systems are invisible until earned.** Synergy tiers, blessing choice, revive — players don't see the value until they hit the placement. The Codex Suite is partly a fix for that: it makes the game's depth *legible* from the title screen.

## Ask 1 — Mirrorwound, confirmed or refined

Arena 4. We have no locked spec for it yet — this is the open creative call. Deliverables:
- **Palette** (floor / boundary / motif accent, to the hex, as you did for Quench and Coilworks).
- **Motif & behavior** — what is the arena *doing* to the player? Quench calculated them; Coilworks was a machine. "Mirrorwound" suggests reflection / doubling / self-damage — a mirror that wounds. Is the hazard a reflection of the player's own fire? Lean in or redirect.
- One line of arena voice, in your Quench/Coilworks register.

## Ask 2 — The Codex Suite: three pages, ONE visual language

New meta surfaces, reached from the title screen and pause menu. They must read as **one system**, and inherit the **card language** (tree-tinted plate, colored stroke, tag emoji, bright title, white effect text). Direction wanted on the shared look, plus each page's discovered/undiscovered treatment:
- **Synergies codex** — all **18** synergy tiers (6 trees × 3: 🔥 Fire, ⚡ Shock, 🩸 Bleed, 🛡️ Guard, 🕳️ Void, ❄️ Chill). *(Note: Neutral is a card tag but has no synergy tier — 18, not 21.)*
- **Card codex** — the full 56-card pool.
- **Bestiary** — every enemy family (Ask 4).
- **Undiscovered state:** tree-tinted card with "???". **"Discovered" = ever OFFERED** (revealed the moment it appears, passed-over or not) — decided at kickoff. So the codex fills fast and rewards *seeing* the pool, not just committing to it. Does the reveal want a beat (a flip, a bloom)? Your call.

## Ask 3 — Synergy modal copy (elevate, don't invent)

The 3x/5x/7x tier unlock is moving from a floating bottom line to a **pause-step modal** (game holds, card-style plate, tap to continue; chains queue one after another). **Functional copy for all 18 tiers already exists** in code — e.g. *"🔥 Spreading Flame — Burns spread to nearby enemies,"* *"⚡ Tesla Field — Passive aura damages nearby enemies,"* *"🩸 Exsanguinate — Low HP enemies take double damage."* The ask: do you want to **elevate these** for the modal's full-card presentation — a title line + a punchier effect line each, in the card voice — or ship the existing strings as-is? If elevating, deliver all 18 (they're in `UpgradeManager.synergyDescription`; I'll paste the current set for you).

## Ask 4 — Two visual-identity calls

**(a) Forge XP Coins** — a new boss-death reward: on top of the existing XP-orb shower (which stays — it's brilliant), the boss erupts **large spinning ember-orange coins scattered arena-wide**, scooped while fighting the post-boss swarm. Decided constraints: **orange, on the player/forge lane** (the one exception to "orange = player only" — this IS forge XP); **large; spinning** (we oscillate xScale to read as a spin); **no magnet** (walking to them is the point, health-orb philosophy); **flat value** (the XP Boost ad does not double them). What should the coin *look and feel* like — a forged token, a spark-stamped disc? It must never be mistaken for blue magnet / green health / small XP orbs.

**(b) Bestiary entries** — one short entry per enemy family, in your register. Families to date: melee, ranged, **Ashling** (splitter), **Braceguard**, **Relay Imp**, **Grounder**, **Static Halo**, **Circuit Wasp**, plus bosses **Slag Titan**, **Warden**, **Dynamo Choir**, and the mini-boss. **Plus a reserved, hidden `????` slot** — this is Mote's (v2.0), seeded now so the schema doesn't churn; write nothing for it, just know the empty chair is intentional.

## Ask 5 — Mirrorwound enemy family + boss

From your Ask 1 palette/motif: **a new enemy family** (introduction order per the Quench/Coilworks curriculum — early teacher, mid pressure, late/elite), and **a boss** distinct from Titan / Warden / Dynamo Choir. If Mirrorwound is about reflection, an enemy that mirrors or copies the player's own attacks is on the table — flag reuse/overlap with existing shatter and gravity-well machinery so we don't double-build.

## Ask 6 — Mirrorwound cards

A new card set for arena 4. Deliverables: final names + ≤50-char descriptions + intended effects. **Collision guard:** dual-tag rule is live (counts toward both). The Void synergy already owns *Event Horizon* and *Singularity*; Chill owns *Shatter* and *Absolute Zero*; the full 56-card pool is in `UpgradeManager.buildCardPool()`. Banked veins you flagged before — stat-boost cards, projectile-mod cards (lightning/frost-touched) — **check overlap with existing shatter machinery** before proposing.

## Constraints recap

Every card true · purple = danger, blue = utility/magnet, green = health, ember/orange = player **and now forge coins** (the sole extension) · Shock leans yellow-white/pale gold, never blue · readability at speed beats cleverness · the codex is card-language, one system, three pages · Mote's chair stays empty until v2.0.
