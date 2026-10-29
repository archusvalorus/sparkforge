#!/bin/sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT HUP INT TERM
cp "$ROOT/Sparkforge/Config/ArenaGeometry.swift" "$ROOT/Sparkforge/Systems/MeleeSector.swift" \
 "$ROOT/Sparkforge/Utils/VectorMath.swift" "$ROOT/tools/geometry-harness/Stubs.swift" "$HERE/main.swift" "$BUILD/"
cp "$ROOT/Sparkforge/Prototypes/Arena8P0Config.swift" "$ROOT/Sparkforge/Prototypes/Arena8GameConfig.swift" "$BUILD/"
cp "${SPARKFORGE_A8_GROWTH_MAP_PATH:-$ROOT/Sparkforge/Prototypes/Arena8GameMap.swift}" "$BUILD/Arena8GameMap.swift"
cp "$ROOT/Sparkforge/Prototypes/RainbowP1Model.swift" "$ROOT/Sparkforge/Systems/DirectHitDamage.swift" \
 "$ROOT/Sparkforge/Systems/VoidState.swift" "$ROOT/Sparkforge/Systems/GameTimer.swift" \
 "$ROOT/Sparkforge/Systems/KillSource.swift" "$ROOT/Sparkforge/Systems/ChainReaction.swift" "$BUILD/"
cp "${SPARKFORGE_P0_BOUNDS_PATH:-$ROOT/Sparkforge/Prototypes/Arena8P0Bounds.swift}" "$BUILD/Arena8P0Bounds.swift"
cp "${SPARKFORGE_P0_MODEL_PATH:-$ROOT/Sparkforge/Prototypes/Arena8P0Model.swift}" "$BUILD/Arena8P0Model.swift"
cp "${SPARKFORGE_A8_GARDEN_PATH:-$ROOT/Sparkforge/Prototypes/Arena8GardenFootprint.swift}" "$BUILD/Arena8GardenFootprint.swift"
cp "${SPARKFORGE_A8_PANDA_PICKUP_PATH:-$ROOT/Sparkforge/Prototypes/Arena8PandaPickupPlacement.swift}" "$BUILD/Arena8PandaPickupPlacement.swift"
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/ExtractedConfig.swift" Geometry Arena Growth Neutral BossClass RainbowPrototype VoidTree Panda
cp "${SPARKFORGE_A8_PANDA_DESTINATION_PATH:-$ROOT/Sparkforge/Prototypes/Arena8PandaDestination.swift}" "$BUILD/Arena8PandaDestination.swift"
python3 "$HERE/extract.py" "${SPARKFORGE_A8_SAMURAI_SCENE_PATH:-$ROOT/Sparkforge/Scenes/GameScene.swift}" "$ROOT/Sparkforge/Nodes/PandaNode.swift" "$BUILD/ActualSamurai.swift"
python3 - "$BUILD/Stubs.swift" "$BUILD/Arena8PandaDestination.swift" <<'PATCH'
from pathlib import Path
import sys
p=Path(sys.argv[1]);p.write_text(p.read_text().replace('static var gameplay: CGFloat { 1 }','static var gameplay: CGFloat = 1'))
p=Path(sys.argv[2]);p.write_text(p.read_text().replace('struct Arena8PandaDestination','struct RealDestination'))
PATCH
swiftc -DDEBUG -module-cache-path "$BUILD/module-cache" -O -o "$BUILD/arena8-samurai" "$BUILD/"*.swift
"$BUILD/arena8-samurai"
