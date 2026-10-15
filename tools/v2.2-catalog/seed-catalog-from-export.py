#!/usr/bin/env python3
"""v2.2 J1 — seed the authored ability catalog from the J0 export. ONE-OFF.

Reads   tools/v2.2-catalog/baseline/compiled-catalog-export.json
Writes  Sparkforge/Catalog/ability-catalog.json  (schema version 1)

It was run once, in J1, to create the authored file from the compiled Swift
catalog. From then on the JSON is edited by hand and this script must not be
run again: it would overwrite the authored file with the v2.1 snapshot. It
refuses to overwrite unless `--force` is given, and stays in the repository
as the record of how the first version was derived.

Usage (repo root):  python3 tools/v2.2-catalog/seed-catalog-from-export.py [--force]
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, 'tools/v2.2-catalog/baseline/compiled-catalog-export.json')
OUT = os.path.join(ROOT, 'Sparkforge/Catalog/ability-catalog.json')

# Portable tree keys ← Swift case names.
TREE_KEY = {'fire': 'fire', 'shock': 'shock', 'bleed': 'bleed', 'guardT': 'guard',
            'voidT': 'void', 'chill': 'chill', 'growth': 'growth', 'neutral': 'neutral'}
# `UpgradeManager.Capability`, in declaration order.
CAPABILITIES = ['growthUnlocked', 'fireUnlocked', 'chillUnlocked', 'shockUnlocked', 'bleedUnlocked',
                'guardUnlocked', 'voidUnlocked', 'glacialDrift', 'whiteout', 'voidWell', 'critSource',
                'polarVortex', 'glacialCondensation', 'pelletEffect']
# `UpgradeManager.retiredCardIDs`, in source order.
RETIRED_ORDER = ['v13_static_field', 'v16_arc_wake', 'v16_live_wire', 'v17_induction_step',
                 'v17_copper_vein', 'v18_needlepoint', 'v16_blood_price', 'v16_mass_tax']


def card(c):
    out = {'id': c['id'], 'name': c['name'], 'tree': TREE_KEY[c['tagKey']]}
    if 'secondaryTagKey' in c:
        out['secondaryTree'] = TREE_KEY[c['secondaryTagKey']]
    for flag, key in (('isSignature', 'signature'), ('isCapstone', 'capstone'), ('isSecret', 'secret')):
        if c[flag]:
            out[key] = True
    out['face'] = c['description']
    if 'detail' in c:
        out['detail'] = c['detail']
    for key in ('provides', 'requires', 'blockedBy'):
        if c[key]:
            out[key] = sorted(c[key], key=CAPABILITIES.index)
    faces, names = c.get('tierDescriptions'), c.get('tierNames')
    if faces is None:
        assert c['maxTier'] == 1 and names is None, c['id']
    else:
        assert len(faces) == c['maxTier'] and c['maxTier'] > 1, c['id']
        assert names is None or len(names) == c['maxTier'], c['id']
        tiers = []
        for i, face in enumerate(faces):
            t = {}
            if names is not None:
                t['name'] = names[i]
            t['face'] = face
            for src, key in (('tierRequires', 'requires'), ('tierProvides', 'provides'), ('tierBlockedBy', 'blockedBy')):
                caps = c[src].get(str(i + 1))
                if caps:
                    assert i > 0, c['id']
                    t[key] = sorted(caps, key=CAPABILITIES.index)
            tiers.append(t)
        out['tiers'] = tiers
    for src in ('tierRequires', 'tierProvides', 'tierBlockedBy'):
        assert all(1 < int(k) <= c['maxTier'] for k in c[src]), c['id']
    out['behavior'] = c['id']
    return out


def main():
    if os.path.exists(OUT) and '--force' not in sys.argv:
        sys.exit(f'{OUT} exists. It is hand-authored now; this script only made its first version. '
                 'Pass --force to overwrite it with the v2.1 snapshot.')
    src = json.load(open(SRC))
    used = {x for c in src['cards'] for k in ('provides', 'requires', 'blockedBy') for x in c[k]}
    used |= {x for c in src['cards'] for k in ('tierRequires', 'tierProvides', 'tierBlockedBy') for v in c[k].values() for x in v}
    assert used <= set(CAPABILITIES), used - set(CAPABILITIES)
    assert set(src['retired']) == set(RETIRED_ORDER)
    doc = {
        'schema': 'sparkforge.ability-catalog',
        'schemaVersion': 1,
        'trees': [{'key': TREE_KEY[t['key']], 'name': t['name']} for t in src['tags']],
        'capabilities': CAPABILITIES,
        'cards': [card(c) for c in src['cards']],
        'synergies': [{'tree': TREE_KEY[t['key']], 'threshold': s['threshold'], 'title': s['title'], 'effect': s['effect'],
                       'behavior': f"{TREE_KEY[t['key']]}.{s['threshold']}"}
                      for t in src['tags'] for s in src['synergies'].get(t['key'], [])],
        'retired': [{'id': i, 'note': src['retired'][i]} for i in RETIRED_ORDER],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w') as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print(f"{OUT}: {len(doc['cards'])} cards, {len(doc['synergies'])} synergy tiers, {len(doc['retired'])} retired ids")


if __name__ == '__main__':
    main()
