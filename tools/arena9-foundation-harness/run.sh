#!/bin/sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT HUP INT TERM
for CONFIG in Debug Release; do
    if [ "$CONFIG" = Debug ]; then DEFINE=-DDEBUG; else DEFINE=; fi
    swiftc $DEFINE -O -module-cache-path "$BUILD/module-cache" \
        "$ROOT/Sparkforge/Config/Arena9StageDefinition.swift" \
        "$ROOT/Sparkforge/Systems/Arena9StageBounds.swift" \
        "$ROOT/Sparkforge/Systems/Arena9EncounterLedger.swift" \
        "$HERE/main.swift" -o "$BUILD/foundation"
    echo "$CONFIG real-source model"
    "$BUILD/foundation"
done
