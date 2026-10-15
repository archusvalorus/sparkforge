#!/bin/sh
# Catalog harness (v2.1 abilities Unit A7a, CL-90).
#
# Compiles the REAL UpgradeManager.swift + PlayerStats.swift (and the sources
# they need) against the shared stubs and the REAL extracted config, then
# proves the catalog: exact expectations, reachability through the real
# normal-campaign draw, the one offer rule across both draws, Panda through
# its scheduler, the +1 Card regressions, the Codex tally and the wiring.
# Every run is seeded, so results reproduce. Exits non-zero on any failure.
#
# Usage (from repo root):
#   sh tools/catalog-harness/run.sh                 # run the checks
#   sh tools/catalog-harness/run.sh --dump out.json # write the catalog JSON only
#   sh tools/catalog-harness/run.sh --record-parity <dir> [--force]  # v2.2: re-record the parity fixtures (refuses an existing dir without --force)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
# v2.2 J2: UpgradeManager reads the authored catalog through the stub AbilityCatalogSource.
export SPARKFORGE_CATALOG_PATH="${SPARKFORGE_CATALOG_PATH:-$ROOT/Sparkforge/Catalog/ability-catalog.json}"
trap 'rm -rf "$BUILD"' EXIT
# v2.2 J1: the real CodexManager writes to the process's UserDefaults domain,
# which is named after the executable. Runs in parallel (the mutation suite)
# must not share one, so the harness runs as the holder of a run SLOT and is
# named after it (with-slot.py: an exclusive flock held for the run; the
# kernel frees it when the run ends, however it ends). At most 32 small
# preference files ever exist, and no run ever touches another's.
cp "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/GuardState.swift" \
   "$ROOT/Sparkforge/Systems/VoidState.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/CodexManager.swift" \
   "$ROOT/tools/signature-draw-harness/SwiftSource.swift" \
   "$HERE/main.swift" "$BUILD/"
# v2.2 J1: the parity kit (snapshot, fixtures) — test support, kept with the
# rest of the catalog-migration tooling.
cp "$ROOT/tools/v2.2-catalog/harness/"*.swift "$BUILD/"
# v2.2 J1: the JSON catalog's loader and the native behaviour registry (off the
# runtime path until J2; compiled here so the J checks can prove parity).
cp "$ROOT/Sparkforge/Systems/AbilityCatalog.swift" "$ROOT/Sparkforge/Systems/AbilityBehaviors.swift" "$BUILD/"
# The REAL CodexManager replaces the shared stub (F3.D: a real offer path must
# be proven to record discovery). Strip the stub's marked block.
awk '/CODEX-STUB-BEGIN/{skip=1} !skip{print} /CODEX-STUB-END/{skip=0}' \
   "$ROOT/tools/signature-draw-harness/Stubs.swift" > "$BUILD/Stubs.swift"
grep -q 'final class CodexManager' "$BUILD/Stubs.swift" && { echo "stub CodexManager not stripped" >&2; exit 1; }
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" \
   "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/ExtractedConfig.swift" Guard VoidTree Drafting Panda Growth Chill BossClass Erasure Shock Neutral
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" "$BUILD/SwiftSource.swift" \
       "$BUILD/UpgradeManager.swift" "$BUILD/PlayerStats.swift" \
       "$BUILD/PlayerDamagePipeline.swift" "$BUILD/GuardState.swift" "$BUILD/ExtractedConfig.swift" "$BUILD/VoidState.swift" "$BUILD/GameTimer.swift" \
       "$BUILD/CodexManager.swift" \
       "$BUILD"/Parity*.swift "$BUILD/AbilityCatalog.swift" "$BUILD/AbilityBehaviors.swift"
# v2.2 J2: a repeated key inside one JSON object is kept-last and silent in
# every parser; the lint fails the run before anything compiles.
python3 "$ROOT/tools/v2.2-catalog/lint-catalog.py" "$ROOT/Sparkforge/Catalog/ability-catalog.json" || exit 1
# The harness binary takes its slot's name only once the slot is held.
run_in_slot() {
  python3 "$HERE/with-slot.py" -- sh -c 'src="$1"; dst="$2"; shift 2; cp "$src" "$dst" && exec "$dst" "$@"' sh \
    "$BUILD/harness" "$BUILD/sparkforge-catalog-harness-{slot}" "$@"
}
# v2.2 N1 corrective (Oct 12): the accepted-engine comparator. HEAD's
# UpgradeManager.swift (pinned by hash in the reviewed edits file) is built
# twice with the SAME support sources as the harness — unedited, and with the
# reviewed N1 pool edits — and each records the 22 legacy runs. The harness
# requires: unedited == the frozen legacy fixture; edited == the current
# manager's replay (JF2b). A moved engine or a non-matching edit stops the run.
# `SPARKFORGE_SKIP_COMPARATOR=1` leaves the two paths unset (JF2b then fails).
COMPARATOR="$ROOT/tools/v2.2-catalog/comparator"
EDITS="$ROOT/tools/v2.2-catalog/parity/v22-neutral/n5-engine-edits.json"   # v2.2 N5 (supersedes the N4 file)
if [ "$1" != "--dump" ] && [ "$1" != "--record-parity" ] && [ -z "$SPARKFORGE_SKIP_COMPARATOR" ]; then
  mkdir -p "$BUILD/cmp"
  ENGINE_COMMIT="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['engineCommit'])" "$EDITS")"
  ENGINE_PATH="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['enginePath'])" "$EDITS")"
  # The accepted engine is a FROZEN copy beside the fixtures (byte-identical to
  # git `<engineCommit>:<enginePath>`, hash-pinned by the edits file; the
  # mutation suite's copies have no git). When git can show that commit here,
  # the copy must still equal it.
  # A comparator that cannot be grounded or built is reported, and the run
  # goes on WITHOUT its transcripts: JF2b-0 and JF2b then FAIL as checks (the
  # mutation suite needs a printed FAIL to count a kill), never pass silently.
  comparator_ok=1
  cp "$ROOT/tools/v2.2-catalog/parity/v22-neutral/accepted-engine-31505bd.swift" "$BUILD/cmp/engine.swift" || comparator_ok=0
  if [ $comparator_ok = 1 ] && ( cd "$ROOT" && git cat-file -e "$ENGINE_COMMIT:$ENGINE_PATH" ) 2>/dev/null; then
    ( cd "$ROOT" && git show "$ENGINE_COMMIT:$ENGINE_PATH" ) | cmp -s - "$BUILD/cmp/engine.swift" \
      || { echo "COMPARATOR: the frozen accepted engine differs from git $ENGINE_COMMIT:$ENGINE_PATH" >&2; comparator_ok=0; }
  fi
  for mode in legacy n1; do
    [ $comparator_ok = 1 ] || break
    if [ "$mode" = legacy ]; then
      python3 "$COMPARATOR/apply-engine-edits.py" "$EDITS" "$BUILD/cmp/engine.swift" "$BUILD/cmp/UpgradeManager-$mode.swift" --none || { comparator_ok=0; break; }
    else
      python3 "$COMPARATOR/apply-engine-edits.py" "$EDITS" "$BUILD/cmp/engine.swift" "$BUILD/cmp/UpgradeManager-$mode.swift" || { comparator_ok=0; break; }
    fi
    swiftc -O -o "$BUILD/cmp/comparator-$mode" "$COMPARATOR/main.swift" "$BUILD/Stubs.swift" \
           "$BUILD/cmp/UpgradeManager-$mode.swift" "$BUILD/PlayerStats.swift" \
           "$BUILD/PlayerDamagePipeline.swift" "$BUILD/GuardState.swift" "$BUILD/ExtractedConfig.swift" "$BUILD/VoidState.swift" "$BUILD/GameTimer.swift" \
           "$BUILD/CodexManager.swift" "$BUILD/ParitySnapshot.swift" "$BUILD/ParityFixtures.swift" || { comparator_ok=0; break; }
    python3 "$HERE/with-slot.py" -- sh -c 'src="$1"; dst="$2"; shift 2; cp "$src" "$dst" && exec "$dst" "$@"' sh \
      "$BUILD/cmp/comparator-$mode" "$BUILD/cmp/sparkforge-catalog-comparator-{slot}" "$BUILD/cmp/transcript-$mode.json" || { comparator_ok=0; break; }
  done
  if [ $comparator_ok = 1 ]; then
    export SPARKFORGE_COMPARATOR_LEGACY="$BUILD/cmp/transcript-legacy.json"
    export SPARKFORGE_COMPARATOR_N1="$BUILD/cmp/transcript-n1.json"
  else
    echo "COMPARATOR: not available for this run — JF2b-0 and JF2b will FAIL" >&2
  fi
fi
if [ "$1" = "--dump" ]; then
  run_in_slot --dump "$2"
elif [ "$1" = "--record-parity" ]; then
  run_in_slot --record-parity "$2" ${3:+"$3"}
else
  run_in_slot "$ROOT"
fi
