from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text();a=s.index('    private func resolveEnemiesAgainstGeometry() {'); b=s.index('        #endif',a)
block=s[a:b]+'        #endif\n    }'
out='import Foundation\nimport CoreGraphics\nfinal class FearBody {\n private var root:CGPoint\n var position:CGPoint { get { root } set { root=CGPoint(x:CGFloat(Float(newValue.x)),y:CGFloat(Float(newValue.y))) } }\n var isDying=false\n var geometryDisplacedThisFrame=false\n let geometryFootprintRadius:CGFloat\n init(_ p:CGPoint,_ radius:CGFloat){root=p;geometryFootprintRadius=radius}\n}\nfinal class ResolverProbe {\n var debugRoomIntegration:Arena8GameMap?\n var enemies:[FearBody]=[]\n var roomEnemyStarts:[ObjectIdentifier:CGPoint]=[:]\n var roomFearAccepted:[ObjectIdentifier:CGPoint]=[:]\n'
Path(sys.argv[2]).write_text(out+block+'\n func resolve(){resolveEnemiesAgainstGeometry()}\n}\n')
