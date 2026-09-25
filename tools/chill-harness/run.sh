#!/bin/sh
# Chill proof harness (v2.1 abilities Unit A2).
#
# Compiles the REAL ChillGround.swift, GameTimer.swift, PlayerStats.swift and
# UpgradeManager.swift (+ PlayerDamagePipeline.swift, which PlayerStats needs)
# against the signature harness's host stubs, then runs the deterministic
# validators in main.swift: Glacial Drift's frozen ground (CL-11), the
# snowman melt rule (CL-7), and the reworked Chill cards applied through
# the real card pool. Re-run after ANY change to chilled ground, snowmen or the Chill tree —
# exits non-zero on any failure.
#
# Usage (from repo root):  sh tools/chill-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Systems/ChillGround.swift" \
   "$ROOT/Sparkforge/Systems/SnowmanState.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/GuardState.swift" \
   "$ROOT/Sparkforge/Systems/VoidState.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/tools/signature-draw-harness/Stubs.swift" \
   "$HERE/main.swift" "$BUILD/"
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" \
   "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/ExtractedConfig.swift" Guard VoidTree
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/ChillGround.swift" "$BUILD/SnowmanState.swift" "$BUILD/GameTimer.swift" \
       "$BUILD/PlayerDamagePipeline.swift" "$BUILD/GuardState.swift" "$BUILD/ExtractedConfig.swift" "$BUILD/VoidState.swift" "$BUILD/PlayerStats.swift" \
       "$BUILD/UpgradeManager.swift"
"$BUILD/harness"
