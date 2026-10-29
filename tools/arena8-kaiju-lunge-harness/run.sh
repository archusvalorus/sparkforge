#!/bin/sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT HUP INT TERM
cp "$ROOT/Sparkforge/Config/ArenaGeometry.swift" "$ROOT/Sparkforge/Systems/MeleeSector.swift" "$ROOT/Sparkforge/Utils/VectorMath.swift" "$ROOT/tools/geometry-harness/Stubs.swift" "$HERE/main.swift" "$BUILD/"
cp "$ROOT/Sparkforge/Prototypes/Arena8P0Config.swift" "$ROOT/Sparkforge/Prototypes/Arena8GameConfig.swift" "$ROOT/Sparkforge/Prototypes/Arena8GameMap.swift" "$ROOT/Sparkforge/Prototypes/Arena8P0Bounds.swift" "$ROOT/Sparkforge/Prototypes/Arena8P0Model.swift" "$BUILD/"
cp "${SPARKFORGE_A8_KAIJU_PATH:-$ROOT/Sparkforge/Prototypes/Arena8KaijuLunge.swift}" "$BUILD/Arena8KaijuLunge.swift"
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/ExtractedConfig.swift" Geometry Arena Player
python3 "$HERE/extract.py" "${SPARKFORGE_A8_KAIJU_PLAYER_PATH:-$ROOT/Sparkforge/Nodes/PlayerNode.swift}" "$BUILD/ActualKaiju.swift"
swiftc -DDEBUG -module-cache-path "$BUILD/module-cache" -O -o "$BUILD/kaiju" "$BUILD/"*.swift
"$BUILD/kaiju"
