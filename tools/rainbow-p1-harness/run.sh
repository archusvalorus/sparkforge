#!/bin/sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT HUP INT TERM
cp "$ROOT/Sparkforge/Config/ArenaGeometry.swift" \
   "$ROOT/Sparkforge/Systems/MeleeSector.swift" \
   "$ROOT/Sparkforge/Systems/DirectHitDamage.swift" \
   "$ROOT/Sparkforge/Systems/VoidState.swift" \
   "$ROOT/Sparkforge/Systems/GameTimer.swift" \
   "$ROOT/Sparkforge/Systems/KillSource.swift" \
   "$ROOT/Sparkforge/Systems/ChainReaction.swift" \
   "$ROOT/Sparkforge/Utils/VectorMath.swift" \
   "$ROOT/tools/geometry-harness/Stubs.swift" "$HERE/main.swift" "$BUILD/"
cp "${SPARKFORGE_P1_MODEL_PATH:-$ROOT/Sparkforge/Prototypes/RainbowP1Model.swift}" "$BUILD/RainbowP1Model.swift"
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" \
   "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/ExtractedConfig.swift" Geometry Arena Growth Neutral BossClass RainbowPrototype
swiftc -DDEBUG -module-cache-path "$BUILD/module-cache" -O -o "$BUILD/rainbow-p1" "$BUILD/"*.swift
"$BUILD/rainbow-p1" "$ROOT"
