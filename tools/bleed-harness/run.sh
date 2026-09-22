#!/bin/sh
# Bleed / boss-DoT proof harness (v2.1 abilities Unit A4a).
#
# Compiles the REAL BleedState.swift, StatusDoTs.swift, BurnState.swift,
# GameTimer.swift, PlayerStats.swift and UpgradeManager.swift (+
# PlayerDamagePipeline.swift, which PlayerStats needs) against the signature
# harness's host stubs, then runs the deterministic validators in main.swift:
# the ticking Bleed (CL-1), the two-channel DoT host and its boss-class scale
# (CL-17), and Bloodthirsty applied through the real card pool. Re-run after
# ANY change to Bleed, the DoT host, or the Bleed tree — exits non-zero on any
# failure.
#
# Usage (from repo root):  sh tools/bleed-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Systems/BleedState.swift" \
   "$ROOT/Sparkforge/Systems/KillContext.swift" \
   "$ROOT/Sparkforge/Systems/BarrierTellState.swift" \
   "$ROOT/Sparkforge/Systems/FireClock.swift" \
   "$ROOT/Sparkforge/Systems/StatusDoTs.swift" \
   "$ROOT/Sparkforge/Systems/BurnState.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/tools/signature-draw-harness/Stubs.swift" \
   "$HERE/main.swift" "$BUILD/"
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/BleedState.swift" "$BUILD/KillContext.swift" "$BUILD/FireClock.swift" \
       "$BUILD/BarrierTellState.swift" \
       "$BUILD/StatusDoTs.swift" "$BUILD/BurnState.swift" \
       "$BUILD/GameTimer.swift" "$BUILD/PlayerDamagePipeline.swift" \
       "$BUILD/PlayerStats.swift" "$BUILD/UpgradeManager.swift"
"$BUILD/harness"
