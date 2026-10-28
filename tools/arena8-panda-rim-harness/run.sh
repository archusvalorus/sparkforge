#!/bin/sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT HUP INT TERM
cp "${SPARKFORGE_A8_PANDA_ENTRY_PATH:-$ROOT/Sparkforge/Prototypes/Arena8PandaEntry.swift}" "$BUILD/Entry.swift"
cp "$HERE/main.swift" "$BUILD/main.swift"
swiftc -DDEBUG -module-cache-path "$BUILD/module-cache" -O -o "$BUILD/panda-rim" "$BUILD/"*.swift
"$BUILD/panda-rim"
