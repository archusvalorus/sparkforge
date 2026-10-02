#!/bin/sh
# Geometry proof harness (v2.1 abilities Unit A7b, seam S0b).
#
# Compiles the REAL ArenaGeometry.swift (footprints, resolve, the stepped and
# exact segment tests, the shared placement sampler, the Splitworks layout),
# MeleeSector.swift (the exact rounded-box segment test) and VectorMath.swift,
# plus the REAL `GameConfig.Geometry` and `GameConfig.Arena` blocks extracted
# from source (the arena-radius formula executes as shipped), then runs
# seeded validators in main.swift. Nothing in the app compiled ArenaGeometry
# for a test before this; every A7b CL-109 seam adds its executed checks here.
#
# Usage (from repo root):  sh tools/geometry-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Config/ArenaGeometry.swift" \
   "$ROOT/Sparkforge/Systems/MeleeSector.swift" \
   "$ROOT/Sparkforge/Utils/VectorMath.swift" \
   "$HERE/Stubs.swift" "$HERE/main.swift" "$BUILD/"
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" \
   "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/ExtractedConfig.swift" Geometry Arena Growth
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/ArenaGeometry.swift" "$BUILD/MeleeSector.swift" "$BUILD/VectorMath.swift" \
       "$BUILD/ExtractedConfig.swift"
GEO_ARENACONFIG="$ROOT/Sparkforge/Config/ArenaConfig.swift" \
GEO_DEVICESCALE="$ROOT/Sparkforge/Utils/DeviceScale.swift" "$BUILD/harness"
