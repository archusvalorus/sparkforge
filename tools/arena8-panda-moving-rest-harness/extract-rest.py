from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text();start=source.index('    private func preparePandaMovingRest(');i=source.index('{',start);depth=1;end=i+1
while depth:
 depth+=(source[end]=='{')-(source[end]=='}');end+=1
body=source[start:end].replace('private func','func',1)
Path(sys.argv[2]).write_text('import Foundation\nimport CoreGraphics\nfinal class MovingRestScene {\n var debugRoomIntegration: Arena8GameMap?\n'+body+'\n}\n')
