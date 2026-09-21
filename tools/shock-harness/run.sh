#!/bin/sh
# Shock proof harness (v2.1 abilities Unit A3).
#
# Compiles the REAL OverloadStunState.swift, GameTimer.swift, PlayerStats.swift and
# UpgradeManager.swift (+ PlayerDamagePipeline.swift, which PlayerStats needs)
# against the signature harness's host stubs, then runs the deterministic
# validators in main.swift: Chain Lightning's falloff (CL-12), Overload's
# stun immunity (CL-2), and the reworked Shock cards applied through
# the real card pool. Re-run after ANY change to chains, Overload or the Shock tree —
# exits non-zero on any failure.
#
# Usage (from repo root):  sh tools/shock-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Systems/OverloadStunState.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/tools/signature-draw-harness/Stubs.swift" \
   "$HERE/main.swift" "$BUILD/"
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/OverloadStunState.swift" "$BUILD/GameTimer.swift" \
       "$BUILD/PlayerDamagePipeline.swift" "$BUILD/PlayerStats.swift" \
       "$BUILD/UpgradeManager.swift"
"$BUILD/harness"
