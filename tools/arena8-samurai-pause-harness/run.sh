#!/bin/sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT HUP INT TERM
cp "$HERE/Boundary.swift" "$HERE/main.swift" "$BUILD/"
python3 "$HERE/extract.py" "${SPARKFORGE_A8_SAMURAI_PAUSE_NODE_PATH:-$ROOT/Sparkforge/Nodes/PandaNode.swift}" "${SPARKFORGE_A8_SAMURAI_PAUSE_SCENE_PATH:-$ROOT/Sparkforge/Scenes/GameScene.swift}" "$BUILD/Actual.swift"
swiftc -module-cache-path "$BUILD/module-cache" -O -o "$BUILD/samurai" "$BUILD/"*.swift
"$BUILD/samurai"
