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
| MD | the card-detail modal fits the smallest iPhone (≤ 667pt; above A7a's 665pt target only Phase). CardDetailNode's layout is modelled; its spacings, wrap widths, pads, structure (which loop or branch each spacing sits in), start and panel formula are pinned to its code (v2.1 A7b S0b) |

## Commands (from the repo root)

```sh
sh tools/catalog-harness/run.sh                        # all checks (~20 s); exit 1 on any FAIL
sh tools/catalog-harness/run.sh --dump catalog.json    # the compiled catalog as JSON
python3 tools/catalog-harness/mutations.py             # the retained mutation suite
python3 tools/catalog-harness/mutations.py -j 6        # …with 6 parallel workers (default 4)
python3 tools/catalog-harness/mutations.py F3 S1       # …only mutants whose id starts so
```

The Atlas (`tools/generate-card-atlas.py`) and the canon
(`tools/generate-ability-canon.py`) render from `--dump`, assert the counts in
`tools/catalog-expect.json`, and then validate their OWN output before writing
it. The Atlas's checks are best-effort tooling, not a rendering guarantee
(CL-112, "Authority" below; known limits in the A7a return packet). It checks
that the rendered card ids are exactly the catalog's, and
validates its display-only provenance from a PARSED element tree (stdlib
`html.parser`), never raw HTML or CSS classes. Visibility is inherited
(`hidden`, `aria-hidden="true"`, inline `display:none` /
`visibility:hidden` / opacity 0), and the stylesheet may hide nothing. Text
is read as items with natural boundaries (formatting tags join a word,
sibling elements stay apart) in several readings; `title`, `alt` and
`aria-label` are channels too; Unicode is NFKC-normalised with
default-ignorables removed. The page must resolve to exactly one source
claim, a shown item reading "Source: compiled runtime catalog · N cards"
(N = `catalog-expect.json`'s total = the cards rendered), exactly one real
"generated <date>", and zero Git claims anywhere ("commit", `@`,
"rev-parse", the words "git"/"head", a standalone run of 7+ hex digits),
hidden content included. The suite's positive `atlas-*` flows prove that
markup changes which alter nothing a reader sees still pass. The
canon is checked as a MODEL: a strict parser places every non-blank line of the
document into a known record of a known section (anything else fails as
unplaceable), and the parsed model must EQUAL the model built independently
from the catalog and the sidecar: missing, extra, duplicate, wrong-owner,
wrong-identity and conflicting records all fail. Every section is strict (the
inventory is at the top of the validator in `generate-ability-canon.py`).
Provenance is a source-input FINGERPRINT, not a Git commit: the SHA-256 over
the digests of the canon's authoritative inputs (the compiled catalog, the
sidecar and `tools/catalog-expect.json` as canonical JSON, and the generator's
own bytes). Generation stamps it; `--check` recomputes it from the inputs present
and requires it exactly, so the same canon validates before and after a
commit, with or without Git, and when it is committed together with the source
it came from (A7a's single closeout commit). `--fingerprint` prints it
itemised. `?`, an empty, truncated or uppercase value, or a commit hash in its
place never validates; only the generation date is provenance-only and
format-validated. Input problems fail the same way: a message and a non-zero
exit. The suite's fingerprint checks are flows: `detects-*` regenerates the
canon, changes ONE input where the canon can't show it, and requires `--check`
to fail on the fingerprint alone; `git-onecommit` commits a source change and
its regenerated canon together in a throwaway repo (valid before, after, and
after a later unrelated commit); `git-stale` commits a source change without
regenerating (must fail).
**Authority (v2.1, closure table CL-112):**
- The compiled runtime catalog is production authority.
- The canon machinery above is authoritative supporting evidence.
- The HTML Atlas is an auxiliary developer visualization, not canonical. Its provenance checks are best-effort tooling with known, non-blocking limitations (A7a return packet). Arbitrary HTML/CSS/browser-equivalence validation is out of scope.
- A versioned JSON ability catalog with its own readers is banked for v2.2 (CL-113).

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

Note: the PB-D and PB-C checks use the real `CodexManager`, which writes to
the harness process's own `UserDefaults` domain on the host; they clear it
before and after (`resetAll()`).
