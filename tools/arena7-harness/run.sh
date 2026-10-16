#!/bin/sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
python3 "$HERE/extract-seams.py" "$ROOT" "$BUILD"
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" \
 "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/Config.swift" Arena Geometry Routing TwinChannels Enemy
cp "$HERE/main.swift" "$BUILD/main.swift"
swiftc -D DEBUG -module-cache-path "${A7_MODULE_CACHE:-/tmp/sf-a7-module-cache}" -o "$BUILD/probe" \
 "$BUILD/main.swift" "$HERE/LegacySteering.swift" "$HERE/Stubs.swift" "$BUILD/Seams.swift" "$BUILD/Chase.swift" "$BUILD/DeviceScale.swift" "$BUILD/Config.swift" \
 "$ROOT/Sparkforge/Config/ArenaGeometry.swift" "$ROOT/Sparkforge/Config/ArenaConfig.swift" \
 "$ROOT/Sparkforge/Systems/MeleeSector.swift" "$ROOT/Sparkforge/Utils/VectorMath.swift"
"$BUILD/probe"
