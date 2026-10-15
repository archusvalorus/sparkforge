#!/bin/sh
# Neutral harness (v2.2 Neutral rework, Unit N2).
#
# Compiles the REAL XPLedger.swift (the run's XP/level rules: the cap, the
# bank, the carried fraction, the granted level) and the REAL PlayerStats.swift
# (Overclock's trio and clock) with the same support sources and stubs the
# other runners use, plus the catalog-backed UpgradeManager so XP Boost and
# Overclock can be applied through their real effects — and (Oct 12
# corrective) the level-queue SEAM: the scene's resume/opener functions and
# PlayerNode's XP members extracted verbatim at build time (extract-queue.py)
# and EXECUTED over the real ledger (the QX group).
# v2.2 N4: the chaos beam's pure rules (BeamTick, BeamClock over the real
# FireClock) are the BX group; its exact parent hits (beamParentHit /
# beamParentHitBoss, with the shared forgeOffense) are extracted into the hit
# seam and executed as BH (statistical where the production threshold is
# drawn fresh — labeled).
# Every other check is deterministic. Exits non-zero on any failure.
#
# Usage (from repo root):  sh tools/neutral-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
export SPARKFORGE_CATALOG_PATH="${SPARKFORGE_CATALOG_PATH:-$ROOT/Sparkforge/Catalog/ability-catalog.json}"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Systems/XPLedger.swift" \
   "$ROOT/Sparkforge/Systems/AttackPattern.swift" \
   "$ROOT/Sparkforge/Systems/BeamTick.swift" "$ROOT/Sparkforge/Systems/BeamClock.swift" "$ROOT/Sparkforge/Systems/FireClock.swift" \
   "$ROOT/Sparkforge/Systems/ChainReaction.swift" "$ROOT/Sparkforge/Systems/KillContext.swift" "$ROOT/Sparkforge/Systems/StatusDoTs.swift" \
   "$ROOT/Sparkforge/Systems/BurnState.swift" "$ROOT/Sparkforge/Systems/BleedState.swift" "$ROOT/Sparkforge/Systems/SnowmanState.swift" \
   "$ROOT/Sparkforge/Systems/KillSource.swift" \
   "$ROOT/Sparkforge/Systems/DirectHitDamage.swift" \
   "$ROOT/Sparkforge/Utils/VectorMath.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/GuardState.swift" \
   "$ROOT/Sparkforge/Systems/VoidState.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/Sparkforge/Systems/AbilityCatalog.swift" "$ROOT/Sparkforge/Systems/AbilityBehaviors.swift" \
   "$ROOT/tools/signature-draw-harness/Stubs.swift" \
   "$HERE/main.swift" "$BUILD/"
# v2.2 N2 corrective: the level-queue seam — the scene's queue functions and
# PlayerNode's XP members, extracted VERBATIM from the live sources into shell
# classes over the real XPLedger/PlayerStats, so the QX checks EXECUTE the
# production control flow.
python3 "$HERE/extract-queue.py" "$ROOT/Sparkforge/Scenes/GameScene.swift" "$ROOT/Sparkforge/Nodes/PlayerNode.swift" "$BUILD/QueueShell.swift" || exit 1
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" \
   "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/ExtractedConfig.swift" Guard VoidTree Drafting Panda Growth Chill BossClass Erasure Shock Neutral Leveling
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/XPLedger.swift" "$BUILD/AttackPattern.swift" "$BUILD/BeamTick.swift" "$BUILD/BeamClock.swift" "$BUILD/FireClock.swift" "$BUILD/ChainReaction.swift" "$BUILD/KillContext.swift" "$BUILD/StatusDoTs.swift" "$BUILD/BurnState.swift" "$BUILD/BleedState.swift" "$BUILD/SnowmanState.swift" "$BUILD/KillSource.swift" "$BUILD/DirectHitDamage.swift" "$BUILD/VectorMath.swift" "$BUILD/QueueShell.swift" "$BUILD/GameTimer.swift" \
       "$BUILD/PlayerDamagePipeline.swift" "$BUILD/GuardState.swift" "$BUILD/ExtractedConfig.swift" "$BUILD/VoidState.swift" "$BUILD/PlayerStats.swift" \
       "$BUILD/UpgradeManager.swift" "$BUILD/AbilityCatalog.swift" "$BUILD/AbilityBehaviors.swift"
"$BUILD/harness"
