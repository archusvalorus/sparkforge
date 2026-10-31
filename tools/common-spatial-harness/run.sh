#!/bin/sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT HUP INT TERM
cp "$ROOT/Sparkforge/Config/ArenaGeometry.swift" "$ROOT/Sparkforge/Systems/MeleeSector.swift" "$ROOT/Sparkforge/Systems/AttackPattern.swift" "$ROOT/Sparkforge/Utils/VectorMath.swift" "$ROOT/tools/geometry-harness/Stubs.swift" "$HERE/main.swift" "$BUILD/"
cp "$ROOT/Sparkforge/Prototypes/Arena8P0Config.swift" "$ROOT/Sparkforge/Prototypes/Arena8GameConfig.swift" "$ROOT/Sparkforge/Config/Arena9StageDefinition.swift" "$ROOT/Sparkforge/Config/Arena9TraversalConfig.swift" "$ROOT/Sparkforge/Prototypes/Arena8P0Bounds.swift" "$ROOT/Sparkforge/Prototypes/Arena8P0Model.swift" "$BUILD/"
cp "${SPARKFORGE_COMMON_MAP_PATH:-$ROOT/Sparkforge/Prototypes/Arena8GameMap.swift}" "$BUILD/Arena8GameMap.swift"
cp "${SPARKFORGE_COMMON_BEAM_PATH:-$ROOT/Sparkforge/Systems/BeamTick.swift}" "$BUILD/BeamTick.swift"
sh "$ROOT/tools/signature-draw-harness/extract-config.sh" "$ROOT/Sparkforge/Config/GameConfig.swift" "$BUILD/ExtractedConfig.swift" Geometry Arena Growth Neutral BossClass RainbowPrototype
python3 - "$HERE" "$ROOT" "$BUILD" <<'PY'
from pathlib import Path
import sys,json,hashlib
here,root,build=map(Path,sys.argv[1:]);f=here/'fixtures';p=json.loads((f/'provenance.json').read_text())
for name,key in [('Sparkforge/Systems/AbilityBehaviors.swift','ability_behaviors_sha256'),('Sparkforge/Systems/PlayerStats.swift','player_stats_sha256'),('Sparkforge/Config/GameConfig.swift','game_config_sha256'),('Sparkforge/Systems/AttackPattern.swift','attack_pattern_sha256')]:assert hashlib.sha256((root/name).read_bytes()).hexdigest()==p[key],name+' recorded radius provenance changed; recapture actual effect proof'
s=(f/'BeamTick-T1.swift').read_bytes();assert hashlib.sha256(s).hexdigest()==p['legacy_beam_sha256'];text=s.decode();assert text.count('enum BeamTick {')==1;(build/'LegacyCircle.swift').write_text(text.replace('enum BeamTick {','enum BaselineBeamTick {',1))
PY
swiftc -DDEBUG -O -module-cache-path "$BUILD/module-cache" "$BUILD/"*.swift -o "$BUILD/common-spatial"
"$BUILD/common-spatial" "$HERE/fixtures/provenance.json"
