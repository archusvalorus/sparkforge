#!/bin/sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$HERE/../tollkeeper-harness/run.py" "$HERE/main.swift"
