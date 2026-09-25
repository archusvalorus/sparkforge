#!/bin/sh
# Void proof harness (v2.1 abilities Unit A6).
#
# Compiles the REAL VoidState.swift (rounding, Warp, Riftline, Void affinity,
# Anomaly, fear + flight, the volley counter, the black hole, the trap and
# Singularity), KillSource.swift, GuardState + PlayerDamagePipeline + GameTimer,
# and PlayerStats + UpgradeManager against the signature harness's host stubs —
# plus the REAL `GameConfig.Guard` and `GameConfig.VoidTree` blocks, extracted
# from source — then runs the deterministic validators in main.swift. It also
# reads GameScene / EnemyNode / ProjectileNode to prove the WIRING exists (the
# scene isn't compiled). Re-run after ANY change to a Void card, the ladder,
# the hit chains or the black holes — exits non-zero on any failure.
#
# Usage (from repo root):  sh tools/void-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Systems/VoidState.swift" \
   "$ROOT/Sparkforge/Systems/GuardState.swift" \
   "$ROOT/Sparkforge/Systems/KillSource.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/tools/signature-draw-harness/Stubs.swift" \
   "$HERE/main.swift" "$BUILD/"
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" \
   "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/ExtractedConfig.swift" Guard VoidTree
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/VoidState.swift" "$BUILD/GuardState.swift" "$BUILD/ExtractedConfig.swift" \
       "$BUILD/KillSource.swift" "$BUILD/GameTimer.swift" "$BUILD/PlayerDamagePipeline.swift" \
       "$BUILD/PlayerStats.swift" "$BUILD/UpgradeManager.swift"
VOID_SCENE="$ROOT/Sparkforge/Scenes/GameScene.swift" \
VOID_CONFIG="$ROOT/Sparkforge/Config/GameConfig.swift" \
VOID_ENEMY="$ROOT/Sparkforge/Nodes/EnemyNode.swift" \
VOID_PROJECTILE="$ROOT/Sparkforge/Nodes/ProjectileNode.swift" \
VOID_WELLNODE="$ROOT/Sparkforge/Nodes/VoidWellNode.swift" \
VOID_BOSSTELL="$ROOT/Sparkforge/Nodes/BossStatusTellNode.swift" "$BUILD/harness"
