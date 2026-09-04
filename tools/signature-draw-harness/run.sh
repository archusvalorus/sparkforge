#!/bin/sh
# Signature-draw proof harness (v2.1 abilities Unit 1).
#
# Compiles the REAL UpgradeManager.swift + PlayerStats.swift against host
# stubs (Stubs.swift) and runs the deterministic validators in main.swift.
# Re-run after ANY change to the draw path or the per-tree provides/requires
# authoring (the rework pass) — takes ~15s, exits non-zero on any failure.
#
# Usage (from repo root):  sh tools/signature-draw-harness/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/Sparkforge/Systems/UpgradeManager.swift" \
   "$ROOT/Sparkforge/Systems/PlayerStats.swift" \
   "$HERE/Stubs.swift" "$HERE/main.swift" "$BUILD/"
swiftc -O -o "$BUILD/harness" "$BUILD/main.swift" "$BUILD/Stubs.swift" \
       "$BUILD/UpgradeManager.swift" "$BUILD/PlayerStats.swift"
"$BUILD/harness"
