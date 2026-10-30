from pathlib import Path
import json, os, subprocess, tempfile

root = Path(__file__).resolve().parents[2]
source = (root / 'Sparkforge/Prototypes/Arena8GameMap.swift').read_text()
faults = [
    ('old-room-size', 'width: C.roomSide, height: C.roomSide',
     'width: C.roomSide / 1.5, height: C.roomSide / 1.5', 'FAIL each room is540square'),
    ('widened-doorways', 'C.doorwayWidth', '(C.doorwayWidth * 1.5)',
     'FAIL unchanged120passages and scaled gaps'),
    ('missing-loop-connection', '(0, 3), (1, 4), (2, 5)', '(0, 3), (2, 5)',
     'FAIL same exact graph and two loops'),
]
results = []
for name, before, after, oracle in faults:
    assert before in source, name
    with tempfile.TemporaryDirectory(prefix='sf-room-size-fault-') as temporary:
        path = Path(temporary) / 'Arena8GameMap.swift'
        path.write_text(source.replace(before, after))
        env = dict(os.environ, SPARKFORGE_A8_SIX_MAP_PATH=str(path))
        result = subprocess.run(['sh', 'tools/arena8-six-harness/run.sh'], cwd=root,
                                env=env, capture_output=True, text=True)
        output = result.stdout + result.stderr
        caught = result.returncode == 1 and oracle in output and 'RESULT ' in output
        results.append({'fault': name, 'exit': result.returncode,
                        'named_behavior_failure': oracle, 'caught': caught})
        assert caught, output
with tempfile.TemporaryDirectory(prefix='sf-room-los-fault-') as temporary:
    original = (root / 'Sparkforge/Scenes/GameScene.swift').read_text()
    before = 'return !rooms.geometry.segmentBlockedExact(origin, target,'
    assert original.count(before) == 1
    path = Path(temporary) / 'GameScene.swift'
    path.write_text(original.replace(before, 'return !rooms.geometry.segmentBlocked(origin, target,'))
    env = dict(os.environ, SPARKFORGE_A8_ROOM_LOS_SCENE_PATH=str(path))
    result = subprocess.run(['python3', 'tools/arena8-room-size-harness/los.py'], cwd=root,
                            env=env, capture_output=True, text=True)
    output = result.stdout + result.stderr
    caught = result.returncode == 1 and 'FAIL actual selector scope' in output and 'RESULT ' in output
    results.append({'fault':'sampled-room-corner-LoS','exit':result.returncode,'caught':caught,
                    'named_behavior_failure':'FAIL actual selector scope'})
    assert caught, output
print(json.dumps(results, indent=2))
