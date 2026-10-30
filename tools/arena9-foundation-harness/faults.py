#!/usr/bin/env python3
"""Compile-valid behavioral controls against the same real-source assertions."""
from pathlib import Path
import json
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source_paths = ["Sparkforge/Config/Arena9StageDefinition.swift",
                "Sparkforge/Systems/Arena9StageBounds.swift",
                "Sparkforge/Systems/Arena9EncounterLedger.swift",
                "tools/arena9-foundation-harness/main.swift"]
faults = [
    ("negative-size", 0, "world.size.width > 0, world.size.height > 0", "world.width > 0, world.height > 0"),
    ("body-clearance", 1, "bodyRadius <= world.height / 2", "bodyRadius <= world.height"),
    ("camera-edge", 1, "high - size / 2, max(low + size / 2, value)", "high, max(low, value)"),
    ("visibility", 1, "proposed.intersection(definition.world)", "proposed"),
    ("one-time-activation", 2, "activated.insert(id).inserted", "true"),
    ("stale-callback", 2, "generation = UUID()\n        activated.removeAll()", "// no generation renewal\n        activated.removeAll()"),
]
results = []
for name, target, old, new in faults:
    with tempfile.TemporaryDirectory(prefix="sf-a9-fault-") as temporary:
        build = Path(temporary)
        files = []
        for index, relative in enumerate(source_paths):
            text = (root / relative).read_text()
            if index == target:
                assert text.count(old) == 1, (name, "mutation no longer precise")
                text = text.replace(old, new)
            file = build / Path(relative).name
            file.write_text(text)
            files.append(str(file))
        compiled = subprocess.run(["swiftc", "-DDEBUG", "-O", "-module-cache-path", str(build / "cache"),
                                   *files, "-o", str(build / "proof")], capture_output=True, text=True)
        assert compiled.returncode == 0, (name, "compiler failure is not a detected fault", compiled.stderr)
        run = subprocess.run([str(build / "proof")], capture_output=True, text=True)
        detected = run.returncode == 1 and "FAIL " in run.stdout and " FAIL" in run.stdout
        results.append({"fault": name, "compiled": True, "detected_by_behavior": detected,
                        "exit": run.returncode, "summary": run.stdout.splitlines()[-1] if run.stdout else ""})
        assert detected, (name, run.stdout, run.stderr)
print(json.dumps(results, indent=2))
