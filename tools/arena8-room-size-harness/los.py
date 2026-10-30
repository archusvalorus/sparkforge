from pathlib import Path
import os, subprocess, tempfile

root = Path(__file__).resolve().parents[2]
scene = Path(os.environ.get('SPARKFORGE_A8_ROOM_LOS_SCENE_PATH', root / 'Sparkforge/Scenes/GameScene.swift')).read_text()
assert 'let hasLoS = rangedHasLineOfSight(from: ranged.position, to: player.position)' in scene
start = scene.index('    private func rangedHasLineOfSight(')
opening = scene.index('{', start)
depth, end = 1, opening + 1
while depth:
    if scene[end] == '{': depth += 1
    elif scene[end] == '}': depth -= 1
    end += 1
# Only visibility changes; function body is copied from the actual Scene.
method = scene[start:end].replace('private func', 'func', 1)
main = '''import Foundation
import CoreGraphics
struct SceneProbe {
 var debugRoomIntegration: Arena8GameMap?
 var arenaGeometry: ArenaGeometry
''' + method + '''
}
@main struct Main {
 static func main() {
  var passed=0,failed=0
  func check(_ id:String,_ yes:Bool){if yes {passed+=1;print("PASS \\(id)")}else{failed+=1;print("FAIL \\(id)")}}
  let map=Arena8GameMap.sixRoom
  let corner=CGPoint(x:map.rooms[0].rect.maxX,y:map.connections[0].corridor.minY)
  let a=corner+CGPoint(x:-20,y:-40),b=corner+CGPoint(x:40,y:20)
  check("short corner is actual valid floor",map.valid(a,radius:14) && map.valid(b,radius:14))
  check("short corner exposes legacy miss",!map.geometry.segmentBlocked(a,b,travelRadius:3) && map.geometry.segmentBlockedExact(a,b,travelRadius:3))
  for context:Arena8GameMap? in [map,nil,.twoRoom] {
   let probe=SceneProbe(debugRoomIntegration:context,arenaGeometry:map.geometry)
   check("actual selector scope",probe.rangedHasLineOfSight(from:a,to:b)==(context?.isSixRoom != true))
  }
  let room=SceneProbe(debugRoomIntegration:map,arenaGeometry:map.geometry)
  for c in map.connections {
   let direction=(map.rooms[c.to].center-map.rooms[c.from].center).normalized
   check("open passage firing retained",room.rangedHasLineOfSight(from:c.center-direction*40,to:c.center+direction*40))
   check("full wall still blocks",!room.rangedHasLineOfSight(from:map.rooms[c.from].center+CGPoint(x:100,y:100),to:map.rooms[c.to].center+CGPoint(x:100,y:100)))
  }
  print("RESULT \\(passed) passed \\(failed) failed");exit(failed==0 ? 0:1)
 }
}
'''
with tempfile.TemporaryDirectory(prefix='sf-room-los-') as temporary:
    path = Path(temporary) / 'main.swift'
    # @main declaration must not share the special top-level main.swift name.
    path = path.with_name('LoSProbe.swift')
    path.write_text(main)
    script = (root / 'tools/arena8-six-harness/run.sh').read_text()
    script = script.replace('HERE="$(cd "$(dirname "$0")" && pwd)"', 'HERE="' + str(root / 'tools/arena8-six-harness') + '"')
    script = script.replace('"$HERE/main.swift"', '"' + str(path) + '"')
    result = subprocess.run(['sh', '-c', script], cwd=root)
    raise SystemExit(result.returncode)
