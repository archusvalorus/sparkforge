#!/bin/sh
# Isolated R0 proof over real catalog/acquisition/draft seams. No game launch.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT HUP INT TERM
export SPARKFORGE_CATALOG_PATH="$ROOT/Sparkforge/Catalog/ability-catalog.json"
cp "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" \
   "$ROOT/Sparkforge/Systems/GuardState.swift" \
   "$ROOT/Sparkforge/Systems/VoidState.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/AbilityCatalog.swift" \
   "$ROOT/Sparkforge/Systems/AbilityBehaviors.swift" \
   "$ROOT/tools/signature-draw-harness/Stubs.swift" "$HERE/main.swift" "$BUILD/"
cp "${SPARKFORGE_RAINBOW_POLICY_PATH:-$ROOT/Sparkforge/Systems/RainbowPolicy.swift}" "$BUILD/RainbowPolicy.swift"
python3 "$HERE/extract-draft-seam.py" \
   "${SPARKFORGE_RAINBOW_MANAGER_PATH:-$ROOT/Sparkforge/Systems/UpgradeManager.swift}" "$BUILD/UpgradeManager.swift"
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" \
   "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/ExtractedConfig.swift" \
   Guard VoidTree Drafting Panda Growth Chill BossClass Erasure Shock Neutral
swiftc -module-cache-path "$BUILD/module-cache" -O -o "$BUILD/rainbow-r0" "$BUILD/"*.swift
"$BUILD/rainbow-r0" "$ROOT"
