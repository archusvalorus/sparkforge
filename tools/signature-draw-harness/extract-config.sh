#!/bin/sh
# Extract REAL `GameConfig.<Enum>` blocks from GameConfig.swift into one
# harness source file, each wrapped in `extension GameConfig { … }`, so the
# harnesses run the shipped numbers and tuning builders — never a hand mirror
# that could drift (A5 internal review, H1). v2.1 A6 generalized the A5
# Guard-only script: pass every enum the compiled sources read. A block ends at
# the first line that is exactly four spaces and a closing brace; the script
# fails if any requested enum is missing.
# Usage: extract-config.sh <GameConfig.swift> <out.swift> <Enum> [<Enum> …]
set -e
SRC="$1"; OUT="$2"; shift 2
[ $# -gt 0 ] || { echo "extract-config.sh: no enum names" >&2; exit 1; }
awk -v names="$*" '
  BEGIN {
    n = split(names, want, " ")
    for (i = 1; i <= n; i++) wanted[want[i]] = 1
    print "import CoreGraphics"; print "import Foundation"; print ""
  }
  !inside && /^    enum [A-Za-z]+ \{/ {
    name = $2
    if (name in wanted) { inside = 1; print "extension GameConfig {" }
  }
  inside { print }
  inside && /^    \}[[:space:]]*$/ { print "}"; print ""; inside = 0; found[name] = 1 }
  END {
    for (i = 1; i <= n; i++) if (!(want[i] in found)) { print "missing enum " want[i] > "/dev/stderr"; exit 1 }
  }
' "$SRC" > "$OUT"
