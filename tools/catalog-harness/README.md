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
| WR | scene wiring that can't be executed, matched on exact code lines (comments stripped) |

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
it. The Atlas checks that the rendered card ids are exactly the catalog's, and
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
of `Sparkforge/Systems`, `Sparkforge/Config`, `Sparkforge/Scenes`, `tools`
and `docs`, and runs the checks listed for it there (Swift harnesses, or the
Atlas / canon generators). The unmutated copy must pass first. A mutant counts
as **KILLED** only when a check fails by assertion; a compile error or crash
is **INVALID** and a hang is a **TIMEOUT**, and neither is coverage. It exits
0 only when every selected mutant is killed. A7a's result at the final freeze
is recorded in `docs/v2.1-abilities-a7a-return.md`.

Note: the PB-D and PB-C checks use the real `CodexManager`, which writes to
the harness process's own `UserDefaults` domain on the host; they clear it
before and after (`resetAll()`).
