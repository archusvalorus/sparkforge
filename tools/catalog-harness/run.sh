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
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/GuardState.swift" \
   "$ROOT/Sparkforge/Systems/VoidState.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/CodexManager.swift" \
   "$HERE/main.swift" "$BUILD/"
# The REAL CodexManager replaces the shared stub (F3.D: a real offer path must
# be proven to record discovery). Strip the stub's marked block.
awk '/CODEX-STUB-BEGIN/{skip=1} !skip{print} /CODEX-STUB-END/{skip=0}' \
   "$ROOT/tools/signature-draw-harness/Stubs.swift" > "$BUILD/Stubs.swift"
grep -q 'final class CodexManager' "$BUILD/Stubs.swift" && { echo "stub CodexManager not stripped" >&2; exit 1; }
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" \
   "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/ExtractedConfig.swift" Guard VoidTree Drafting Panda
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/UpgradeManager.swift" "$BUILD/PlayerStats.swift" \
       "$BUILD/PlayerDamagePipeline.swift" "$BUILD/GuardState.swift" "$BUILD/ExtractedConfig.swift" "$BUILD/VoidState.swift" "$BUILD/GameTimer.swift" \
       "$BUILD/CodexManager.swift"
if [ "$1" = "--dump" ]; then
  "$BUILD/harness" --dump "$2"
else
  "$BUILD/harness" "$ROOT"
fi
