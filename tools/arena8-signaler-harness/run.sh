#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
task_signal_tmp=$(mktemp -d "${TMPDIR:-/tmp}/sf-signaler.XXXXXX")
trap 'rm -rf "$task_signal_tmp"' EXIT
xcrun swiftc -module-cache-path "${TMPDIR:-/tmp}/sf-signaler-module-cache" "${SPARKFORGE_SIGNALER_CORE_PATH:-Sparkforge/Systems/Arena8PacketCommands.swift}" tools/arena8-signaler-harness/main.swift -o "$task_signal_tmp/signaler"
"$task_signal_tmp/signaler"
