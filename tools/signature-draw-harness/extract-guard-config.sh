#!/bin/sh
# Extract the REAL `GameConfig.Guard` block (v2.1 A5) from GameConfig.swift into
# a harness source file, wrapped in `extension GameConfig { … }`, so the
# harnesses run the shipped Guard numbers and tuning builders — never a hand
# mirror that could drift (A5 internal review, H1). The block ends at the first
# line that is exactly four spaces and a closing brace.
# Usage: extract-guard-config.sh <GameConfig.swift> <out.swift>
set -e
awk '
  BEGIN { print "import CoreGraphics"; print "import Foundation"; print "" }
  /^    enum Guard \{/ { inside = 1; print "extension GameConfig {" }
  inside { print }
  inside && /^    \}$/ { print "}"; found = 1; exit }
  END { if (!found) exit 1 }
' "$1" > "$2"
