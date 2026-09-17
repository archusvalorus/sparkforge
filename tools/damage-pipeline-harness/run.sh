#!/bin/sh
# Damage-pipeline proof harness (v2.1 abilities Unit A0).
#
# Compiles the REAL PlayerDamagePipeline.swift, GameTimer.swift,
# KillSource.swift and PlayerStats.swift (+ UpgradeManager.swift, which
# PlayerStats needs) against the signature harness's host stubs, then runs
# the deterministic validators in main.swift. Re-run after ANY change to the
# damage order, Blood Barrier, rescues, kill credit or game-time timers —
# exits non-zero on any failure.
#
# Usage (from repo root):  sh tools/damage-pipeline-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/KillSource.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/tools/signature-draw-harness/Stubs.swift" \
   "$HERE/main.swift" "$BUILD/"
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/PlayerDamagePipeline.swift" "$BUILD/GameTimer.swift" \
       "$BUILD/KillSource.swift" "$BUILD/PlayerStats.swift" \
       "$BUILD/UpgradeManager.swift"
"$BUILD/harness"
