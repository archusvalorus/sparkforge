#!/bin/sh
# Fire proof harness (v2.1 abilities Unit A1).
#
# Compiles the REAL BurnState.swift, GameTimer.swift, PlayerStats.swift and
# UpgradeManager.swift (+ PlayerDamagePipeline.swift, which PlayerStats needs)
# against the signature harness's host stubs, then runs the deterministic
# validators in main.swift: Crucible's per-enemy stacks (Q-F2), the
# dormant-stack decay (CL-16), and the reworked Fire cards applied through
# the real card pool. Re-run after ANY change to Burn or the Fire tree —
# exits non-zero on any failure.
#
# Usage (from repo root):  sh tools/fire-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Systems/BurnState.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/tools/signature-draw-harness/Stubs.swift" \
   "$HERE/main.swift" "$BUILD/"
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/BurnState.swift" "$BUILD/GameTimer.swift" \
       "$BUILD/PlayerDamagePipeline.swift" "$BUILD/PlayerStats.swift" \
       "$BUILD/UpgradeManager.swift"
"$BUILD/harness"
