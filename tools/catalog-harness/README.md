# Catalog harness (v2.1 abilities, Unit A7a)

Test support only. Nothing under `tools/` is part of the app target.

## What it proves

`run.sh` compiles the REAL `UpgradeManager`, `PlayerStats` and `CodexManager`
(plus the sources they need) against the shared stubs and the REAL extracted
`GameConfig` blocks, then runs seeded, reproducible checks:

| Group | What |
|---|---|
| RS | the seed drives every random choice (palette, Panda roll, spreads, bonus) |
| CA | exact catalog expectations (80 = 79 draftable + Panda; per tree; signatures; capstones; every gate's provider) |
| RW | every draftable card is offered AND maxed through the real draw and `acquire`, on a full save and a new save |
| IS | level-up sessions (spread, reroll, +1 Card, Extra Pick in any order, then the pick) against an independent oracle |
| BR / EG | +1 Card regressions; the ruled enabler edges (CL-91/92/93) through the real draw |
| AQ / SY | eligibility at acquisition time (Reviewer F1) and CL-93's symmetric incompatibility, both orders |
| SL | the same-level exclusion on every draw path (Reviewer F2) |
| PB | production boundaries: capstone-guarantee cadence, Panda's schedule, `reset()`, the real Codex write, the scene's level plumbing (Reviewer F3) |
| PA / CT / CP | Panda via its scheduler; the Codex tally and retired ids; the approved copy and its fit |
| WR | scene wiring that can't be executed, matched on exact code lines; the source is read as CODE through the shared `tools/signature-draw-harness/SwiftSource.swift` (line, block and nested block comments removed, string literals intact), and WR8 proves structure (each DEBUG banner reachable straight from its hot flag); WR9 (A7b S3) pins the exact active tokens that hand the gun Storm Engine's volley count (CL-98), WR10 (A7b S4) the ones that slow enemies on cultivated ground by the run's `terraSlow` (CL-96), WR11 (A7b S5) EnemyNode's independent snowman / timed-stun holds (R2), WR12 (A7b S6) the four independent vulnerability channels across every app source (CL-107/116), WR13 (A7b S7/S8) the four direct-hit chains' one block and its path to the target's direct entry (CL-94/114/115), WR14 (A7b S8) the Overcharge split's reach, the direct entries and the punish routing (CL-114a/c), WR15 (A7b S9) the replacement icicle's crit roll and Calculated Strike count (CL-117), WR16 (A7b S10) both Shatter sites' one rule, exits and tuning (CL-118), WR17 (A7b S11) Erasure's lone-boss fallback and Unstable Core's struck-only cost (CL-119/120), WR18 (A7b S12) hittability for every targeter, the gun's auto-aim included (CL-126/127a), WR19 (A7b S13) arcs and hops see their target and Skybeam homing's line of sight (CL-123), WR20 (A7b S14) the one path-tested shove and valid placements (CL-124), WR21 (A7b S15) boss hazards reach the live body (CL-127d), and WR22 (A7b S16) CL-125's monument invariant |
| SX | the shared source sanitizer itself, executed on fixtures: every comment form removed, every string form kept, the aligned shape view, `Block`'s depth / enclosing block / early-exit count (corrective 2); the EXECUTABLE view (string contents and inactive `#if` regions excluded, DEBUG active) and the in-branch exit-free path check (corrective 3); comments BLANKED so tokens never fuse, directives parsed as tokens (spaces, tabs, comments between them), unsupported condition forms refused, and the direct control-flow skeleton MW7 pins (corrective 4); a required call must be a STANDALONE statement, never embedded in a ternary, assignment, argument, operator, chain or trailing closure (corrective 5); the EXACT active token sequence (every lexeme verbatim, string literals whole) and its SHA-256, the input of the MW8 / WR8 tripwires; SX15 proves on the real scene that harmless whitespace/comment edits keep the tripwires while a wrapper breaks them (corrective 6) |
| JF / JL / JP | **v2.2 (catalog migration).** Since J2 the game's cards come from the authored JSON (`Sparkforge/Catalog/ability-catalog.json`, loaded by `AbilityCatalog.swift`) and their effects from the native registry (`AbilityBehaviors.swift`); `UpgradeManager` defines nothing itself. JF: the parity fixtures in `tools/v2.2-catalog/parity/` are the files recorded in J1 from the LEGACY pool (the only record of it), and **the catalog-backed game reproduces both byte for byte** — every effect delta, and the 22 recorded runs through the REAL manager (draft, reroll, bonus, acquisition, synergy bookkeeping, Codex writes, reset); the snapshot they rest on is complete and strict. JL: the authored file loads, and 87 broken catalogs (an unreadable source included) are each rejected whole with the diagnostic that names the problem. JP: the game's pool equals the file's cards field for field and in order, the dump is byte-identical to the J0 export of the legacy pool, 51 targeted scenarios match the record, and the natively named card ids exist. Support code: `tools/v2.2-catalog/harness/`. Records: `docs/v2.2-catalog-j1-return.md`, `docs/v2.2-catalog-j2-return.md` |
| MD | the card-detail modal fits the smallest iPhone (≤ 667pt; above A7a's 665pt target only Phase). CardDetailNode's layout is modelled; its spacings, wrap widths, pads, structure (which loop or branch each spacing sits in), start and panel formula are pinned to its code (v2.1 A7b S0b) |

## Commands (from the repo root)

```sh
sh tools/catalog-harness/run.sh                        # all checks (~20 s); exit 1 on any FAIL
sh tools/catalog-harness/run.sh --dump catalog.json    # the game's compiled pool as JSON (since v2.2 J3 the generators read the authored file instead; see check-reader-parity.py)
python3 tools/catalog-harness/mutations.py             # the retained mutation suite
python3 tools/catalog-harness/mutations.py -j 6        # …with 6 parallel workers (default 4)
python3 tools/catalog-harness/mutations.py F3 S1       # …only mutants whose id starts so
sh tools/catalog-harness/run.sh --record-parity <dir> [--force]  # v2.2: re-record the parity fixtures from the CURRENT game into a NEW directory; an existing one is refused without --force (the committed ones are the legacy record: a changed recording fails JF1 until parity-manifest.json is rewritten under a ruling)
python3 tools/catalog-harness/slot-lock-test.py        # v2.2 J1: the run-slot wrapper (ownership, exhaustion, interruption; ~3 s)
```

**Mutants and the J group.** Since the J2 cutover the J checks are the parity proof for every mutant (a mutant that changes what a card does or how the draft behaves fails JF2, the recorded-run replay, or JP4/JP5). The J1-era filter that ignored J results for older mutants is gone, and the mutants that used to edit card text in `UpgradeManager.swift` now edit the JSON or the registry (`REPOINT` in `mutations.py`).

**Parity under an approved content change (v2.2 N1, corrected Oct 12).** The legacy fixtures in `tools/v2.2-catalog/parity/` are FROZEN (never re-recorded without a ruling, never `--force`d). When a unit changes cards on purpose, a reviewed overlay (`tools/v2.2-catalog/parity/v22-neutral/n1-overlay.json`) names the retired and rewritten cards and their expected ladders, and `ParityAttribution.swift` builds the EXPECTED current documents from the frozen record plus the overlay — per card, per tier, grounded in the fixture's own record of what each affected card did — and the J checks require the actual documents to equal them: exact everywhere, numeric within 1e-12 only on the attributed fields (JF2a, JP4–JP6; JF2d proves the attributed fields are exactly the overlay's). Nothing is masked: an unrelated writer of the same field (Surge, Ice Rink, a stray radius write) fails. The run replay is compared to the ACCEPTED draw engine (`accepted-engine-31505bd.swift`, a frozen hash-pinned copy of HEAD's `UpgradeManager.swift`; `n1-engine-edits.json` = the reviewed exact-once edits that give it the N1 pool; `tools/v2.2-catalog/comparator/`): `run.sh` builds it unedited (must reproduce the legacy run fixture byte for byte, JF2b-0) and edited (the current manager's complete replay must equal it byte for byte, JF2b), so any draw-engine drift fails, early or late. The retained probes are the `N1-R` mutants.

**v2.2 N2.** The overlay and engine edits moved to `n2-overlay.json` / `n2-engine-edits.json` (the N1 files stay as evidence): the overlay may now list `addedFields` (PlayerStats stored fields the legacy record never had, with their default leaves) and copy-only rewrites (a card in `cards` with no `expectedDeltas` entry keeps its legacy effect exactly). The pure XP/level rules (`Sparkforge/Systems/XPLedger.swift`) and Overclock's clock are proven by `tools/neutral-harness/run.sh` (the mutation suite's `neutral` check); the scene's serialized level queue is EXECUTED by the neutral harness's QX group — `tools/neutral-harness/extract-queue.py` copies `resumeAfterLevelUp` / `stepOpenerDraft` / `takeNextLevel` and PlayerNode's XP members verbatim from the live sources at build time into shells over the real ledger (so a changed production function is what gets tested next time); the catalog harness's NX pins on the same code are source-only and say so.

**v2.2 N3.** The overlay/edits moved to `n3-overlay.json` / `n3-engine-edits.json` (N1/N2 files kept). `Sparkforge/Systems/AttackPattern.swift` (Scatter lanes, Fracture fans, the ±90° forward-spread rule, chance-rounded shares) is proven pure by the neutral harness's PX group; the scene's `fireShotSpread` / `shotBaseDamage` and the projectile's `move` / `hasStruck` / `onHitEnemy` are extracted verbatim into the fire seam and executed by its FX group; the catalog harness's NP group covers the real acquire path, gates, copy and labeled source-only pins. The v1.8 split fields stay in PlayerStats as retired stored state so the accepted engine keeps compiling.
The N3 corrective (Oct 13) adds the hit-chain seam to the same extractor: the gun handlers' damage chains, the Forge-offense helper, the two Fracture-branch helpers and the boss dial, executed by the DX group — the Fracture share is the chain's last step on its own threshold, and zero survives the shield and the dial.
**v2.2 N4.** The overlay/edits moved to `n4-overlay.json` / `n4-engine-edits.json` (N1–N3 files kept). Rapid Fire's ladder writes `fireRateMultiplier` as rate ratios, so the overlay names it in `multiplicativeFields` and `ParityAttribution.swift` attributes that field by ratio (every writer of it multiplies); every other field stays additive. NR0–NR3 pin the config, the real acquire path on top of Static/Surge/Glass Engine, both orders of the Polar Vortex T4 ↔ Rapid Fire T5 exclusion and the copy; NB1 pins the beam's rider copies (`landBeamHit` / `landBeamHitOnBoss`) token-equal to the gun handlers' sections; NB2–NB5 pin the beam's scene wiring (source-only). The A7b censuses (WR12/14/15/16) hold exactly on the scene outside the beam section (`beamSplit`) and count the beam's own additions separately. The pure beam (`BeamTick`, `BeamClock`) and its exact parent hits (`beamParentHit` / `beamParentHitBoss`, extracted with `forgeOffense`) are executed by the neutral harness's BX/BH groups. Mutants: `N4-` (55); retained mutants that edited a gun line the beam copies now edit both sites (`RE`), so NB1 is never what kills them. **Echo ruling (Oct 13):** Erasure T4's Echo is one shared `scheduleErasureEcho(direction:)` (moved verbatim out of `fireProjectile`), called by the gun's primary and once per virtual parent lane by the beam's volley effects; NB6 pins it by source, the neutral harness's EX group executes it (cadence, 1.5 s delay, 50% basis, lane multiplicity with Storm, pause/resume on a modelled SpriteKit action clock, no recursion), mutants `N4-EC1`–`EC11` and `N4-Q5`. N4-R1 (Oct 13): that model clock runs each frame's update phase BEFORE evaluating due actions (SKScene's documented order); the frame-phase regression EXP1 pins it and `N4-EP1` restores the old wrong order as a control. It remains a model — not SpriteKit timing, node/callback ordering or a real modal callback.

**v2.2 N5 (Chain Reaction, R6).** The overlay/edits moved to `n5-overlay.json` / `n5-engine-edits.json` (N1–N4 files kept); every mutant aimed at an N4 parity file is re-pointed to its N5 version. `ParityAttribution` now carries an overlay tier's NON-numeric pairs (a Bool a card sets — Chain Reaction's explode flag) as EXACT pairs into the expected document, and JP4b compares them byte for byte; they never join the numeric attributed-field set. NC1–NC7 pin the real acquire path, the copy and (source-only) the scene wiring; WR12/WR14 count `chainReactionBurst`'s single vulnerability read and direct entry separately; NE8 is the whole roster's 166 / 30. The pure rules (`ChainReaction.swift`) and the kill/burst seam (`onEnemyKilled`, `didFinishUpdate`, `drainChainReactions`, `chainReactionBurst`, and EnemyNode's real `takeDamage`/`takeDirectHit` body, extracted verbatim) are executed by the neutral harness's CX0–CX9. Mutants: `N5-` (39); damage-pipeline P11 covers the new `.rewardRecorded` credit tier. N5-R1 (Oct 14): the burst delivers `ChainReaction.entry(hit)` (a positive resolved hit carries a melt-capable basis); NC5/WR14 pin that line, the neutral harness's CX10/CX10b/CX11 execute it, controls `N5-R1-M1`–`M3`. Whiteout × Fracture / beam (Oct 14): the gun handler's final enemy entry and its beam copy deliver `hit.targetEntry` (a positive resolved hit carries a melt-capable basis; riders keep `damage = hit.basis`); WR13/WR14 and redsmile MW8 pin the moved line, the neutral harness's WX1–WX3 execute it, controls `WB-M1`–`M5`. WB-R1 (Oct 14): an inline comment had silenced WR14's beam-boss predicate (NB1 kept the overall exit nonzero); `wr14-guard-probe.py` now attributes the beam-boss mutation to WR14 BY NAME (WG0 / WG1 / the WG2 bug control) — keep comments on their own lines inside multi-line predicates.

**The generators (v2.2 J3-a).** The Atlas and the canon render from the AUTHORED catalog (`Sparkforge/Catalog/ability-catalog.json`) through `tools/v2.2-catalog/catalog_reader.py`, with no Swift compile; `tools/catalog-expect.json` uses the file's portable tree keys. `python3 tools/v2.2-catalog/check-reader-parity.py` proves the reader equals the game's compiled pool key for key. How to add a card or a tier: `docs/v2.2-catalog-authoring.md`; the isolated demonstration: `tools/v2.2-catalog/fixtures/demo-existing-behavior-card.py`.

`python3 tools/generate-ability-canon.py --check docs/v2.1-ability-canon.md`
validates the committed packet without writing (the suite's `canon-file` check).

## The mutation suite

`mutations.py` applies one mutant at a time — an exact-string edit, a short
ordered list of them, or a regex (`RE(...)`) for "every entry"/"move" cases —
to a throwaway copy
of `Sparkforge/Systems`, `Sparkforge/Config`, `Sparkforge/Scenes`,
`Sparkforge/Nodes`, `Sparkforge/Utils` (A7b S0a), `tools` and `docs`, and runs the checks listed for it there (Swift harnesses, or the
Atlas / canon generators). The unmutated copy must pass first. A mutant counts
as **KILLED** only when a check fails by assertion; a compile error or crash
is **INVALID** and a hang is a **TIMEOUT**, and neither is coverage. It exits
0 only when every selected mutant is killed. A7a's result at the final freeze
is recorded in `docs/v2.1-abilities-a7a-return.md`.

Note: every runner that compiles `UpgradeManager.swift` also compiles `AbilityCatalog.swift` + `AbilityBehaviors.swift` and exports `SPARKFORGE_CATALOG_PATH` (the stub `AbilityCatalogSource` in `Stubs.swift` reads it; the app's reads the bundle).

Note: the PB-D and PB-C checks and the v2.2 J run recorder use the real
`CodexManager`, which writes to the harness process's own `UserDefaults`
domain on the host; they clear it before and after (`resetAll()`). The domain
is named after the executable, so `run.sh` runs the harness as the holder of
one of 32 run slots and names it after the slot
(`sparkforge-catalog-harness-slotN`): runs in parallel never share a domain,
and no more than 32 small preference files ever exist. A slot is owned by an
exclusive `flock` held for the run (`with-slot.py`); the kernel frees it when
the run ends, however it ends, so there is no pid file, no liveness guess and
no reclamation, and no run can take or remove another live run's slot (v2.2
J1; before it every run shared the one domain `harness`, which made parallel
runs interfere, and a first repair that reclaimed slots by checking pids let
two reclaimers take the same slot — independent review, Oct 6).

## N6 final integration and recording

N6 uses dedicated `chaosBeam` / `beamIncompatible` capabilities for the approved first-acquired-wins exclusion between Rapid Fire T5 and Warp Shot/Mirror Edge. NI0–NI8 execute the real manager gates, acquisition, stale tables, rerolls/bonus/random-opener surfaces and reset. RF T1–T4 and the other pellet effects remain compatible. These are manager seams, not real UI callback tests.

Active attributed expectations and pinned-engine edits are `parity/v22-neutral/n6-*.json`; all historical files stay frozen. The separate final record is `tools/v2.2-catalog/parity/v22/` (`effect-deltas.json`, `run-transcripts.json`, `manifest.json`). NIF1–NIF4 verify its manifest/digests and compare current effect/run documents byte for byte; they supplement rather than replace JF1/JF2/JP. The current-record path omits retired-card steps from historical scenarios via the existing explicit retirement seam. Do not overwrite legacy fixtures or use `--force` for final recording.

N6 adds 11 negative controls: six gate/grant directions, wrong broad gate, acquire bypass, and three final-record tampering controls. The inventory is767; a new candidate does not inherit the historical full756 PASS. Packet: `docs/v2.2-neutral-n6-return.md`.
