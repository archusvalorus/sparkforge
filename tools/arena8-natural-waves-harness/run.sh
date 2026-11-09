#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d /tmp/sf-natural-model.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
cp "$ROOT/Sparkforge/Prototypes/Arena8NaturalWaveRun.swift" "$TMP/Run.swift"
cp "$ROOT/Sparkforge/Prototypes/Arena8MixedPressureMode.swift" "$TMP/Mode.swift"
cp "$ROOT/Sparkforge/Prototypes/Arena8PreviewSpawnClock.swift" "$TMP/Clock.swift"
cp "$ROOT/tools/arena8-natural-waves-harness/main.swift" "$TMP/main.swift"
swiftc -module-cache-path "$TMP/cache" -D DEBUG "$TMP/Run.swift" "$TMP/Mode.swift" "$TMP/Clock.swift" "$TMP/main.swift" -o "$TMP/proof"
"$TMP/proof"
