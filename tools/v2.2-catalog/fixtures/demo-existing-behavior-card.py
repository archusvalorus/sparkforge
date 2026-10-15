#!/usr/bin/env python3
"""v2.2 J3-c — adding a card that uses an EXISTING behaviour, in isolation.

Builds a copy of the authored catalog with the demonstration card from
`existing-behavior-card.json` inserted, points the catalog harness at the
copy (SPARKFORGE_CATALOG_PATH) and dumps the game's pool from it: the new
card is there, bound to `neutral_1`'s effect, with no Swift change. Then the
same card with a behaviour key nothing registers: the loader refuses the
whole file at the startup gate (JS0) and names the key. The live catalog is
never touched; everything happens in a temporary directory.

Usage (repo root):  python3 tools/v2.2-catalog/fixtures/demo-existing-behavior-card.py   # exit 0 = both outcomes as described
"""
import json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(ROOT, 'tools/v2.2-catalog'))
import catalog_reader

spec = json.load(open(os.path.join(HERE, 'existing-behavior-card.json')))
live = catalog_reader.parse()


def with_card(card):
    doc = json.loads(json.dumps(live))
    ids = [c['id'] for c in doc['cards']]
    assert card['id'] not in ids and card['id'] not in {r['id'] for r in doc['retired']}
    doc['cards'].insert(ids.index(spec['insertAfter']) + 1, card)
    return doc


def dump(doc, tmp, label):
    path = os.path.join(tmp, f'{label}.json')
    json.dump(doc, open(path, 'w'), indent=2, ensure_ascii=False)
    out = os.path.join(tmp, f'{label}-dump.json')
    r = subprocess.run(['sh', os.path.join(ROOT, 'tools/catalog-harness/run.sh'), '--dump', out],
                       env=dict(os.environ, SPARKFORGE_CATALOG_PATH=path), capture_output=True, text=True, cwd=ROOT, timeout=600)
    return r, (json.load(open(out)) if os.path.exists(out) else None)


def main():
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        r, pool = dump(with_card(spec['card']), tmp, 'added')
        ids = [c['id'] for c in pool['cards']] if pool else []
        added = r.returncode == 0 and pool is not None and len(ids) == len(live['cards']) + 1 and ids[ids.index(spec['insertAfter']) + 1] == spec['card']['id']
        print(('PASS' if added else 'FAIL') + f'  DEMO1 a card bound to an existing behaviour loads: {len(ids)} cards, `{spec["card"]["id"]}` after `{spec["insertAfter"]}`, no Swift change')
        ok &= added
        broken = dict(spec['card'], behavior=spec['brokenBehavior'])
        r, pool = dump(with_card(broken), tmp, 'broken')
        refused = r.returncode != 0 and pool is None and 'JS0' in r.stdout and 'missingBehavior' in r.stdout
        print(('PASS' if refused else 'FAIL') + f'  DEMO2 the same card with an unregistered behaviour is refused whole at the startup gate: {[l for l in r.stdout.splitlines() if "JS0" in l][:1]}')
        ok &= refused
    print('the live catalog was not touched')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
