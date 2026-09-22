#!/bin/sh
# HUD proof harness (v2.1 abilities A4b corrective pass).
#
# Compiles the REAL HPBarNode.swift with BarrierTellState.swift and
# ColorExtensions.swift (SpriteKit builds on macOS) and probes what the Blood
# Barrier strip actually PRESENTS — geometry + number, not just a visible flag.
# It exists because the same-frame grant→depletion defect lived at the
# node/presentation boundary, where a pure-state test cannot reach it.
#
# Usage (from repo root):  sh tools/hud-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Nodes/HPBarNode.swift" \
   "$ROOT/Sparkforge/Systems/BarrierTellState.swift" \
   "$ROOT/Sparkforge/Utils/ColorExtensions.swift" \
   "$HERE/Stubs.swift" "$HERE/main.swift" "$BUILD/"
swiftc -O -DDEBUG -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/HPBarNode.swift" "$BUILD/BarrierTellState.swift" "$BUILD/ColorExtensions.swift"
"$BUILD/harness"
