#!/usr/bin/env python3
"""The generators' reader sees exactly what the game loads (v2.2 J3-a).

Runs the catalog harness's `--dump` (the compiled, catalog-backed
`UpgradeManager` pool, Swift tree keys) and compares it, key for key and in
order, with `catalog_reader.load()` on the authored file (portable keys). The
only expected difference is the key spelling of the two trees whose Swift case
names differ (`guardT`/`voidT` ↔ `guard`/`void`).

Usage (repo root):  python3 tools/v2.2-catalog/check-reader-parity.py   # exit 0 = identical
"""
import json, os, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import catalog_reader

ROOT = catalog_reader.ROOT
SWIFT_KEY = {'guard': 'guardT', 'void': 'voidT'}


def main():
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, 'dump.json')
        subprocess.run(['sh', os.path.join(ROOT, 'tools/catalog-harness/run.sh'), '--dump', out], check=True, cwd=ROOT, stdout=subprocess.DEVNULL)
        dump = json.load(open(out))
    reader = catalog_reader.load()
    # Translate the reader's portable keys to the dump's Swift keys, then compare.
    cards = []
    for c in reader['cards']:
        c = dict(c)
        c['tagKey'] = SWIFT_KEY.get(c['tagKey'], c['tagKey'])
        if 'secondaryTagKey' in c:
            c['secondaryTagKey'] = SWIFT_KEY.get(c['secondaryTagKey'], c['secondaryTagKey'])
        cards.append(c)
    view = {'cards': cards,
            'synergies': {SWIFT_KEY.get(k, k): v for k, v in reader['synergies'].items()},
            'retired': reader['retired'],
            'tags': [{'key': SWIFT_KEY.get(t['key'], t['key']), 'name': t['name']} for t in reader['tags']],
            'panda': reader['panda']}
    problems = []
    if [c['id'] for c in view['cards']] != [c['id'] for c in dump['cards']]:
        problems.append('card order differs')
    for a, b in zip(view['cards'], dump['cards']):
        for k in sorted(set(a) | set(b)):
            if a.get(k) != b.get(k):
                problems.append(f'{a["id"]}.{k}: reader {a.get(k)!r} ≠ game {b.get(k)!r}')
    for k in ('synergies', 'retired', 'tags', 'panda'):
        if view[k] != dump[k]:
            problems.append(f'{k} differ')
    if problems:
        print('FAIL  reader-parity: the reader and the game disagree:')
        for p in problems[:20]:
            print('  ' + p)
        return 1
    print(f'PASS  reader-parity: the generators\' reader equals the game\'s pool ({len(cards)} cards, {sum(len(v) for v in view["synergies"].values())} synergy tiers)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
