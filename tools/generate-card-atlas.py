#!/usr/bin/env python3
"""Sparkforge Card Atlas generator (v2.1, Aug 2026; data path rebuilt in A7a, Sep 2026).

Renders the studio's standing visual aid for the card/ability roster
(Brandon's call, Aug 10 2026) as one self-contained HTML page. Publish the
output as the existing "Sparkforge Card Atlas" artifact so the URL stays
stable.

v2.1 A7a (CL-103): the card data no longer comes from regexes over the Swift
source (a comment above a card could supply or flip its fields). The catalog
harness compiles the REAL UpgradeManager and dumps `allCards` and the synergy
ladders as JSON (`sh tools/catalog-harness/run.sh --dump <file>`); this script
only renders that, and asserts the exact expected counts first.

Usage (from repo root):
    python3 tools/generate-card-atlas.py [output.html]

Hand-maintained sections (update as decisions land):
  * CAP_LENS    — the capstones-need-AoE audit annotations (keyed by card id)
  * LINKED      — linked card pairs (Q-S2 and the Siphon/Sanguinarian pair)
  * PROPOSALS   — banked ideas and future cards (none of them in v2.1)
  (expected counts live in tools/catalog-expect.json, closure table CL-106)
"""
import json, html, re, sys, subprocess, datetime, os, tempfile, unicodedata
from html.parser import HTMLParser

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else 'sparkforge-card-atlas.html'

FAM = {
 'fire':   ('\U0001F525','FIRE','#FF7722'), 'chill': ('❄️','CHILL','#7EC8E3'),
 'shock':  ('⚡','SHOCK','#F6D36B'), 'bleed': ('\U0001FA78','BLEED','#CC4444'),
 'guardT': ('\U0001F6E1','GUARD','#8899AA'), 'voidT': ('\U0001F573','VOID','#9B59D0'),
 'growth': ('\U0001F331','GROWTH','#6FBF73'),'neutral':('◇','NEUTRAL','#B0A89C'),
}
CAP_LENS = {
 'cap_fire_everglow':    ('AoE ✓','Pulses + arena eruption are AoE, and both take the 50% boss-class scale. OPEN (A7b): the pulse never reaches the arena boss.', False),
 'cap_guard_ironmaiden': ('Mixed','Thorns/Retaliate/T5 are single-target retaliation; T4 kinetic burst is AoE (misses the arena boss). Boss-scale retrofit DONE in A5: thorns + Retaliate take 50% on mini-bosses and bosses (CL-67).', False),
 'cap_shock_skybeam':    ('Mixed','T1–T4 strike one target. T5 (A3, CL-8) strikes every 5s on its own clock: 300% ATK on the lassoed prey or the nearest enemy, plus 150% ATK splash within 80pt.', False),
 'cap_bleed_apex':       ('ST ⚠','Familiar hunts one target; execute is single-target. AoE-audit candidate (splash ≈50% of primary, never a second damage source).', True),
 'cap_void_erasure':     ('Global ✓','Event Horizon (Erasure T5 — the ×5 Void synergy is Listlessness now) is arena-wide by design. T1/T3 need a normal enemy to target, so they are silent in boss-only fights (A7b, CL-95).', False),
 'cap_chill_polarvortex':('AoE ✓','Storm is a field effect.', False),
 'v20_tree':             ('Mixed','Summon roster varies — audit per-animal (the NatureCanon roster in GameScene).', False),
}
PROPOSALS = [
 ('#C9B8E8','Variegated Rainbow','BANKED · v2.2+','breadth reward · CL-105 (Sep 25): not in v2.1',
  'Trigger: 1 card from every coloured tree in the run\'s palette. Prismatic Spark + rainbow projectiles (200%) + every 20s a full-screen "SUPER!" laser (350%, boss-resisted). No code exists; open design calls (what "200%" scales, laser vs the Carrier, offer seat, tag) are listed in CL-105.'),
 ('#CC4444','Scatter Shot (Option B)','BANKED IDEA','distinct from shipped Fracture Shot',
  'Shot absorbs into the first enemy hit, then scatters reduced-damage fragments outward from the victim to strike others. Fire-time split (Fracture) vs impact-time split (this).'),
 ('#F6D36B','Attack-speed laser ladder','BANKED IDEA','a Shock ladder card, not a capstone (Skybeam is Shock\'s one capstone)',
  '5-tier attack-speed ladder ending in a living-laser beam. It would ride the Shock gate like every Shock card (`shockUnlocked`).'),
]

# CL-106: the catalog A7a proved, shared with the canon generator. A mismatch
# stops the page from generating.
EXPECT = {k: v for k, v in json.load(open(os.path.join(ROOT, 'tools/catalog-expect.json'))).items() if k != '_about'}

def load_catalog():
    """Compile the real catalog and read it back (CL-103)."""
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, 'catalog.json')
        subprocess.run(['sh', os.path.join(ROOT, 'tools/catalog-harness/run.sh'), '--dump', out],
                       check=True, cwd=ROOT, stdout=subprocess.DEVNULL)
        data = json.load(open(out))
    def chips(d):
        return {int(k): ' + '.join(v) for k, v in d.items()}
    cards = []
    for c in data['cards']:
        cards.append(dict(
            id=c['id'], name=c['name'], tag=c['tagKey'], tag2=c.get('secondaryTagKey'),
            desc=c['description'], capstone=c['isCapstone'], secret=c['isSecret'],
            signature=c['isSignature'], maxTier=c['maxTier'],
            provides=' + '.join(c['provides']), requires=' + '.join(c['requires']),
            tierRequires=chips(c['tierRequires']), tierProvides=chips(c['tierProvides']),
            tierBlockedBy=chips(c['tierBlockedBy']),
            blockedBy=' + '.join(c['blockedBy']),
            detail=c.get('detail', ''), tiers=c.get('tierDescriptions', []),
            tierNames=c.get('tierNames', [])))
    syn = {k: [(t['threshold'], t['title'], t['effect']) for t in v] for k, v in data['synergies'].items()}
    return cards, syn, data['panda']

def assert_expected(cards):
    live = [c for c in cards if not c['secret']]
    got = {'total': len(cards), 'draftable': len(live), 'secret': len(cards) - len(live),
           'signatures': sum(c['signature'] for c in cards), 'capstones': sum(c['capstone'] for c in cards),
           'byTree': {t: sum(1 for c in live if c['tag'] == t) for t in EXPECT['byTree']}}
    assert got == EXPECT, f'catalog drifted from the expected counts:\n  got      {got}\n  expected {EXPECT}'
    unplaced = [c['id'] for c in live if c['tag'] not in FAM or (c['tag2'] and c['tag2'] not in FAM)]
    assert not unplaced, f'cards with no Atlas section: {unplaced}'

# Q-S2: linked cards — owning one and maxing the other upgrades it, no extra pick.
LINKED = {'shock_4': 'Chain Lightning (maxed → 35% / 2s)', 'shock_2': 'Overload (upgrades it at T4)',
          'v21_sanguinarian': "Siphon (Siphon's overheal → Blood Barrier)", 'bleed_4': 'Sanguinarian (overheal → Blood Barrier)'}

def esc(s): return html.escape(s or '')

def card_html(c, fam_color):
    crown = ' <span class="crown">\U0001F451 CAPSTONE</span>' if c['capstone'] else ''
    if c.get('signature'):
        crown += ' <span class="sig">★ SIGNATURE</span>'
    dual = f' <span class="dual">+{FAM[c["tag2"]][1]}</span>' if c.get('tag2') else ''
    gate = ''
    if c['id'] in LINKED: gate += f'<span class="gate link">linked ⇄ {esc(LINKED[c["id"]])}</span>'
    if c['provides']: gate += f'<span class="gate">grants ▸ {esc(c["provides"])}</span>'
    if c['requires']: gate += f'<span class="gate req">needs ▸ {esc(c["requires"])}</span>'
    for t, cap in sorted(c['tierRequires'].items()):
        gate += f'<span class="gate req">T{t} needs ▸ {esc(cap)}</span>'
    for t, cap in sorted(c['tierProvides'].items()):
        gate += f'<span class="gate">T{t} grants ▸ {esc(cap)}</span>'
    for t, cap in sorted(c['tierBlockedBy'].items()):
        gate += f'<span class="gate block">T{t} not offered once ▸ {esc(cap)}</span>'
    if c['blockedBy']: gate += f'<span class="gate block">not offered once ▸ {esc(c["blockedBy"])}</span>'
    tiers = c['tiers'] if c['tiers'] else [c['desc']] * c['maxTier']
    names = c.get('tierNames') or []
    if len(tiers) > 1:
        rungs = ''.join(
            f'<li><b>T{i+1}</b>{(" <em>%s</em>" % esc(names[i])) if i < len(names) else ""} {esc(t)}</li>'
            for i, t in enumerate(tiers))
        rungs = f'<ol class="rungs">{rungs}</ol>'
    else:
        rungs = f'<p class="one">{esc(tiers[0])}</p>'
    lens = ''
    if c['capstone'] and c['id'] in CAP_LENS:
        tagt, note, flag = CAP_LENS[c['id']]
        lens = f'<div class="{"lens flag" if flag else "lens"}"><b>AoE lens: {tagt}</b> {esc(note)}</div>'
    detail = f'<p class="detail">{esc(c["detail"])}</p>' if c.get('detail') else ''
    n = c['maxTier']
    return (f'<article class="card" style="--fc:{fam_color}" id="{c["id"]}">'
            f'<header><h4>{esc(c["name"])}{crown}{dual}</h4>'
            f'<span class="meta"><code>{c["id"]}</code> · {n} tier{"s" if n>1 else ""}</span></header>'
            f'{rungs}{detail}{lens}<footer>{gate}</footer></article>')

# A7a corrective 10: the header's provenance is display-only and names no Git
# commit. Under the single-unit-commit workflow the Atlas is rendered from the
# unit's uncommitted tree, so HEAD at render time names the previous unit's
# commit, not the source shown. The count is the authoritative expected total.
PROVENANCE = 'Source: compiled runtime catalog · {} cards'

def build(cards, SYN, panda_cfg):
    source = PROVENANCE.format(EXPECT['total'])
    today = datetime.date.today().strftime('%b %d %Y')
    order = ['fire','chill','shock','bleed','guardT','voidT','growth','neutral']
    nav, sections = '', ''
    for tag in order:
        emoji, label, color = FAM[tag]
        group = [c for c in cards if c['tag']==tag and not c['secret']]
        nav += f'<a href="#tree-{tag}" style="--fc:{color}">{emoji} {label}</a>'
        syn = ''
        if tag in SYN:
            rows = ''.join(
                f'<div class="syn-rung"><span class="thr">×{t}</span><b>{esc(ti)}</b><span>{esc(e)}</span>'
                f'</div>'
                for t,ti,e in SYN[tag])
            syn = f'<div class="synladder"><span class="synlabel">SYNERGY LADDER (distinct cards in tree)</span>{rows}</div>'
        body = ''.join(card_html(c, color) for c in group)
        sections += (f'<section id="tree-{tag}" style="--fc:{color}"><h2>{emoji} {label} '
                     f'<span class="count">{len(group)} cards</span></h2>{syn}'
                     f'<div class="cards">{body}</div></section>')
    panda = next(c for c in cards if c['secret'])
    tn = ' → '.join(panda['tierNames'])
    sections += (f'<section id="tree-secret" style="--fc:#775544"><h2>\U0001F43C SECRET '
                 f'<span class="count">1 card — outside the taxonomy</span></h2>'
                 f'<div class="cards"><article class="card secret" style="--fc:#775544" id="{panda["id"]}">'
                 f'<header><h4>{esc(panda["name"])}</h4><span class="meta"><code>{panda["id"]}</code> · {panda["maxTier"]} tiers · {panda_cfg["chance"] * 100:.2f}%/run</span></header>'
                 f'<p class="one">??? (masked forever, by design). Tier names: {esc(tn)}</p>'
                 f'<footer><span class="gate">never in the random pool · no synergy contribution · scheduler-only</span></footer>'
                 f'</article></div></section>')
    props = ''.join(
        f'<article class="card prop" style="--fc:{c}"><header><h4>{esc(n)} <span class="crown">{b}</span></h4>'
        f'<span class="meta">{m}</span></header><p class="one">{esc(t)}</p></article>'
        for c,n,b,m,t in PROPOSALS)
    sections += (f'<section id="proposals" style="--fc:#FFB84D"><h2>\U0001F6E0 REWORK PROPOSALS &amp; BANKED IDEAS '
                 f'<span class="count">banked — none of these are in v2.1</span></h2><div class="cards">{props}</div></section>')
    caps = sum(1 for c in cards if c['capstone'])
    css = open(os.path.join(ROOT, 'tools/card-atlas.css')).read()
    return f'''<title>Sparkforge Card Atlas</title>
<style>{css}</style>
<div class="wrap">
<h1>✦ SPARKFORGE CARD ATLAS</h1>
<p class="sub">every card, tier, and capstone in one place — the studio's standing visual aid for the arsenal</p>
<div class="stats"><span><b>{len(cards)}</b> cards</span><span><b>7</b> trees + Neutral + 1 secret · <b>{sum(1 for c in cards if not c['secret'])}</b> draftable</span><span><b>{caps}</b> capstones</span><span><b>7</b> synergy ladders (×3/×5/×7)</span><span class="provenance">{esc(source)}</span><span>generated {today}</span></div>
<nav>{nav}<a href="#tree-secret" style="--fc:#775544">\U0001F43C SECRET</a><a href="#proposals" style="--fc:#FFB84D">\U0001F6E0 PROPOSALS</a></nav>
{sections}
<footer class="page">Generated by <code>tools/generate-card-atlas.py</code> from the compiled <code>UpgradeManager.allCards</code> (catalog harness dump). Tier text is the live in-game copy. \U0001F451 = tree capstone. ★ = the tree's SIGNATURE (thesis card; the deterministic first pick). "AoE lens" = the capstones-need-AoE audit (⚠ = single-target falloff candidate). Gate lines show the eligibility layer: grants / needs, per-tier needs and grants, and "not offered once" (a card something you own has silenced). Reference card <code>ids</code> when proposing changes.</footer>
</div>'''

def assert_rendered(page, cards):
    """A7a corrective F4: validate the OUTPUT, not just the input. The rendered
    card ids must be exactly the catalog's — none missing, none extra, none
    twice — whatever the header claims."""
    rendered = re.findall(r'<article class="card(?: secret)?" style="[^"]*" id="([^"]+)">', page)
    want = [c['id'] for c in cards]
    dupes = sorted({i for i in rendered if rendered.count(i) > 1})
    missing, extra = sorted(set(want) - set(rendered)), sorted(set(rendered) - set(want))
    if len(rendered) != len(want) or dupes or missing or extra:
        sys.exit(f'rendered Atlas does not match the catalog: rendered {len(rendered)} of {len(want)}; '
                 f'missing {missing}; extra {extra}; duplicated {dupes}')

# ─── The Atlas's provenance, from the parsed page (A7a correctives 11–12) ────
# The page is parsed into an element TREE (stdlib html.parser; entities decoded)
# and its provenance is read as SEMANTICS, never as raw HTML, CSS classes or one
# literal tag. Each element carries inherited visibility:
#   not rendered  the `hidden` attribute, or inline display:none,
#                 visibility:hidden|collapse, content-visibility:hidden — removed
#                 from the screen AND the accessibility tree;
#   aria-hidden   aria-hidden="true" — out of the accessibility tree, still painted;
#   faded         inline opacity:0 or font-size:0 — painted invisibly, still read out.
# (The stylesheet may hide nothing at all — checked below — so no class can.)
# Text is flattened in document order into ITEMS, with a boundary at every
# block element, at both edges of every non-formatting element (span, a, …),
# and between adjacent sibling elements; formatting elements (b, em, code, …)
# join the text around them, so "H<b>E</b>AD" is still HEAD while
# "<span>…</span><span>GIT</span>" keeps GIT a separate token. Tooltip and
# accessibility attributes (title, alt, aria-label, aria-description,
# placeholder) are items of their own. For provenance only, every item is NFKC-
# normalised with default-ignorable characters removed (U+034F, U+FE0F, zero-
# width, bidi and variation selectors, tags …) and whitespace collapsed; matching
# is case-folded. The rendered card copy is never changed.
# The model the page must resolve to:
#   * exactly ONE source claim ("source:" or "compiled runtime catalog", any
#     case) across everything painted or announced (text not `not rendered`,
#     and the attributes of elements not `not rendered`), in EVERY reading;
#     and a fully SHOWN item (none of the three flags) reading exactly
#     "Source: compiled runtime catalog · N cards", N = catalog-expect.json's
#     total = the <article id=…> cards rendered;
#   * exactly ONE date value on the same channels, and a SHOWN item reading
#     exactly "generated Mon DD YYYY", a real calendar date;
#   * ZERO Git claims anywhere — hidden content and every attribute included:
#     "commit", "@", "rev-parse" (contained); "git", "head" (as words); or a
#     standalone run of 7+ hex digits (a 7–40 char commit, or longer).
# Because a reader may see adjacent inline elements joined or apart, claims
# are counted and Git words searched in several READINGS (the semantic one,
# plus every combination of joining/breaking text↔element and element↔element
# edges) and the strictest result wins.

_IGNORABLE = [(0x00AD, 0x00AD), (0x034F, 0x034F), (0x061C, 0x061C), (0x115F, 0x1160), (0x17B4, 0x17B5),
              (0x180B, 0x180F), (0x200B, 0x200F), (0x202A, 0x202E), (0x2060, 0x206F), (0x3164, 0x3164),
              (0xFE00, 0xFE0F), (0xFEFF, 0xFEFF), (0xFFA0, 0xFFA0), (0xFFF0, 0xFFF8), (0x1BCA0, 0x1BCA3),
              (0x1D173, 0x1D17A), (0xE0000, 0xE0FFF)]     # Unicode Default_Ignorable_Code_Point


def _ignorable(ch):
    o = ord(ch)
    return unicodedata.category(ch) == 'Cf' or any(lo <= o <= hi for lo, hi in _IGNORABLE)


def _norm(text):
    """Provenance normalisation: NFKC, default-ignorables removed, whitespace collapsed."""
    text = unicodedata.normalize('NFKC', text)
    text = unicodedata.normalize('NFKC', ''.join(ch for ch in text if not _ignorable(ch)))
    return re.sub(r'\s+', ' ', text).strip()


class _Node:
    def __init__(self, tag, attrs):
        self.tag, self.children = tag, []
        self.attrs = {k.lower(): v or '' for k, v in attrs}
        decl = {}
        for part in re.sub(r'/\*.*?\*/', '', self.attrs.get('style', ''), flags=re.S).split(';'):
            if ':' in part:
                prop, val = part.split(':', 1)
                decl[prop.strip().lower()] = re.sub(r'\s*!\s*important\s*$', '', val.strip().lower())
        self.not_rendered = ('hidden' in self.attrs or decl.get('display') == 'none'
                             or decl.get('visibility') in ('hidden', 'collapse') or decl.get('content-visibility') == 'hidden')
        self.aria_hidden = self.attrs.get('aria-hidden', '').strip().lower() == 'true'
        self.faded = re.fullmatch(r'0*\.?0*(px|em|rem|%|pt)?', decl.get('opacity', 'x')) is not None \
            or re.fullmatch(r'0*\.?0*(px|em|rem|%|pt)?', decl.get('font-size', 'x')) is not None


class _Tree(HTMLParser):
    VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'source', 'track', 'wbr'}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = _Node('#root', [])
        self.open = [self.root]
        self.styles = []

    def handle_starttag(self, tag, attrs):
        node = _Node(tag, attrs)
        self.open[-1].children.append(node)
        if tag not in self.VOID:
            self.open.append(node)

    def handle_startendtag(self, tag, attrs):
        self.open[-1].children.append(_Node(tag, attrs))

    def handle_endtag(self, tag):
        if any(n.tag == tag for n in self.open[1:]):
            while self.open[-1].tag != tag:
                self.open.pop()
            self.open.pop()

    def handle_data(self, data):
        if self.open[-1].tag == 'style':
            self.styles.append(data)
        self.open[-1].children.append(data)


SKIP = {'style', 'script', 'template', 'head'}
BLOCK = {'address', 'article', 'aside', 'blockquote', 'br', 'dd', 'details', 'dialog', 'div', 'dl', 'dt', 'fieldset',
         'figcaption', 'figure', 'footer', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hgroup', 'hr', 'li',
         'main', 'nav', 'ol', 'p', 'pre', 'section', 'summary', 'table', 'tbody', 'td', 'tfoot', 'th', 'thead', 'title',
         'tr', 'ul'}
FORMATTING = {'abbr', 'b', 'bdi', 'bdo', 'big', 'cite', 'code', 'data', 'del', 'dfn', 'em', 'font', 'i', 'ins', 'kbd',
              'mark', 's', 'samp', 'small', 'strike', 'strong', 'sub', 'sup', 'time', 'tt', 'u', 'var'}
ACCESSIBLE = ('title', 'alt', 'aria-label', 'aria-description', 'placeholder')
POLICIES = ['semantic', (True, True), (True, False), (False, True), (False, False)]   # (join text↔el, join el↔el)
CHANNELS = {'all': lambda n: False,                                    # every node (the Git scan)
            'present': lambda n: n.not_rendered,                        # painted or announced
            'shown': lambda n: n.not_rendered or n.aria_hidden or n.faded}  # fully shown


def _edge(policy, el, neighbour):
    """Is there a boundary between element `el` and its sibling `neighbour`?"""
    if el.tag in BLOCK or isinstance(neighbour, _Node) and neighbour.tag in BLOCK:
        return True
    if neighbour is None:
        return False
    if policy == 'semantic':
        return el.tag not in FORMATTING or isinstance(neighbour, _Node)
    join_text, join_el = policy
    return not (join_el if isinstance(neighbour, _Node) else join_text)


def _reading(root, policy, excluded):
    items = [[]]
    def cut():
        if items[-1]:
            items.append([])
    def walk(node):
        kids = [k for k in node.children if isinstance(k, str) or (k.tag not in SKIP and not excluded(k))]
        for i, k in enumerate(kids):
            if isinstance(k, str):
                items[-1].append(k)
                continue
            if _edge(policy, k, kids[i - 1] if i else None):
                cut()
            walk(k)
            if _edge(policy, k, kids[i + 1] if i + 1 < len(kids) else None):
                cut()
    walk(root)
    return [t for t in (_norm(''.join(f)) for f in items) if t]


def _attr_items(root, excluded):
    out = []
    def walk(node):
        for k in node.children:
            if isinstance(k, _Node) and k.tag not in SKIP and not excluded(k):
                out.extend(_norm(k.attrs[a]) for a in ACCESSIBLE if _norm(k.attrs.get(a, '')))
                walk(k)
    walk(root)
    return out


MONTHS = r'(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)'
DATE = r'(?<![^\W\d_])' + MONTHS + r'\s+\d{1,2}\s+\d{4}(?!\d)|(?<!\d)\d{4}-\d{2}-\d{2}(?!\d)'
SOURCE_CLAIM = [r'source\s*:', r'compiled\s*runtime\s*catalog']
FORBIDDEN = [('"commit"', r'commit'), ('"@"', r'@'), ('"rev-parse"', r'rev-parse'),
             ('"git"', r'(?<![^\W\d_])git(?![^\W\d_])'), ('"head"', r'(?<![^\W\d_])head(?![^\W\d_])'),
             ('a hash', r'(?<![^\W_])[0-9a-f]{7,}(?![^\W_])')]
STYLE_HIDING = r'display\s*:\s*none|visibility\s*:\s*(hidden|collapse)|content-visibility\s*:\s*hidden|opacity\s*:\s*0*\.?0*\s*[;}!]' \
               r'|font-size\s*:\s*0*\.?0*[a-z%]*\s*[;}!]|text-indent\s*:\s*-|clip(-path)?\s*:'


def _source_claims(item):
    low = item.casefold()
    return max(len(re.findall(p, low)) for p in SOURCE_CLAIM)


def assert_provenance(page):
    """A7a corrective 12: the parsed page's provenance equals the model above."""
    tree = _Tree()
    tree.feed(page)
    tree.close()
    total = json.load(open(os.path.join(ROOT, 'tools/catalog-expect.json')))['total']
    label = f'Source: compiled runtime catalog · {total} cards'           # its own copy, never PROVENANCE
    readings = {(ch, pol): _reading(tree.root, pol, ex) + _attr_items(tree.root, ex)
                for ch, ex in CHANNELS.items() for pol in POLICIES}
    shown_text = _reading(tree.root, 'semantic', CHANNELS['shown'])
    problems = []
    css = '\n'.join(tree.styles)
    if re.search(STYLE_HIDING, css, re.I):
        problems.append('the stylesheet can hide elements (visibility is validated from markup only)')
    # One source claim, the approved one, shown.
    claims = max(sum(_source_claims(i) for i in readings[('present', pol)]) for pol in POLICIES)
    if claims != 1:
        problems.append(f'{claims} source claims on the page (expected exactly one)')
    if shown_text.count(label) != 1:
        problems.append(f'no single shown item reads exactly "{label}"')
    def walk_articles(node):
        return sum((k.tag == 'article' and bool(k.attrs.get('id'))) + walk_articles(k)
                   for k in node.children if isinstance(k, _Node))
    cards = walk_articles(tree.root)
    if cards != total:
        problems.append(f'the label counts {total} cards (tools/catalog-expect.json) but {cards} are rendered')
    # One real generated date, shown.
    dates = max(sum(len(re.findall(DATE, i.casefold())) for i in readings[('present', pol)]) for pol in POLICIES)
    stamped = [m for i in shown_text for m in [re.fullmatch(r'generated (' + MONTHS + r') (\d{1,2}) (\d{4})', i.casefold())] if m]
    if dates != 1 or len(stamped) != 1:
        problems.append(f'{dates} dates on the page and {len(stamped)} shown "generated <date>" items (expected exactly one of each)')
    else:
        try:
            datetime.datetime.strptime(' '.join(stamped[0].groups()), '%b %d %Y')
        except ValueError:
            problems.append(f'the generated date "{" ".join(stamped[0].groups())}" is not a real date')
    # No Git claims, in any reading of any channel.
    claims_git = sorted({f'{what} {m!r}' for items in readings.values() for i in items
                         for what, pat in FORBIDDEN for m in re.findall(pat, i.casefold())})
    if claims_git:
        problems.append('the page claims Git provenance: ' + ', '.join(claims_git[:6]))
    if problems:
        sys.exit('rendered Atlas provenance failed validation: ' + '; '.join(problems))

if __name__ == '__main__':
    cards, syn, panda_cfg = load_catalog()
    assert_expected(cards)
    page = build(cards, syn, panda_cfg)
    assert_rendered(page, cards)
    assert_provenance(page)
    open(OUT, 'w').write(page)
    print(f'{OUT}: {len(cards)} cards rendered and verified')
