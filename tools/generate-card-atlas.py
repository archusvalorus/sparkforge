#!/usr/bin/env python3
"""Sparkforge Card Atlas generator (v2.1, Aug 2026).

Parses UpgradeManager.buildCardPool() straight out of the Swift source and
emits a single self-contained HTML page — the studio's standing visual aid
for the card/ability roster (Brandon's call, Aug 10 2026). Publish the
output as the existing "Sparkforge Card Atlas" artifact so the URL stays
stable.

Usage (from repo root):
    python3 tools/generate-card-atlas.py [output.html]

The parser is regex-based and leans on the pool's consistent authoring
style: `UpgradeCard(id: "...", name: "...", tag: .x, ... )` with string
literals for descriptions and tierDescriptions. If a future card breaks the
pattern (e.g. a computed id, like Panda's GameConfig.Panda.cardID), add a
special case the way Panda has one below.

Hand-maintained sections (update as decisions land):
  * SYN         — synergy ladders (mirror UpgradeManager.synergyTiers)
  * CAP_LENS    — the capstones-need-AoE audit annotations
  * PROPOSALS   — banked rework proposals / new-card ideas
"""
import re, json, html, sys, subprocess, datetime, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'Sparkforge/Systems/UpgradeManager.swift')
OUT = sys.argv[1] if len(sys.argv) > 1 else 'sparkforge-card-atlas.html'

FAM = {
 'fire':   ('\U0001F525','FIRE','#FF7722'), 'chill': ('❄️','CHILL','#7EC8E3'),
 'shock':  ('⚡','SHOCK','#F6D36B'), 'bleed': ('\U0001FA78','BLEED','#CC4444'),
 'guardT': ('\U0001F6E1','GUARD','#8899AA'), 'voidT': ('\U0001F573','VOID','#9B59D0'),
 'growth': ('\U0001F331','GROWTH','#6FBF73'),'neutral':('◇','NEUTRAL','#B0A89C'),
}
SYN = {
 'fire':  [(3,'Spreading Flame','Burns leap to nearby enemies'),(5,'Wildfire Heart','Burns spread farther and hit harder'),(7,'Inferno Crown','Every enemy in the arena is burning')],
 'shock': [(3,'Chain Current','Lightning chains to one more enemy'),(5,'Tesla Field','A charged aura damages nearby enemies'),(7,'Storm Engine','Every 3rd shot fires a chaining spread')],
 'bleed': [(3,'Open Wounds','Bleeding enemies take more damage'),(5,'Exsanguinate','Low-HP enemies take double damage'),(7,'Red Harvest','Bleed kills restore HP')],
 'guardT':[(3,'Ironhide','Gain DEF while enemies crowd you'),(5,'Thornwall','Enemies that touch you take damage back'),(7,'Unbroken Core','Your DEF fuels damage and steadies your core')],
 'voidT': [(3,'Undertow','Void pulls nearby enemies inward'),(5,'Event Horizon','Enemies caught in Void struggle to escape'),(7,'Singularity','Void collapses enemies into ruin')],
 'chill': [(3,'Frostbite','Chilled enemies move even slower'),(5,'Shatter','Frozen enemies burst when struck'),(7,'Absolute Zero','The arena slows; shatters come easy')],
 'growth':[(3,'Rootbound','Cultivated ground grips harder — enemies on it are slower'),(5,'Verdant Rise','Your ground mends you faster'),(7,'Wildwood','The whole garden bites what stands on it')],
}
CAP_LENS = {
 'Everglow':    ('AoE ✓','Pulses + arena eruption are AoE. OPEN: eruption damage path not yet boss-scaled (retrofit).', True),
 'Iron Maiden': ('Mixed','Thorns/T5 are single-target retaliation; T4 kinetic burst is AoE. OPEN: damage paths not yet boss-scaled (retrofit).', True),
 'Skybeam':     ('ST ⚠','Single-target strikes only — the pre-boss swarm outruns it. Banked rework below.', True),
 'Apex':        ('ST ⚠','Familiar hunts one target; execute is single-target. AoE-audit candidate (splash ≈50% of primary, never a second damage source).', True),
 'Erasure':     ('Global ✓','Event Horizon is arena-wide by design.', False),
 'Polar Vortex':('AoE ✓','Storm is a field effect.', False),
 'Tree':        ('Mixed','Summon roster varies — audit per-animal (memory: tree-capstone animal pool).', False),
}
PROPOSALS = [
 ('#F6D36B','Skybeam T5 rework','BANKED','touches <code>skybeam</code> capstone only',
  'T5 strike becomes lasso-independent: flat 5s cadence, 300% ATK, +50% splash, heavier bolt visual. T1–T4 untouched. Build trap on file: updateSkybeam early-returns with no lasso — the guard must move or the change no-ops.'),
 ('#8899AA','Thornwall true damage','BANKED','Guard ×5 synergy, one constant',
  'Reflect 0.30 → 1.50 (pre-mitigation, true damage, shield-bypass already work). OPEN CALLS: is 1.50 the start or the cap? Bosses currently take reflect unscaled — cap or scale?'),
 ('#C9B8E8','Variegated Rainbow','PROPOSED CAPSTONE','breadth reward · IN v2.1 per Brandon',
  'Trigger: 1 card from every ACTIVE tree this run. Prismatic Spark + rainbow projectiles (200%) + every 20s a full-screen "SUPER!" laser (350%, boss-resisted). Pairs with arena tree-gating via the existing provides/requires eligibility layer.'),
 ('#CC4444','Scatter Shot (Option B)','BANKED IDEA','distinct from shipped Fracture Shot',
  'Shot absorbs into the first enemy hit, then scatters reduced-damage fragments outward from the victim to strike others. Fire-time split (Fracture) vs impact-time split (this).'),
 ('#F6D36B','Attack-speed laser capstone','BANKED IDEA','Shock, conditional (requires a Shock card)',
  '5-tier attack-speed ladder ending in a living-laser beam. Example of a tier ladder + conditional capstone grammar.'),
]

def extract_cards():
    src = open(SRC).read()
    pool = src[src.index('private static func buildCardPool'):]
    cards = []
    for ch in pool.split('UpgradeCard(')[1:]:
        def grab(pat, default=None):
            m = re.search(pat, ch); return m.group(1) if m else default
        cid = grab(r'id:\s*"([^"]+)"') or ('v20_panda' if 'GameConfig.Panda.cardID' in ch.split('apply:')[0] else None)
        if not cid: continue
        tiers = re.search(r'tierDescriptions:\s*\[(.*?)\]\s*,?\n', ch, re.S)
        tnames = re.search(r'tierNames:\s*\[(.*?)\]', ch, re.S)
        cards.append(dict(
            id=cid, name=grab(r'name:\s*"([^"]+)"'), tag=grab(r'tag:\s*\.(\w+)'),
            tag2=grab(r'secondaryTag:\s*\.(\w+)'), desc=grab(r'description:\s*"([^"]*)"'),
            capstone=('isCapstone: true' in ch), secret=('isSecret: true' in ch),
            provides=(grab(r'provides:\s*\[\.(\w+)\]') or ''),
            requires=(grab(r'requires:\s*\[\.(\w+)\]') or ''),
            tiers=(re.findall(r'"([^"]*)"', tiers.group(1)) if tiers else []),
            tierNames=(re.findall(r'"([^"]*)"', tnames.group(1)) if tnames else [])))
    return cards

def esc(s): return html.escape(s or '')

def card_html(c, fam_color):
    crown = ' <span class="crown">\U0001F451 CAPSTONE</span>' if c['capstone'] else ''
    dual = f' <span class="dual">+{FAM[c["tag2"]][1]}</span>' if c.get('tag2') else ''
    gate = ''
    if c['provides']: gate += f'<span class="gate">grants ▸ {esc(c["provides"])}</span>'
    if c['requires']: gate += f'<span class="gate req">needs ▸ {esc(c["requires"])}</span>'
    tiers = c['tiers'] if c['tiers'] else [c['desc']]
    names = c.get('tierNames') or []
    if len(tiers) > 1:
        rungs = ''.join(
            f'<li><b>T{i+1}</b>{(" <em>%s</em>" % esc(names[i])) if i < len(names) else ""} {esc(t)}</li>'
            for i, t in enumerate(tiers))
        rungs = f'<ol class="rungs">{rungs}</ol>'
    else:
        rungs = f'<p class="one">{esc(tiers[0])}</p>'
    lens = ''
    if c['capstone'] and c['name'] in CAP_LENS:
        tagt, note, flag = CAP_LENS[c['name']]
        lens = f'<div class="{"lens flag" if flag else "lens"}"><b>AoE lens: {tagt}</b> {esc(note)}</div>'
    n = len(tiers)
    return (f'<article class="card" style="--fc:{fam_color}" id="{c["id"]}">'
            f'<header><h4>{esc(c["name"])}{crown}{dual}</h4>'
            f'<span class="meta"><code>{c["id"]}</code> · {n} tier{"s" if n>1 else ""}</span></header>'
            f'{rungs}{lens}<footer>{gate}</footer></article>')

def build(cards):
    commit = subprocess.run(['git','rev-parse','--short','HEAD'], capture_output=True,
                            text=True, cwd=ROOT).stdout.strip() or '?'
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
                f'{"<span class=flagchip>REWORK BANKED</span>" if ti=="Thornwall" else ""}</div>'
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
                 f'<div class="cards"><article class="card secret" style="--fc:#775544">'
                 f'<header><h4>Pandas.</h4><span class="meta"><code>v20_panda</code> · 5 tiers · 9.27%/run</span></header>'
                 f'<p class="one">??? (masked forever, by design). Tier names: {esc(tn)}</p>'
                 f'<footer><span class="gate">never in the random pool · no synergy contribution · scheduler-only</span></footer>'
                 f'</article></div></section>')
    props = ''.join(
        f'<article class="card prop" style="--fc:{c}"><header><h4>{esc(n)} <span class="crown">{b}</span></h4>'
        f'<span class="meta">{m}</span></header><p class="one">{esc(t)}</p></article>'
        for c,n,b,m,t in PROPOSALS)
    sections += (f'<section id="proposals" style="--fc:#FFB84D"><h2>\U0001F6E0 REWORK PROPOSALS &amp; BANKED IDEAS '
                 f'<span class="count">for this pass</span></h2><div class="cards">{props}</div></section>')
    caps = sum(1 for c in cards if c['capstone'])
    css = open(os.path.join(ROOT, 'tools/card-atlas.css')).read()
    return f'''<title>Sparkforge Card Atlas</title>
<style>{css}</style>
<div class="wrap">
<h1>✦ SPARKFORGE CARD ATLAS</h1>
<p class="sub">every card, tier, and capstone in one place — the studio's standing visual aid for the arsenal</p>
<div class="stats"><span><b>{len(cards)}</b> cards</span><span><b>8</b> trees + 1 secret</span><span><b>{caps}</b> capstones</span><span><b>7</b> synergy ladders (×3/×5/×7)</span><span>source: UpgradeManager @ <b>{commit}</b> · {today}</span></div>
<nav>{nav}<a href="#tree-secret" style="--fc:#775544">\U0001F43C SECRET</a><a href="#proposals" style="--fc:#FFB84D">\U0001F6E0 PROPOSALS</a></nav>
{sections}
<footer class="page">Generated by <code>tools/generate-card-atlas.py</code> from <code>UpgradeManager.buildCardPool()</code>. Tier text is the live in-game copy. \U0001F451 = tree capstone. "AoE lens" = the capstones-need-AoE audit (⚠ = single-target falloff candidate). Gate lines show the provides/requires eligibility layer. Reference card <code>ids</code> when proposing changes.</footer>
</div>'''

if __name__ == '__main__':
    cards = extract_cards()
    assert len(cards) >= 80, f'extracted only {len(cards)} cards — parser drift?'
    open(OUT, 'w').write(build(cards))
    print(f'{OUT}: {len(cards)} cards')
