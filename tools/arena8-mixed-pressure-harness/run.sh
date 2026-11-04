#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
task_mixed_tmp=$(mktemp -d "${TMPDIR:-/tmp}/sf-mixed.XXXXXX")
trap 'rm -rf "$task_mixed_tmp"' EXIT
xcrun swiftc -D DEBUG -module-cache-path "${TMPDIR:-/tmp}/sf-mixed-module-cache" "${SPARKFORGE_MIXED_CLOCK_PATH:-Sparkforge/Prototypes/Arena8PreviewSpawnClock.swift}" Sparkforge/Prototypes/Arena8MixedPressureMode.swift tools/arena8-mixed-pressure-harness/main.swift -o "$task_mixed_tmp/mixed"
"$task_mixed_tmp/mixed"
