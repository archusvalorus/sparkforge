#!/bin/sh
# BGM deck harness (v2.1 geometry Unit 4).
#
# Compiles the REAL Sparkforge/Systems/BGMDeck.swift and executes the settled
# deck rules with seeded generators (docs/arena6-geometry-reconciliation.md
# §5 Unit 4, audio subunit), then checks the bundled tracks themselves: exactly
# 20 generic bgm_*.mp3 files whose bytes match the verified import map.
# Exits non-zero on any failure.
#
# Usage (from repo root):  sh tools/bgm-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Systems/BGMDeck.swift" "$HERE/main.swift" "$BUILD/"
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/BGMDeck.swift"
BGM_DIR="$ROOT/Sparkforge/Audio/BGM" BGM_MAP="$HERE/import-map.csv" "$BUILD/harness"
