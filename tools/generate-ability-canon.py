#!/usr/bin/env python3
"""Sparkforge ability canon generator (v2.1 A7a, closure table CL-104).

Writes `docs/v2.1-ability-canon.md`, the canonical ability-design packet Lyra
asked for in `docs/arena6-geometry-reconciliation.md` §8. It joins two sources:

  * the COMPILED catalog — every card's id, name, tags, role, tiers, exact
    player copy and eligibility edges, plus the synergy ladders — dumped by
    the catalog harness (`sh tools/catalog-harness/run.sh --dump <file>`);
  * the HAND-KEPT sidecar `docs/v2.1-ability-canon-sidecar.json` — the
    judgement columns code can't express (travel family, geometry policy,
    targeting, hit class, boss-class treatment, kill source, tell, rulings,
    sensitivities), the tree theses and the cross-cutting rules.

It fails on a sidecar key that is missing or unknown, so a new, renamed or
retired card can't slip past the packet, and it asserts the same expected
counts as the Atlas (`tools/catalog-expect.json`).

Provenance is a SOURCE-INPUT FINGERPRINT, not a Git commit: the SHA-256 of the
inputs the packet is generated from, stamped on generation and recomputed by
`--check`. It needs no Git metadata, and committing the packet (alone, or in
the same commit as the source it came from) doesn't change it.

Usage (from repo root):
    python3 tools/generate-ability-canon.py [output.md]
    python3 tools/generate-ability-canon.py --check <canon.md>   # validate only
    python3 tools/generate-ability-canon.py --fingerprint        # the fingerprint, itemised
"""
import hashlib, json, os, re, subprocess, sys, tempfile, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'docs/v2.1-ability-canon.md')
SIDECAR = os.path.join(ROOT, 'docs/v2.1-ability-canon-sidecar.json')
EXPECT = os.path.join(ROOT, 'tools/catalog-expect.json')
GENERATOR = os.path.abspath(__file__)
FIELDS = ['family', 'geometry', 'targeting', 'hitClass', 'bossClass', 'killSource', 'tell', 'rulings', 'sensitivities']
FAMILIES = ['direct projectile', 'on-hit rider', 'DoT status', 'aura (player-centred)', 'global / positionless',
            'falling / sky-strike', 'void beam', 'ground zone', 'well / rooted object', 'knockback / pull',
            'teleport / pin', 'orbital / familiar', 'summon', 'melee sweep', 'passive stat',
            'damage layer / shield', 'transformation', 'draft rule']
ORDER = ['fire', 'chill', 'shock', 'bleed', 'guardT', 'voidT', 'growth', 'neutral']


def load_catalog():
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, 'catalog.json')
        subprocess.run(['sh', os.path.join(ROOT, 'tools/catalog-harness/run.sh'), '--dump', out],
                       check=True, cwd=ROOT, stdout=subprocess.DEVNULL)
        return json.load(open(out))


# ─── Provenance: the source-input fingerprint (A7a corrective 9) ─────────────
# The packet records WHAT it was generated from, not WHEN in Git history: a
# SHA-256 over its authoritative inputs, each digested on its own —
#   catalog    the compiled catalog, as dumped (canonical JSON: sorted keys, no
#              whitespace, so the host's JSON formatting can't move it)
#   sidecar    docs/v2.1-ability-canon-sidecar.json (canonical JSON)
#   expect     tools/catalog-expect.json (canonical JSON)
#   generator  this file (its bytes)
# — and the fingerprint is the SHA-256 of the lines "<input> <digest>\n" in
# that order (`--fingerprint` prints them, so each can be checked by hand).
# Generation stamps it and `--check` recomputes it from the inputs present, so
# it validates identically before and after a commit, with or without Git
# metadata, and whether the packet is committed alone or together with the
# source it came from (the A7a single closeout commit). It is never unknown:
# every input is read or the run fails. `?`, an empty or truncated value, or a
# commit hash in its place is not a fingerprint and never validates.

FINGERPRINT = re.compile(r'^[0-9a-f]{64}$')


def _provenance_fail(message):
    sys.exit(f'canon provenance failed: {message}')


def _canonical_json(obj):
    return json.dumps(obj, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')


def source_inputs(cat, side):
    """(input, SHA-256 hex) for each authoritative input, in fingerprint order."""
    return [
        ('catalog', hashlib.sha256(_canonical_json(cat)).hexdigest()),
        ('sidecar', hashlib.sha256(_canonical_json(side)).hexdigest()),
        ('expect', hashlib.sha256(_canonical_json(json.load(open(EXPECT)))).hexdigest()),
        ('generator', hashlib.sha256(open(GENERATOR, 'rb').read()).hexdigest()),
    ]


def source_fingerprint(cat, side):
    """The packet's source-input fingerprint (what `build()` stamps and `--check` requires)."""
    manifest = ''.join(f'{name} {digest}\n' for name, digest in source_inputs(cat, side))
    return hashlib.sha256(manifest.encode()).hexdigest()


def _require(ok, message):
    """An INPUT validation failure: a message and a non-zero exit, never a bare
    `assert` (which `python -O` would skip, and which exits via a traceback)."""
    if not ok:
        sys.exit(f'canon input failed validation: {message}')


def validate(cat, side):
    cards = cat['cards']
    live = [c for c in cards if not c['isSecret']]
    expect = {k: v for k, v in json.load(open(EXPECT)).items() if k != '_about'}
    got = {'total': len(cards), 'draftable': len(live), 'secret': len(cards) - len(live),
           'signatures': sum(c['isSignature'] for c in cards), 'capstones': sum(c['isCapstone'] for c in cards),
           'byTree': {t: sum(1 for c in live if c['tagKey'] == t) for t in expect['byTree']}}
    _require(got == expect, f'catalog drifted from the expected counts:\n  got      {got}\n  expected {expect}')
    names = {t['key']: t['name'] for t in cat['tags']}
    want = {c['id'] for c in cards} | {f'syn:{names[k]}_{s["threshold"]}' for k, v in cat['synergies'].items() for s in v}
    have = set(side['entries'])
    missing, unknown = sorted(want - have), sorted(have - want)
    _require(not missing and not unknown, f'sidecar out of step with the catalog:\n  missing {missing}\n  unknown {unknown}')
    for k, e in side['entries'].items():
        _require(list(e) == FIELDS or set(e) == set(FIELDS), f'{k}: fields {sorted(e)}')
        bad = [f for f in e['family'] if f not in FAMILIES]
        _require(not bad, f'{k}: unknown family {bad}')
    for n in names.values():
        _require(n in side['trees'], f'no thesis for {n}')
    # A7a corrective 5 (F4a): every synergy entry carries every text field the
    # canon prints for it, sensitivities included (rulings may truthfully be
    # empty: Chill ×3 Frostbite has no numbered ruling).
    for k, e in side['entries'].items():
        if k.startswith('syn:'):
            empty = [f for f in FIELDS if f not in ('rulings',) and not (e[f] if isinstance(e[f], list) else e[f].strip())]
            _require(not empty, f'{k}: required synergy fields are empty: {empty}')
    # (F4b) the cross-cutting rules: at least one subsection, none empty, no
    # repeated subsection titles, no rule item listed twice.
    cc = side.get('crosscutting') or []
    _require(cc, 'sidecar has no cross-cutting rules')
    titles = [sec['title'] for sec in cc]
    _require(len(set(titles)) == len(titles), f'duplicate cross-cutting subsections: {titles}')
    for sec in cc:
        _require(sec['body'], f'cross-cutting subsection "{sec["title"]}" is empty')
    items = [b for sec in cc for b in sec['body']]
    _require(len(set(items)) == len(items), 'a cross-cutting rule item is listed twice')


def md(s):
    return (s or '').replace('|', '\\|').replace('\n', ' ')


def card_block(c, e, names):
    role = []
    if c['isSignature']: role.append('★ signature')
    if c['isCapstone']: role.append('👑 capstone')
    if c.get('secondaryTagKey'): role.append(f'bridge → {names[c["secondaryTagKey"]]}')
    if c['isSecret']: role.append('secret')
    head = f'#### {c["name"]} · `{c["id"]}`' + (f' · {", ".join(role)}' if role else '')
    lines = [head, '']
    if c['isSecret']:
        lines.append(f'- **Copy:** masked by design (`???` at every tier). Tier names: {" → ".join(c.get("tierNames", []))}.')
    else:
        # The face (the card before it's owned). A card with tier copy shows its
        # ladder below, so the face gets its own line (A7a corrective 4: nine
        # cards' faces were printed nowhere in the packet).
        if c.get('tierDescriptions'):
            lines.append(f'- **Face:** "{c["description"]}"')
        tiers = c.get('tierDescriptions') or [c['description']]
        if len(tiers) == 1:
            lines.append(f'- **Copy:** "{tiers[0]}"')
        else:
            lines.append('- **Copy:** ' + ' · '.join(f'T{i+1} "{t}"' for i, t in enumerate(tiers)))
        if c.get('detail'):
            lines.append(f'- **MORE detail:** "{c["detail"]}"')
    gates = []
    if c['provides']: gates.append('grants ' + ', '.join(f'`{x}`' for x in c['provides']))
    if c['requires']: gates.append('needs ' + ', '.join(f'`{x}`' for x in c['requires']))
    for t, caps in sorted(c['tierRequires'].items()): gates.append(f'T{t} needs ' + ', '.join(f'`{x}`' for x in caps))
    for t, caps in sorted(c['tierProvides'].items()): gates.append(f'T{t} grants ' + ', '.join(f'`{x}`' for x in caps))
    for t, caps in sorted(c['tierBlockedBy'].items()): gates.append(f'T{t} not offered once the run holds ' + ', '.join(f'`{x}`' for x in caps))
    if c['blockedBy']: gates.append('not offered once the run holds ' + ', '.join(f'`{x}`' for x in c['blockedBy']))
    lines.append(f'- **Tiers:** {c["maxTier"]} · **Gates:** ' + ('; '.join(gates) if gates else 'none (ungated)'))
    lines += sidecar_lines(e)
    return '\n'.join(lines)


def sidecar_lines(e):
    out = [f'- **Family:** {", ".join(e["family"])}',
           f'- **Geometry:** {e["geometry"]}',
           f'- **Targeting:** {e["targeting"]}',
           f'- **Hit class:** {e["hitClass"]}',
           f'- **Boss-class:** {e["bossClass"]}',
           f'- **Kill source:** {e["killSource"]}',
           f'- **Tell:** {e["tell"]}']
    if e['rulings']: out.append(f'- **Rulings:** {", ".join(e["rulings"])}')
    if e['sensitivities']: out.append(f'- **Sensitivities:** {e["sensitivities"]}')
    return out


def build(cat, side):
    fp = source_fingerprint(cat, side)
    names = {t['key']: t['name'] for t in cat['tags']}
    cards = cat['cards']
    live = [c for c in cards if not c['isSecret']]
    E = side['entries']
    o = []
    o.append('# Sparkforge v2.1 — Ability Canon (Lyra\'s §8 packet)\n')
    o.append('> **PROVISIONAL until A7b closes.** A7b may change behaviour or copy; its close re-runs this generator and reviews the sidecar (closure table CL-104).\n')
    o.append(f'*Generated by `tools/generate-ability-canon.py` ({datetime.date.today():%b %d %Y}) from the compiled catalog '
             f'and the hand-kept sidecar `docs/v2.1-ability-canon-sidecar.json`; source-input fingerprint `sha256:{fp}` '
             '(the catalog, the sidecar, `tools/catalog-expect.json` and the generator; `--fingerprint` itemises it). '
             'Do not edit this file by hand: change the card in code, or its entry in the sidecar, and regenerate. '
             'Brief: `docs/arena6-geometry-reconciliation.md` §8. The Sep 15 reconciliation (`docs/v2.1-card-rework-spec.md`) '
             'is frozen as history; its Q-ids stay citable. Rulings: `docs/v2.1-ability-closure-table.md`.*\n')
    o.append(f'**{len(cards)} cards = {len(live)} draftable + {len(cards) - len(live)} secret** · 7 trees + Neutral · '
             f'{sum(c["isSignature"] for c in cards)} signatures · {sum(c["isCapstone"] for c in cards)} capstones · '
             f'{sum(len(v) for v in cat["synergies"].values())} synergy tiers · {len(cat["retired"])} retired ids.\n')
    o.append('## Contents\n')
    o.append('- [Cross-cutting rules](#cross-cutting-rules)')
    for k in ORDER:
        o.append(f'- [{names[k]}](#{names[k].lower()})')
    o.append('- [Secret](#secret)\n- [Index by travel family](#index-by-travel-family)\n- [Retired ids](#retired-ids)\n')

    o.append('## Cross-cutting rules\n')
    for sec in side['crosscutting']:
        o.append(f'### {sec["title"]}\n')
        o += [f'- {b}' for b in sec['body']]
        o.append('')

    for k in ORDER:
        name = names[k]
        group = [c for c in live if c['tagKey'] == k]
        th = side['trees'][name]
        o.append(f'## {name}\n')
        o.append(f'**Thesis:** {th["thesis"]} *({th["source"]})* · **{len(group)} cards.**\n')
        if k in cat['synergies']:
            o.append('**Synergy ladder** (distinct cards in the tree):\n')
            o.append('| × | Name | In-game copy | Family | How it works | Boss-class |')
            o.append('|---|---|---|---|---|---|')
            for s in cat['synergies'][k]:
                e = E[f'syn:{name}_{s["threshold"]}']
                o.append(f'| {s["threshold"]} | {md(s["title"])} | {md(s["effect"])} | {md(", ".join(e["family"]))} | {md(e["hitClass"])} | {md(e["bossClass"])} |')
            o.append('')
            for s in cat['synergies'][k]:
                e = E[f'syn:{name}_{s["threshold"]}']
                extra = [x for x in (f'targeting: {e["targeting"]}', f'geometry: {e["geometry"]}', f'kill source: {e["killSource"]}',
                                     f'tell: {e["tell"]}', ('rulings: ' + ', '.join(e['rulings'])) if e['rulings'] else '',
                                     f'sensitivities: {e["sensitivities"]}' if e['sensitivities'] else '') if x]
                o.append(f'- **×{s["threshold"]} {s["title"]}** — ' + ' · '.join(extra))
            o.append('')
        for c in group:
            o.append(card_block(c, E[c['id']], names))
            o.append('')

    o.append('## Secret\n')
    for c in cards:
        if c['isSecret']:
            o.append(card_block(c, E[c['id']], names))
            o.append('')

    o.append('## Index by travel family\n')
    o.append('*§8 asks for summons, orbitals, projectiles, auras, zones, globals, teleports, pulls and displacement by travel family. '
             'Geometry policy per family: reconciliation §3.*\n')
    index = {f: [] for f in FAMILIES}
    label = {c['id']: c['name'] for c in cards}
    for key, e in E.items():
        nm = label.get(key) or ('×' + key.split('_')[-1] + ' ' + key[4:].split('_')[0] + ' synergy')
        for f in e['family']:
            index[f].append(f'{nm} (`{key}`)')
    for f in FAMILIES:
        if index[f]:
            o.append(f'- **{f}** ({len(index[f])}): ' + ', '.join(sorted(index[f])))
    o.append('')

    o.append('## Retired ids\n')
    o.append('*Shipped in a live build, since removed. Never reuse one of these ids (Codex discovery would carry over). CL-102.*\n')
    o.append('| id | Retired by |')
    o.append('|---|---|')
    for rid, why in sorted(cat['retired'].items()):
        o.append(f'| `{rid}` | {why} |')
    o.append('')
    return '\n'.join(o)


# ═══ The canon's trust boundary (A7a corrective 6) ════════════════════════════
#
# The packet is machine-authored end to end, so it is validated as a MODEL, not
# as "expected records are present":
#   1. `parse_canon` reads the WHOLE rendered document with a strict grammar —
#      every non-blank line must be a record of a known kind, in a known
#      section, or it is reported as unplaceable;
#   2. `expected_model` builds the model the document must equal, independently,
#      from the compiled catalog and the sidecar (never from build()/card_block());
#   3. `validate_output` requires exact equality, and explains every difference:
#      missing, extra, duplicate, wrong owner, wrong identity, conflicting.
#
# SECTION INVENTORY — every semantic content section is STRICT; the generation
# date is intentionally provenance-only and format-validated:
#   preamble ................ title and banner (fixed text); the provenance line
#                              (exact template; its SOURCE-INPUT FINGERPRINT must
#                              equal the one recomputed from the inputs exactly;
#                              its generation DATE is provenance-only and
#                              format-validated);
#                              the summary (exactly one; catalog counts)
#   Contents ................ the exact ordered link list
#   Cross-cutting rules ..... subsections × rule items == the sidecar, each item
#                              exactly once under its own subsection
#   Fire … Neutral .......... exactly one thesis (sidecar + catalog count); the
#                              ladder intro/header/separator (coloured trees); the
#                              ladder rows and synergy entries (catalog + sidecar,
#                              by (tree, threshold) identity); the card blocks, in
#                              pool order, every field line
#   Secret .................. the secret card's block
#   Index by travel family .. the fixed intro line; one row per family that has
#                              members, members == the sidecar's, catalog ids only
#   Retired ids ............. the fixed intro; the table == the retired registry
# The wording of sidecar prose values is authored in the sidecar; here it is
# compared for exact identity with the sidecar, not judged.

SIDECAR_FIELDS = [('geometry', 'Geometry'), ('targeting', 'Targeting'), ('hitClass', 'Hit class'),
                  ('bossClass', 'Boss-class'), ('killSource', 'Kill source'), ('tell', 'Tell')]
TITLE = "# Sparkforge v2.1 — Ability Canon (Lyra's §8 packet)"
BANNER = ('> **PROVISIONAL until A7b closes.** A7b may change behaviour or copy; its close re-runs this generator '
          'and reviews the sidecar (closure table CL-104).')
def provenance_re(fp):
    """The provenance line: the source-input fingerprint EXACTLY; the date by format only."""
    return re.compile(
    r'^\*Generated by `tools/generate-ability-canon\.py` \([A-Z][a-z]{2} \d{2} \d{4}\) from the compiled catalog '
    r'and the hand-kept sidecar `docs/v2\.1-ability-canon-sidecar\.json`; source-input fingerprint `sha256:' + re.escape(fp) + '` '
    + re.escape('(the catalog, the sidecar, `tools/catalog-expect.json` and the generator; `--fingerprint` itemises it). '
                'Do not edit this file by hand: change the card in code, or its entry in the sidecar, and regenerate. '
                'Brief: `docs/arena6-geometry-reconciliation.md` §8. The Sep 15 reconciliation (`docs/v2.1-card-rework-spec.md`) '
                'is frozen as history; its Q-ids stay citable. Rulings: `docs/v2.1-ability-closure-table.md`.') + r'\*$')
LADDER = ['**Synergy ladder** (distinct cards in the tree):',
          '| × | Name | In-game copy | Family | How it works | Boss-class |', '|---|---|---|---|---|---|']
INDEX_INTRO = ('*§8 asks for summons, orbitals, projectiles, auras, zones, globals, teleports, pulls and displacement by '
               'travel family. Geometry policy per family: reconciliation §3.*')
RETIRED_INTRO = '*Shipped in a live build, since removed. Never reuse one of these ids (Codex discovery would carry over). CL-102.*'
RETIRED_HEAD = ['| id | Retired by |', '|---|---|']


def _esc(t):
    return (t or '').replace('|', '\\|').replace('\n', ' ')


def expected_synergy_entry(threshold, s, e):
    """One synergy entry, exactly — from the catalog and the sidecar only."""
    parts = [f'targeting: {e["targeting"]}', f'geometry: {e["geometry"]}', f'kill source: {e["killSource"]}', f'tell: {e["tell"]}']
    if e['rulings']:
        parts.append('rulings: ' + ', '.join(e['rulings']))
    if e['sensitivities']:
        parts.append('sensitivities: ' + e['sensitivities'])
    return f'- **×{threshold} {s["title"]}** — ' + ' · '.join(parts)


def expected_card(c, e, names):
    """(header, field lines) one card's block must be — catalog + sidecar only."""
    role = (['★ signature'] if c['isSignature'] else []) + (['👑 capstone'] if c['isCapstone'] else []) \
        + ([f'bridge → {names[c["secondaryTagKey"]]}'] if c.get('secondaryTagKey') else []) + (['secret'] if c['isSecret'] else [])
    head = f'#### {c["name"]} · `{c["id"]}`' + (f' · {", ".join(role)}' if role else '')
    out = []
    if c['isSecret']:
        out.append(f'- **Copy:** masked by design (`???` at every tier). Tier names: {" → ".join(c.get("tierNames", []))}.')
    else:
        tiers = c.get('tierDescriptions') or []
        if tiers:
            out.append(f'- **Face:** "{c["description"]}"')
        out.append('- **Copy:** ' + (' · '.join(f'T{i + 1} "{t}"' for i, t in enumerate(tiers)) if len(tiers) > 1
                                     else f'"{(tiers or [c["description"]])[0]}"'))
        if c.get('detail'):
            out.append(f'- **MORE detail:** "{c["detail"]}"')

    def caps(v):
        return ', '.join(f'`{x}`' for x in v)
    gates = ([f'grants {caps(c["provides"])}'] if c['provides'] else []) + ([f'needs {caps(c["requires"])}'] if c['requires'] else [])
    for key, verb in (('tierRequires', 'needs'), ('tierProvides', 'grants'), ('tierBlockedBy', 'not offered once the run holds')):
        gates += [f'T{t} {verb} {caps(v)}' for t, v in sorted(c[key].items(), key=lambda kv: int(kv[0]))]
    if c['blockedBy']:
        gates.append(f'not offered once the run holds {caps(c["blockedBy"])}')
    out.append(f'- **Tiers:** {c["maxTier"]} · **Gates:** ' + ('; '.join(gates) if gates else 'none (ungated)'))
    out.append('- **Family:** ' + ', '.join(e['family']))
    out += [f'- **{label}:** {e[key]}' for key, label in SIDECAR_FIELDS]
    if e['rulings']:
        out.append('- **Rulings:** ' + ', '.join(e['rulings']))
    if e['sensitivities']:
        out.append('- **Sensitivities:** ' + e['sensitivities'])
    return head, out


def _index_label(key, cards_by_id):
    c = cards_by_id.get(key)
    return c['name'] if c else '×' + key.rsplit('_', 1)[1] + ' ' + key[4:].rsplit('_', 1)[0] + ' synergy'


def expected_model(cat, side, fp):
    if not FINGERPRINT.match(fp or ''):
        _provenance_fail(f'expected source-input fingerprint {fp!r} is not a SHA-256 fingerprint')
    names = {t['key']: t['name'] for t in cat['tags']}
    E = side['entries']
    cards = cat['cards']
    by_id = {c['id']: c for c in cards}
    live = [c for c in cards if not c['isSecret']]
    summary = (f'**{len(cards)} cards = {len(live)} draftable + {len(cards) - len(live)} secret** · 7 trees + Neutral · '
               f'{sum(c["isSignature"] for c in cards)} signatures · {sum(c["isCapstone"] for c in cards)} capstones · '
               f'{sum(len(v) for v in cat["synergies"].values())} synergy tiers · {len(cat["retired"])} retired ids.')
    trees = {}
    for k in ORDER:
        n = names[k]
        th = side['trees'][n]
        group = [c for c in live if c['tagKey'] == k]
        syn = cat['synergies'].get(k, [])
        trees[n] = {
            'thesis': [f'**Thesis:** {th["thesis"]} *({th["source"]})* · **{len(group)} cards.**'],
            'ladder': LADDER if syn else [],
            'rows': [_ladder_row(n, s, E) for s in syn],
            'entries': [expected_synergy_entry(s['threshold'], s, E[f'syn:{n}_{s["threshold"]}']) for s in syn],
            'cards': [expected_card(c, E[c['id']], names) for c in group],
        }
    index = {}
    for key, e in E.items():
        for fam in e['family']:
            index.setdefault(fam, []).append((_index_label(key, by_id), key))
    return {
        'preamble': [TITLE, BANNER, provenance_re(fp), summary],
        'sections': ['Contents', 'Cross-cutting rules'] + [names[k] for k in ORDER] + ['Secret', 'Index by travel family', 'Retired ids'],
        'contents': ['- [Cross-cutting rules](#cross-cutting-rules)'] + [f'- [{names[k]}](#{names[k].lower()})' for k in ORDER]
                    + ['- [Secret](#secret)', '- [Index by travel family](#index-by-travel-family)', '- [Retired ids](#retired-ids)'],
        'cross': [(sec['title'], list(sec['body'])) for sec in side['crosscutting']],
        'trees': trees,
        'secret': [expected_card(c, E[c['id']], names) for c in cards if c['isSecret']],
        'index': [(fam, sorted(index[fam])) for fam in FAMILIES if fam in index],
        'retired': sorted(cat['retired'].items()),
        'known_ids': set(by_id) | {k for k in E if k.startswith('syn:')},
        'fingerprint': fp,
    }


def _ladder_row(tree, s, E):
    e = E[f'syn:{tree}_{s["threshold"]}']
    return (f'| {s["threshold"]} | {_esc(s["title"])} | {_esc(s["effect"])} | {_esc(", ".join(e["family"]))} '
            f'| {_esc(e["hitClass"])} | {_esc(e["bossClass"])} |')


def parse_canon(md_text):
    """The document → its model. Every non-blank line lands in exactly one
    record of its section; anything else is recorded as unplaceable."""
    m = {'preamble': [], 'sections': [], 'contents': [], 'cross': [], 'cross_orphans': [], 'trees': {},
         'secret': [], 'index_intro': [], 'index': [], 'retired_intro': [], 'retired_head': [], 'retired': [],
         'unplaceable': []}
    section, card, sub = None, None, None
    tree_titles = None

    def bad(line):
        m['unplaceable'].append((section or 'preamble', line))

    for line in md_text.split('\n'):
        if not line.strip():
            continue
        if line.startswith('## '):
            section, card, sub = line[3:].strip(), None, None
            m['sections'].append(section)
            continue
        if section is None:
            m['preamble'].append(line)
        elif section == 'Contents':
            m['contents'].append(line) if re.match(r'^- \[[^\]]+\]\(#[a-z0-9-]+\)$', line) else bad(line)
        elif section == 'Cross-cutting rules':
            if line.startswith('### '):
                sub = (line[4:].strip(), [])
                m['cross'].append(sub)
            elif line.startswith('- '):
                (sub[1].append(line[2:]) if sub else m['cross_orphans'].append(line[2:]))
            else:
                bad(line)
        elif section in ('Secret',) or section in TREE_NAMES:
            bucket = m['secret'] if section == 'Secret' else m['trees'].setdefault(
                section, {'thesis': [], 'ladder': [], 'rows': [], 'entries': [], 'cards': []})
            if line.startswith('#### '):
                card = (line, [])
                (bucket if section == 'Secret' else bucket['cards']).append(card)
            elif card is not None and line.startswith('- **'):
                card[1].append(line)
            elif section == 'Secret':
                bad(line)
            elif line.startswith('**Thesis:** '):
                bucket['thesis'].append(line)
            elif line in LADDER:
                bucket['ladder'].append(line)
            elif re.match(r'^\| [0-9]+ \| ', line):
                bucket['rows'].append(line)
            elif re.match(r'^- \*\*×[0-9]+ ', line):
                bucket['entries'].append(line)
            else:
                bad(line)
        elif section == 'Index by travel family':
            if line == INDEX_INTRO:
                m['index_intro'].append(line)
            else:
                mm = re.match(r'^- \*\*(.+?)\*\* \(([0-9]+)\): (.+)$', line)
                if mm:
                    members = re.findall(r'(.+?) \(`([^`]+)`\)(?:, |$)', mm.group(3))
                    m['index'].append((mm.group(1), int(mm.group(2)), members, line))
                else:
                    bad(line)
        elif section == 'Retired ids':
            if line == RETIRED_INTRO:
                m['retired_intro'].append(line)
            elif line in RETIRED_HEAD:
                m['retired_head'].append(line)
            else:
                mm = re.match(r'^\| `([^`]+)` \| (.+) \|$', line)
                m['retired'].append((mm.group(1), mm.group(2))) if mm else bad(line)
        else:
            bad(line)
    return m


TREE_NAMES = set()   # filled from the catalog before parsing


def _dupes(xs):
    return sorted({x for x in xs if xs.count(x) > 1}, key=xs.index)


def compare_models(exp, act):
    P = []
    # Unplaceable lines: never allowed.
    for sec, line in act['unplaceable']:
        P.append(f'unplaceable line in "{sec}": "{line[:70]}"')
    # Sections.
    if act['sections'] != exp['sections']:
        sec_p = [f'section "## {s}" appears {act["sections"].count(s)} times (expected once)'
                 for s in exp['sections'] if act['sections'].count(s) != 1]
        sec_p += [f'unexpected section "## {s}"' for s in sorted(set(act['sections']) - set(exp['sections']))]
        P += sec_p or [f'sections out of order: {act["sections"]}']
    # Preamble: title, banner, provenance, summary — exactly these four records.
    pre = act['preamble']
    if len(pre) != 4 or pre[0] != exp['preamble'][0] or pre[1] != exp['preamble'][1] \
            or not exp['preamble'][2].match(pre[2] if len(pre) > 2 else '') or (pre[3] if len(pre) > 3 else '') != exp['preamble'][3]:
        summaries = [ln for ln in pre if re.match(r'^\*\*[0-9]+ cards = ', ln)]
        stamped = next((m.group(1) for ln in pre for m in [re.search(r'source-input fingerprint `(?:sha256:)?([^`]*)`', ln)] if m), None)
        P.append(f'preamble must be exactly [title, banner, provenance, summary]; found {len(pre)} records'
                 + (f', {len(summaries)} summary records' if len(summaries) != 1 else '')
                 + ('' if exp['preamble'][3] in pre else '; the summary counts differ from the catalog')
                 + ('' if any(exp['preamble'][2].match(ln) for ln in pre)
                    else f'; the provenance line must carry source-input fingerprint `sha256:{exp["fingerprint"]}` ('
                         + (f'found `{stamped}`' if stamped is not None else 'found none')
                         + (', not a SHA-256 fingerprint, which is never valid' if stamped is not None and not FINGERPRINT.match(stamped) else '')
                         + ') with a generation date in "Mon DD YYYY" form'))
    # Contents.
    if act['contents'] != exp['contents']:
        P.append(f'contents links differ: missing {[c for c in exp["contents"] if c not in act["contents"]]}, '
                 f'extra {[c for c in act["contents"] if c not in exp["contents"]]}, duplicated {_dupes(act["contents"])}')
    # Cross-cutting rules.
    for item in act['cross_orphans']:
        P.append(f'cross-cutting rule item before any subsection: "{item[:60]}"')
    got_titles = [t for t, _ in act['cross']]
    exp_titles = [t for t, _ in exp['cross']]
    for t in exp_titles:
        if got_titles.count(t) != 1:
            P.append(f'cross-cutting subsection "{t}" appears {got_titles.count(t)} times (expected once)')
    for t in sorted(set(got_titles) - set(exp_titles)):
        P.append(f'unexpected cross-cutting subsection "{t}"')
    owner = {item: t for t, items in exp['cross'] for item in items}
    all_items = [item for _, items in act['cross'] for item in items] + act['cross_orphans']
    for item in _dupes(all_items):
        P.append(f'cross-cutting rule item appears {all_items.count(item)} times: "{item[:60]}"')
    for t, items in act['cross']:
        if not items:
            P.append(f'cross-cutting subsection "{t}" is empty')
        for item in items:
            if item not in owner:
                P.append(f'unexpected cross-cutting rule item under "{t}": "{item[:60]}"')
            elif owner[item] != t:
                P.append(f'cross-cutting rule item under "{t}" belongs under "{owner[item]}": "{item[:60]}"')
    for item, t in owner.items():
        if not any(ti == t and item in its for ti, its in act['cross']):
            P.append(f'cross-cutting rule item missing from "{t}": "{item[:60]}"')
    if not P and act['cross'] != exp['cross']:
        P.append('cross-cutting rules are out of order')
    # Trees.
    for tree, e in exp['trees'].items():
        a = act['trees'].get(tree, {'thesis': [], 'ladder': [], 'rows': [], 'entries': [], 'cards': []})
        if a['thesis'] != e['thesis']:
            P.append(f'"{tree}": {len(a["thesis"])} thesis records (expected exactly one, equal to the sidecar)'
                     + ('' if e['thesis'][0] in a['thesis'] else '; the expected thesis is missing'))
        if a['ladder'] != e['ladder']:
            P.append(f'"{tree}": synergy ladder intro/header/separator differ')
        P += _compare_synergy_lines(tree, 'ladder row', e['rows'], a['rows'], r'^\| ([0-9]+) \| ')
        P += _compare_synergy_lines(tree, 'synergy entry', e['entries'], a['entries'], r'^- \*\*×([0-9]+) ')
        P += _compare_cards(f'"{tree}"', e['cards'], a['cards'])
    P += _compare_cards('"Secret"', exp['secret'], act['secret'])
    # Index by travel family.
    if act['index_intro'] != [INDEX_INTRO]:
        P.append(f'index intro appears {len(act["index_intro"])} times (expected once)')
    fams = [f for f, _, _, _ in act['index']]
    exp_index = dict(exp['index'])
    for f in _dupes(fams):
        P.append(f'travel-family row "{f}" appears {fams.count(f)} times')
    for f in sorted(set(fams) - set(exp_index)):
        P.append(f'unexpected travel-family row "{f}"')
    for f in exp_index:
        if f not in fams:
            P.append(f'travel-family row "{f}" is missing')
    for f, count, members, _ in act['index']:
        ids = [k for _, k in members]
        unknown = sorted(set(ids) - exp['known_ids'])
        if unknown:
            P.append(f'travel-family row "{f}" names unknown ids {unknown}')
        if count != len(members):
            P.append(f'travel-family row "{f}" says ({count}) but lists {len(members)}')
        if f in exp_index and sorted(members) != exp_index[f]:
            want, got = set(exp_index[f]), set(members)
            P.append(f'travel-family row "{f}" members differ: missing {sorted(k for _, k in want - got)}, '
                     f'extra {sorted(k for _, k in got - want)}, duplicated {_dupes(ids)}')
    if not P and [f for f, _, _, _ in act['index']] != [f for f, _ in exp['index']]:
        P.append('travel-family rows are out of order')
    # Retired ids.
    if act['retired_intro'] != [RETIRED_INTRO] or act['retired_head'] != RETIRED_HEAD:
        P.append('retired-ids intro/table header differ')
    if act['retired'] != exp['retired']:
        got_ids = [i for i, _ in act['retired']]
        P.append(f'retired ids differ from the registry: missing {sorted(set(dict(exp["retired"])) - set(got_ids))}, '
                 f'extra {sorted(set(got_ids) - set(dict(exp["retired"])))}, duplicated {_dupes(got_ids)}')
    return P


def _compare_synergy_lines(tree, kind, want, got, pattern):
    P = []
    def ident(line):
        mm = re.match(pattern, line)
        return int(mm.group(1)) if mm else None
    wi, gi = [ident(x) for x in want], [ident(x) for x in got]
    for t in wi:
        if gi.count(t) != 1:
            P.append(f'{kind} {tree} ×{t} appears {gi.count(t)} times (expected once)')
    for t in sorted({t for t in gi if t not in wi}, key=str):
        P.append(f'unexpected {kind} {tree} ×{t}')
    for line in got:
        t = ident(line)
        if t in wi and gi.count(t) == 1 and line != want[wi.index(t)]:
            if kind == 'synergy entry':
                g = dict(p.split(': ', 1) for p in line.split(' — ', 1)[-1].split(' · ') if ': ' in p)
                w = dict(p.split(': ', 1) for p in want[wi.index(t)].split(' — ', 1)[-1].split(' · ') if ': ' in p)
                diff = sorted(k for k in set(g) | set(w) if g.get(k) != w.get(k)) or ['title/format']
                P.append(f'synergy entry {tree} ×{t} differs from its sidecar entry in {diff}')
            else:
                P.append(f'{kind} {tree} ×{t} content differs from the catalog/sidecar')
    if not P and got != want:
        P.append(f'{kind}s in "{tree}" are out of order')
    return P


def _compare_cards(where, want, got):
    P = []
    def cid(head):
        mm = re.match(r'^#### .*? · `([a-z0-9_]+)`', head)
        return mm.group(1) if mm else '?'
    wid, gid = [cid(h) for h, _ in want], [cid(h) for h, _ in got]
    for i in wid:
        if gid.count(i) != 1:
            P.append(f'{where}: card {i} appears {gid.count(i)} times (expected once)')
    for i in sorted(set(gid) - set(wid)):
        P.append(f'{where}: unexpected card {i}')
    for head, lines in got:
        i = cid(head)
        if i in wid and gid.count(i) == 1:
            w_head, w_lines = want[wid.index(i)]
            if head != w_head:
                P.append(f'{where}: card {i} header differs (name/role)')
            if lines != w_lines:
                def label(x):
                    return x.split(':**', 1)[0][4:] if x.startswith('- **') else '?'
                missing = [label(x) for x in w_lines if x not in lines]
                extra = [label(x) for x in lines if x not in w_lines]
                dup = [label(x) for x in _dupes(lines)]
                P.append(f'{where}: card {i} fields differ — missing/altered {missing}, extra {extra}, duplicated {dup}'
                         if (missing or extra or dup) else f'{where}: card {i} fields are out of order')
    if not P and gid != wid:
        P.append(f'{where}: cards are out of order')
    return P


def validate_output(md_text, cat, side, fp):
    """A7a corrective 6: the rendered canon's parsed model must EQUAL the model
    built from the catalog and the sidecar (and `fp`, the source-input
    fingerprint recomputed from the inputs). Exits non-zero, listing why."""
    TREE_NAMES.clear()
    TREE_NAMES.update(t['name'] for t in cat['tags'])
    problems = compare_models(expected_model(cat, side, fp), parse_canon(md_text))
    if problems:
        sys.exit('canon output failed validation:\n  ' + '\n  '.join(problems[:40])
                 + (f'\n  … and {len(problems) - 40} more' if len(problems) > 40 else ''))


if __name__ == '__main__':
    cat = load_catalog()
    side = json.load(open(SIDECAR))
    validate(cat, side)
    if len(sys.argv) > 1 and sys.argv[1] == '--fingerprint':
        for name, digest in source_inputs(cat, side):
            print(f'{name} {digest}')
        print(f'fingerprint sha256:{source_fingerprint(cat, side)}   (= SHA-256 of the lines above)')
        sys.exit(0)
    if len(sys.argv) > 2 and sys.argv[1] == '--check':
        # Validate an existing packet against the catalog without writing anything.
        validate_output(open(sys.argv[2]).read(), cat, side, source_fingerprint(cat, side))
        print(f'{sys.argv[2]}: valid ({len(cat["cards"])} cards, {sum(len(v) for v in cat["synergies"].values())} synergy tiers)')
        sys.exit(0)
    text = build(cat, side)
    validate_output(text, cat, side, source_fingerprint(cat, side))
    open(OUT, 'w').write(text)
    print(f'{OUT}: {len(cat["cards"])} cards, {len(side["entries"])} sidecar entries')
