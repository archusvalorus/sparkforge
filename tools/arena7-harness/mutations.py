#!/usr/bin/env python3
"""Focused A7 controls; mutations run only on isolated copies, never the live repo."""
from pathlib import Path
import tempfile, shutil, subprocess, json
root = Path(__file__).resolve().parents[2]
files = [
 "tools/arena7-harness/run.sh", "tools/arena7-harness/extract-seams.py",
 "tools/arena7-harness/main.swift", "tools/arena7-harness/Stubs.swift",
 "tools/arena7-harness/LegacySteering.swift", "tools/signature-draw-harness/extract-config.sh",
 "Sparkforge/Config/ArenaConfig.swift", "Sparkforge/Config/ArenaGeometry.swift",
 "Sparkforge/Config/GameConfig.swift", "Sparkforge/Scenes/GameScene.swift",
 "Sparkforge/Utils/GeometryDebug.swift", "Sparkforge/Systems/MeleeSector.swift",
 "Sparkforge/Utils/VectorMath.swift", "Sparkforge/Utils/DeviceScale.swift", "Sparkforge/Nodes/EnemyNode.swift"]
controls = [
 ("M1 scene bypasses graph", "Sparkforge/Scenes/GameScene.swift", "if geo.usesRouteGraph {", "if false {"),
 ("M2 graph ignores actor clearance", "Sparkforge/Config/ArenaGeometry.swift", "current.position, next.position, travelRadius: travelRadius", "current.position, next.position, travelRadius: 0"),
 ("M3 near-player rejection removed", "Sparkforge/Config/ArenaGeometry.swift", "&& p.distance(to: player) >= playerClearance + actorRadius", "&& true"),
 ("M4 unsafe anchor fallback", "Sparkforge/Config/ArenaGeometry.swift", "return candidates.first { p in", "return candidates.first(where: { p in"),
 ("M5 preview steals Boss Mode home", "Sparkforge/Scenes/GameScene.swift", "ArenaConfig.all.count, ArenaConfig.overrideID == nil", "ArenaConfig.all.count"),
 ("M6 ignore island dimensions", "Sparkforge/Config/ArenaGeometry.swift", "width: r * 0.085, height: r * 0.215", "width: r * 0.005, height: r * 0.215"),
 ("M7 never resume direct pursuit", "Sparkforge/Scenes/GameScene.swift", "enemy.routePrevNodeID = enemy.routeNodeID\n                enemy.routeNodeID = nil", "enemy.routePrevNodeID = enemy.routeNodeID\n                enemy.routeNodeID = 4"),
]
results=[]
for name, path, before, after in controls:
 with tempfile.TemporaryDirectory(prefix="sf-a7-control-") as directory:
  clone=Path(directory)
  for file in files:
   dest=clone/file; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(root/file,dest)
  target=clone/path; text=target.read_text(); assert text.count(before)==1,(name,text.count(before))
  text=text.replace(before,after)
  if name.startswith("M4"):
   text=text.replace("crossingClearance + actorRadius }\n        }", "crossingClearance + actorRadius }\n        }) ?? candidates.first")
  target.write_text(text)
  try:
   run=subprocess.run(["sh", str(clone/"tools/arena7-harness/run.sh")],capture_output=True,text=True,timeout=180)
   outcome="KILLED" if run.returncode==1 and "FAIL A" in run.stdout and "error:" not in run.stderr else "SURVIVED" if run.returncode==0 else "INVALID"
   result={"name":name,"outcome":outcome,"exit":run.returncode,"failures":[l for l in run.stdout.splitlines() if l.startswith("FAIL")],"stderr":run.stderr[-1000:]}
  except subprocess.TimeoutExpired:
   result={"name":name,"outcome":"TIMEOUT"}
  results.append(result); print(json.dumps(result),flush=True)
print(json.dumps({"killed":sum(r["outcome"]=="KILLED" for r in results),"total":len(results)}))
raise SystemExit(0 if all(r["outcome"]=="KILLED" for r in results) else 1)
