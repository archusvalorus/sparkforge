#!/usr/bin/env python3
"""v2.2 J0 baseline — where each card's numbers live today.

Read-only. Splits `UpgradeManager.buildCardPool()` into its card blocks and,
for each card's EFFECT code (comments and string literals removed), lists:

  config    the `GameConfig.<Enum>.<name>` values the effect reads, including
            those reached through a captured local (`gouge`, `siphon`, `shove`)
  literals  effect lines that carry a number written in place
  kind      "config"   numbers come from GameConfig only
            "literal"  at least one number is written in the effect
            "mixed"    both
            "switch"   the effect only sets a flag or a tier; its numbers live
                       where that flag is read (PlayerStats, the scene, a node)
            "none"     empty effect (the scene acts on the card id)

It is a heuristic over source text, made for the J0 ownership map. It proves
nothing about behaviour and is not a check.

Usage (repo root):  python3 tools/v2.2-catalog/baseline/inventory.py [out.json]
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SRC = os.path.join(ROOT, 'Sparkforge/Systems/UpgradeManager.swift')

text = open(SRC).read()
pool = text[text.index('private static func buildCardPool()'):]


def code_only(s):
    s = re.sub(r'"(?:\\.|[^"\\])*"', '""', s)      # string literals → ""
    return re.sub(r'//[^\n]*', '', s)               # line comments


# Captured locals: `let gouge = GameConfig.Bleed.gougeCritTotals`
local_cfg = dict(re.findall(r'let (\w+) = (GameConfig\.\w+\.\w+)\n', pool))

blocks = pool.split('cards.append(UpgradeCard(')[1:]
out = []
for raw in blocks:
    m = re.search(r'id: (?:"([^"]+)"|(GameConfig\.\w+\.\w+))', raw)
    card_id = m.group(1) or m.group(2)
    name = re.search(r'name: "([^"]*)"', raw).group(1)
    code = code_only(raw)
    # The block runs to the next append; cut at this card's closing `))` or `})`.
    end = re.search(r'\n        \}?\)\)?\n', code)
    code = code[:end.end()] if end else code
    lines = [l.strip() for l in code.split('\n') if 'stats' in l]
    config = sorted(set(re.findall(r'GameConfig\.\w+\.\w+', code)) - {'GameConfig.Panda.cardID'})
    for local, cfg in local_cfg.items():
        if re.search(r'\b' + local + r'\[', code):
            config = sorted(set(config) | {cfg})
    literals = []
    for l in lines:
        body = re.sub(r'GameConfig\.\w+\.\w+(\[\d+\])?', '', l)
        body = re.sub(r'\b\w+\[\w+( - 1)?\]', '', body)           # local[i], local[i - 1]
        body = re.sub(r'\b\w*Tier = \d+', '', body)               # tier switches
        if re.search(r'(?<![\w.])\d+(\.\d+)?', body):
            literals.append(l)
    effect_lines = [l for l in lines if 'stats.' in l]
    if not effect_lines:
        kind = 'none'
    elif literals and config:
        kind = 'mixed'
    elif literals:
        kind = 'literal'
    elif config:
        kind = 'config'
    else:
        kind = 'switch'
    out.append({'id': card_id, 'name': name, 'kind': kind, 'config': config, 'literals': literals})

summary = {}
for c in out:
    summary[c['kind']] = summary.get(c['kind'], 0) + 1
result = {'_about': __doc__.split('\n')[0], 'source': 'Sparkforge/Systems/UpgradeManager.swift',
          'summary': summary, 'cards': out}
if len(sys.argv) > 1:
    json.dump(result, open(sys.argv[1], 'w'), indent=1)
    print(f'{sys.argv[1]}: {len(out)} cards, {summary}')
else:
    print(json.dumps(result, indent=1))
