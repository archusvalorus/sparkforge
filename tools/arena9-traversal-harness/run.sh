#!/bin/sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT HUP INT TERM
swiftc -O -module-cache-path "$BUILD/module-cache" "$ROOT/Sparkforge/Config/Arena9StageDefinition.swift" "$ROOT/Sparkforge/Systems/Arena9StageBounds.swift" "$ROOT/Sparkforge/Systems/Arena9EncounterLedger.swift" "${SPARKFORGE_A9_RUN_PATH:-$ROOT/Sparkforge/Systems/Arena9TraversalRun.swift}" "$HERE/main.swift" -o "$BUILD/traversal"
"$BUILD/traversal"
if [ "${SPARKFORGE_A9_MODEL_ONLY:-0}" = 1 ]; then exit 0; fi
mkdir "$BUILD/palette"
cp "$ROOT/Sparkforge/Systems/PlayerStats.swift" "$ROOT/Sparkforge/Systems/PlayerDamagePipeline.swift" "$ROOT/Sparkforge/Systems/GuardState.swift" "$ROOT/Sparkforge/Systems/VoidState.swift" "$ROOT/Sparkforge/Systems/GameTimer.swift" "$ROOT/Sparkforge/Systems/AbilityCatalog.swift" "$ROOT/Sparkforge/Systems/AbilityBehaviors.swift" "$ROOT/Sparkforge/Systems/UpgradeManager.swift" "$ROOT/Sparkforge/Systems/RainbowPolicy.swift" "$ROOT/tools/signature-draw-harness/Stubs.swift" "$BUILD/palette/"
cp "$HERE/palette.swift" "$BUILD/palette/main.swift"
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/palette/ExtractedConfig.swift" Guard VoidTree Drafting Panda Growth Chill BossClass Erasure Shock Neutral
export SPARKFORGE_CATALOG_PATH="$ROOT/Sparkforge/Catalog/ability-catalog.json"
swiftc -O -module-cache-path "$BUILD/module-cache" "$BUILD/palette/"*.swift -o "$BUILD/palette-checks"
"$BUILD/palette-checks"
