#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
task_packet_tmp=$(mktemp -d "${TMPDIR:-/tmp}/sf-packet.XXXXXX")
trap 'rm -rf "$task_packet_tmp"' EXIT
xcrun swiftc Sparkforge/Systems/Arena8PacketCommands.swift tools/arena8-packet-harness/main.swift -o "$task_packet_tmp/packet"
"$task_packet_tmp/packet"
