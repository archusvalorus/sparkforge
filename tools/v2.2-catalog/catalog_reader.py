#!/usr/bin/env python3
"""The authored ability catalog, read for the generators (v2.2 J3-a).

`load(path)` reads `Sparkforge/Catalog/ability-catalog.json` — the file the
game itself loads (`AbilityCatalog.swift`) — and returns the card data in the
shape the canon and Atlas generators consume. Until J3 they read a dump of the
compiled Swift pool; this reader replaces that compile. It is a READER: it
refuses a malformed file (repeated keys, wrong schema, unknown tree) but it is
not the loader — the game's validation lives in Swift and is proven by the
catalog harness (`tools/catalog-harness`, JL/JS0).

Keys are the file's PORTABLE tree keys (`guard`, `void`, …), which
`tools/catalog-expect.json` and both generators use since J3.

The Panda scheduler's numbers (its eligibility chance and first-offer window)
are tuning, not catalog: they are read from `GameConfig.swift` for the Atlas's
secret section, and are not part of the canon's fingerprint.
"""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CATALOG = os.path.join(ROOT, 'Sparkforge/Catalog/ability-catalog.json')
GAME_CONFIG = os.path.join(ROOT, 'Sparkforge/Config/GameConfig.swift')
SCHEMA, SCHEMA_VERSION = 'sparkforge.ability-catalog', 1


class CatalogReadError(SystemExit):
    def __init__(self, message):
        super().__init__(f'catalog reader: {message}')


def parse(path=CATALOG):
    """The authored document, parsed; a repeated key anywhere is an error."""
    repeated = []

    def hook(pairs):
        seen = set()
        for k, _ in pairs:
            if k in seen:
                repeated.append(k)
            seen.add(k)
        return dict(pairs)

    try:
        doc = json.load(open(path, encoding='utf-8'), object_pairs_hook=hook)
    except (OSError, ValueError) as e:
        raise CatalogReadError(f'{path}: {e}')
    if repeated:
        raise CatalogReadError(f'{path}: repeated key(s) {sorted(set(repeated))}')
    if not isinstance(doc, dict) or doc.get('schema') != SCHEMA or doc.get('schemaVersion') != SCHEMA_VERSION:
        raise CatalogReadError(f'{path}: not {SCHEMA} version {SCHEMA_VERSION}')
    for key in ('trees', 'capabilities', 'cards', 'synergies', 'retired'):
        if not isinstance(doc.get(key), list):
            raise CatalogReadError(f'{path}: missing list `{key}`')
    return doc


def panda_config(path=GAME_CONFIG):
    """`GameConfig.Panda.eligibilityChance` and `firstOfferWindow`, read from the source text."""
    text = open(path, encoding='utf-8').read()
    chance = re.search(r'static let eligibilityChance: CGFloat = ([0-9.]+)', text)
    window = re.search(r'static let firstOfferWindow: ClosedRange<Int> = (\d+)\.\.\.(\d+)', text)
    if not chance or not window:
        raise CatalogReadError(f'{path}: GameConfig.Panda.eligibilityChance / firstOfferWindow not found')
    return {'chance': float(chance.group(1)), 'window': [int(window.group(1)), int(window.group(2))]}


def load(path=CATALOG, config=GAME_CONFIG):
    """The generators' view: cards in file order, synergies per tree, retired ids, trees, panda."""
    doc = parse(path)
    trees = {t['key']: t['name'] for t in doc['trees']}
    cards = []
    for c in doc['cards']:
        if c['tree'] not in trees or ('secondaryTree' in c and c['secondaryTree'] not in trees):
            raise CatalogReadError(f'card {c.get("id")}: unknown tree')
        tiers = c.get('tiers')
        tier_caps = lambda key: {str(i + 1): sorted(t[key]) for i, t in enumerate(tiers or []) if t.get(key)}
        entry = {
            'id': c['id'], 'name': c['name'],
            'tag': trees[c['tree']], 'tagKey': c['tree'],
            'isSignature': bool(c.get('signature')), 'isCapstone': bool(c.get('capstone')), 'isSecret': bool(c.get('secret')),
            'maxTier': len(tiers) if tiers else 1,
            'description': c['face'],
            'provides': sorted(c.get('provides', [])), 'requires': sorted(c.get('requires', [])), 'blockedBy': sorted(c.get('blockedBy', [])),
            'tierRequires': tier_caps('requires'), 'tierProvides': tier_caps('provides'), 'tierBlockedBy': tier_caps('blockedBy'),
        }
        if 'secondaryTree' in c:
            entry['secondaryTag'] = trees[c['secondaryTree']]
            entry['secondaryTagKey'] = c['secondaryTree']
        if tiers:
            entry['tierDescriptions'] = [t['face'] for t in tiers]
            if all('name' in t for t in tiers):
                entry['tierNames'] = [t['name'] for t in tiers]
        if 'detail' in c:
            entry['detail'] = c['detail']
        cards.append(entry)
    synergies = {}
    for s in doc['synergies']:
        synergies.setdefault(s['tree'], []).append({'threshold': s['threshold'], 'title': s['title'], 'effect': s['effect']})
    for key in trees:
        if key != 'neutral':
            synergies.setdefault(key, [])
    return {
        'cards': cards,
        'synergies': synergies,
        'retired': {r['id']: r['note'] for r in doc['retired']},
        'tags': [{'key': t['key'], 'name': t['name']} for t in doc['trees']],
        'panda': panda_config(config),
    }


def canonical_bytes(path=CATALOG):
    """The authored document as canonical JSON (sorted keys, no whitespace): the canon's `catalog` input."""
    return json.dumps(parse(path), sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')


if __name__ == '__main__':
    import sys
    cat = load(sys.argv[1] if len(sys.argv) > 1 else CATALOG)
    print(f'{len(cat["cards"])} cards, {sum(len(v) for v in cat["synergies"].values())} synergy tiers, {len(cat["retired"])} retired ids')
