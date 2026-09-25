#!/bin/sh
# Signature-draw proof harness (v2.1 abilities Unit 1).
#
# Compiles the REAL UpgradeManager.swift + PlayerStats.swift against host
# stubs (Stubs.swift) and runs the deterministic validators in main.swift.
# Re-run after ANY change to the draw path or the per-tree provides/requires
# authoring (the rework pass) — takes ~15s, exits non-zero on any failure.
#
# Usage (from repo root):  sh tools/signature-draw-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
# PlayerStats holds A0's damage-pipeline state, so its value types ride along.
cp "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/GuardState.swift" \
   "$ROOT/Sparkforge/Systems/VoidState.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$HERE/Stubs.swift" "$HERE/main.swift" "$BUILD/"
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" \
   "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/ExtractedConfig.swift" Guard VoidTree
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/UpgradeManager.swift" "$BUILD/PlayerStats.swift" \
       "$BUILD/PlayerDamagePipeline.swift" "$BUILD/GuardState.swift" "$BUILD/ExtractedConfig.swift" "$BUILD/VoidState.swift" "$BUILD/GameTimer.swift"
"$BUILD/harness"
