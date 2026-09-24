#!/bin/sh
# Red Smile proof harness (v2.1 abilities Unit A4c).
#
# Compiles the REAL CombatPresence.swift (active combat, CL-33),
# RedSmileState.swift (the 10s start-to-start cycle, the 3s form and its melee
# clock, kaiju priority — CL-34/42/44), MeleeSector.swift (body-radius-aware
# sector overlap, CL-41), FireClock.swift, KillSource.swift, and PlayerStats +
# UpgradeManager (+ PlayerDamagePipeline and GameTimer, which PlayerStats
# needs) against the signature harness's host stubs, then runs the
# deterministic validators in main.swift. Re-run after ANY change to Red Smile,
# active combat, the sweep test or the Bleed/Void cards — exits non-zero on any
# failure.
#
# Usage (from repo root):  sh tools/redsmile-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Systems/CombatPresence.swift" \
   "$ROOT/Sparkforge/Systems/RedSmileState.swift" \
   "$ROOT/Sparkforge/Systems/MeleeSector.swift" \
   "$ROOT/Sparkforge/Systems/FireClock.swift" \
   "$ROOT/Sparkforge/Systems/KillSource.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/GuardState.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/tools/signature-draw-harness/Stubs.swift" \
   "$HERE/main.swift" "$BUILD/"
sh "$ROOT/tools/signature-draw-harness/extract-guard-config.sh" \
   "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/GuardConfig.swift"
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/CombatPresence.swift" "$BUILD/RedSmileState.swift" \
       "$BUILD/MeleeSector.swift" "$BUILD/FireClock.swift" "$BUILD/KillSource.swift" \
       "$BUILD/GameTimer.swift" "$BUILD/PlayerDamagePipeline.swift" "$BUILD/GuardState.swift" "$BUILD/GuardConfig.swift" \
       "$BUILD/PlayerStats.swift" "$BUILD/UpgradeManager.swift"
"$BUILD/harness"
