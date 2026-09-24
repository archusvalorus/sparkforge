#!/bin/sh
# Guard proof harness (v2.1 abilities Unit A5).
#
# Compiles the REAL GuardState.swift (stillness, Fortify, Grounded Core,
# Ironhide, Unbroken's window, the projectile shield, the contact bounce, Iron
# Bloom, Repulse's launch), CombatPresence.swift (active combat, CL-33 — the
# definition Grounded Core reuses), KillSource.swift, PlayerDamagePipeline +
# GameTimer, and PlayerStats + UpgradeManager against the signature harness's
# host stubs — plus the REAL `GameConfig.Guard` block, extracted from source —
# then runs the deterministic validators in main.swift. It also reads
# GameScene.swift to prove the scene WIRING exists (the scene isn't compiled).
# Re-run after ANY change to a Guard card, the ladder or the damage pipeline —
# exits non-zero on any failure.
#
# Usage (from repo root):  sh tools/guard-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Systems/GuardState.swift" \
   "$ROOT/Sparkforge/Systems/CombatPresence.swift" \
   "$ROOT/Sparkforge/Systems/KillSource.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/tools/signature-draw-harness/Stubs.swift" \
   "$HERE/main.swift" "$BUILD/"
sh "$ROOT/tools/signature-draw-harness/extract-guard-config.sh" \
   "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/GuardConfig.swift"
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/GuardState.swift" "$BUILD/GuardConfig.swift" "$BUILD/CombatPresence.swift" "$BUILD/KillSource.swift" \
       "$BUILD/GameTimer.swift" "$BUILD/PlayerDamagePipeline.swift" \
       "$BUILD/PlayerStats.swift" "$BUILD/UpgradeManager.swift"
GUARD_CONFIG="$ROOT/Sparkforge/Config/GameConfig.swift" \
GUARD_SCENE="$ROOT/Sparkforge/Scenes/GameScene.swift" "$BUILD/harness"
