#!/usr/bin/env python3
"""Execute actual registries and launch reconciliation against an isolated defaults suite.
Only SDK boss factories and unrelated progression collaborators are stubbed.
"""
from pathlib import Path
import tempfile,subprocess,os
root=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='sf-a7-integration-') as directory:
 out=Path(directory)
 p=(root/'Sparkforge/Systems/ProgressionManager.swift').read_text()
 # Access-only constructor exposure; retain the complete real reconciliation.
 p=p.replace('private init()', 'init()').replace('private let defaults = UserDefaults.standard','private let defaults = TestDefaults.store')
 (out/'Progression.swift').write_text(p)
 # This command-line probe is single-threaded; the real app still compiles the
 # original MainActor annotation in both Debug and Release.
 b=(root/'Sparkforge/Systems/BossRegistry.swift').read_text().replace('import SpriteKit','import Foundation').replace('@MainActor\n','')
 (out/'Registry.swift').write_text(b)
 subprocess.run(['sh',str(root/'tools/signature-draw-harness/extract-config.sh'),str(root/'Sparkforge/Config/GameConfig.swift'),str(out/'Config.swift'),'Arena','Geometry','Wave','BossMode'],check=True)
 sources=[out/'Progression.swift',out/'Registry.swift',out/'Config.swift',root/'Sparkforge/Config/ArenaConfig.swift',root/'Sparkforge/Config/ArenaGeometry.swift',root/'Sparkforge/Systems/MeleeSector.swift',root/'Sparkforge/Utils/VectorMath.swift',root/'tools/arena7-integration-harness/Stubs.swift',root/'tools/arena7-integration-harness/main.swift']
 binary=out/'probe'
 subprocess.run(['swiftc','-D','DEBUG','-module-cache-path',os.environ.get('A7_MODULE_CACHE','/tmp/sf-a7-integration-cache'),'-o',str(binary),*map(str,sources)],check=True)
 raise SystemExit(subprocess.run([str(binary)]).returncode)
