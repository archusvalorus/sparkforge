#!/usr/bin/env python3
"""The retained mutation suite: A7a's, extended by A7b (ids `B7-…`). Test support; tools/ is not in the app target.

Each mutant is an exact-string edit (or a short list of them, applied in
order, each matching exactly once; or `RE(pattern)` → every regex match) on a throwaway copy of the repo
(Sparkforge/Systems, Config, Scenes, Nodes, Utils, tools, docs); the listed checks then run
in that copy. A mutant with no edit (None) is a CONTROL: its check is a
scenario that must fail on the unmutated tree. The canon's fingerprint checks
are multi-step flows (`detects-*`, `git-onecommit`, `git-stale`; see _flow).
Verdicts:
  KILLED    a check FAILED by assertion (a Swift harness printed FAIL, or a
            generator exited non-zero with its own validation message)
  SURVIVED  everything still passed — a coverage gap
  INVALID   the mutant didn't compile / crashed (never counts as coverage)
  TIMEOUT   a check ran past the timeout (a hang is a gap, never coverage)
  NO-MATCH  the mutant's source string isn't in the tree (the suite is stale)
Before any mutant runs, the UNMUTATED copy must pass every check used.

Usage (from the repo root):
    python3 tools/catalog-harness/mutations.py            # the full suite
    python3 tools/catalog-harness/mutations.py -j 6       # parallel workers (default 4)
    python3 tools/catalog-harness/mutations.py F3A S1     # only mutants whose id starts so
Exit status 0 only if every mutant selected is KILLED.
"""
import concurrent.futures, os, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UM = 'Sparkforge/Systems/UpgradeManager.swift'
GS = 'Sparkforge/Scenes/GameScene.swift'
SHATTER = 'Sparkforge/Systems/ShatterRule.swift'   # A7b S10
CM = 'Sparkforge/Systems/CodexManager.swift'
ATLAS, CANON = 'tools/generate-card-atlas.py', 'tools/generate-ability-canon.py'
CANON_DOC = 'docs/v2.1-ability-canon.md'
SIDECAR = 'docs/v2.1-ability-canon-sidecar.json'
CAT, CHILL, SIG, GUARD = 'catalog', 'chill', 'signature-draw', 'guard'
VULN = 'vulnerability'   # A7b S6 corrective 7: the real-node harness
TIMEOUT = 600

class RE(str):
    """A regex mutant: every match of the pattern is replaced (at least one required)."""

FP_STAMP = r'(source-input fingerprint `sha256:)[0-9a-f]{64}(`)'

M = [
 # --- the shared offer predicate (CL-89 + corrective F2), clause by clause ---
 ('P1 predicate: maxed clause removed', UM, '        guard tier(of: card.id) < card.maxTier else { return false }\n        // Corrective F2', '        // Corrective F2', [CAT]),
 ('P2 predicate: requires clause removed', UM, '        guard card.requires.isSubset(of: capabilities) else { return false }\n        // v2.1 A2 / A7a', '        // v2.1 A2 / A7a', [CAT]),
 ('P3 next tier: tierRequires ignored', UM, '        if let need = card.tierRequires[next], !need.isSubset(of: capabilities) { return false }\n', '', [CAT, CHILL]),
 ('P3b next tier: tierBlockedBy ignored', UM, '        if let block = card.tierBlockedBy[next], !block.isDisjoint(with: capabilities) { return false }\n', '', [CAT]),
 ('P3c predicate: next-tier gates not consulted', UM, '        guard nextTierOpen(card) else { return false }\n', '', [CAT, CHILL]),
 ('P4 predicate: blockedBy clause removed', UM, '        guard card.blockedBy.isDisjoint(with: capabilities) else { return false }\n', '', [CAT]),
 ('P5 predicate: secret clause removed', UM, '        if card.isSecret { return false }\n        // v2.0 (E1)', '        // v2.0 (E1)', [CAT, SIG]),
 ('P6 predicate: active-colour clause removed', UM, '        guard activeFamilies.contains(card.tag) else { return false }\n        // A dual-tag', '        // A dual-tag', [CAT, SIG]),
 ('P7 predicate: bridge clause removed', UM, '        if let second = card.secondaryTag, !activeFamilies.contains(second) { return false }\n        // Capstones never', '        // Capstones never', [CAT]),
 ('P8 predicate: capstone lockout removed', UM, '        if card.isCapstone && capstoneInProgress { return false }\n        return true', '        return true', [CAT]),
 ('P9 capstoneInProgress always false', UM, '    private var capstoneInProgress: Bool { !activeCapstones.isEmpty }', '    private var capstoneInProgress: Bool { false }', [CAT]),
 ('P10 a stalled capstone still counts as active', UM, '$0.isCapstone && tier(of: $0.id) > 0 && tier(of: $0.id) < $0.maxTier && nextTierOpen($0)', '$0.isCapstone && tier(of: $0.id) > 0 && tier(of: $0.id) < $0.maxTier', [CAT]),
 ('P11 predicate: same-level clause removed (F2)', UM, '        guard !takenAt(level).contains(card.id) else { return false }\n        // v2.0 Phase C', '        // v2.0 Phase C', [CAT]),
 ('P12 takenAt ignores the level', UM, '        cardsTakenLevel == level ? cardsTakenThisLevel : []', '        cardsTakenThisLevel', [CAT]),
 # --- the bonus draw ---
 ('B1 bonus: back to the pre-A7a filter', UM, '!displayedIDs.contains($0.id) && isOfferable($0, capstoneInProgress: inProgress, level: lastDrawLevel)',
  'tier(of: $0.id) < $0.maxTier && !displayedIDs.contains($0.id) && !$0.isSecret && activeFamilies.contains($0.tag) && $0.requires.isSubset(of: capabilities)', [CAT]),
 ('B2 bonus: judged at the wrong level (same-level exclusion lost)', UM, 'isOfferable($0, capstoneInProgress: inProgress, level: lastDrawLevel)', 'isOfferable($0, capstoneInProgress: inProgress, level: -1)', [CAT]),
 ('B4 bonus: pity not reset', UM, '        if let bonus, !bonus.provides.isEmpty { levelsSinceGatewayOffer[bonus.id] = 0 }\n', '', [CAT]),
 ('B5 bonus: displayed cards not excluded', UM, '!displayedIDs.contains($0.id) && isOfferable(', 'isOfferable(', [CAT]),
 ('B6 bonus: capstone flag passed as false', UM, 'isOfferable($0, capstoneInProgress: inProgress, level: lastDrawLevel)', 'isOfferable($0, capstoneInProgress: false, level: lastDrawLevel)', [CAT]),
 # --- pickCard bookkeeping ---
 ('K1 pickCard: tierProvides never granted', UM, '        if let granted = card.tierProvides[current + 1] { capabilities.formUnion(granted) }\n', '', [CAT]),
 ('K2 pickCard: tierProvides granted one tier early', UM, '        if let granted = card.tierProvides[current + 1] { capabilities.formUnion(granted) }', '        if let granted = card.tierProvides[current + 2] { capabilities.formUnion(granted) }', [CAT]),
 ('K3 pickCard: taken-this-level never recorded', UM, '        cardsTakenThisLevel.insert(card.id)\n', '', [CAT]),
 ('K4 pickCard: taken set never cleared on a new level', UM, '        if level != cardsTakenLevel { cardsTakenLevel = level; cardsTakenThisLevel.removeAll() }', '        if level != cardsTakenLevel { cardsTakenLevel = level }', [CAT]),
 # --- F1: acquisition-time eligibility ---
 ('S1 isSelectable always true', UM, '    func isSelectable(_ card: UpgradeCard, atLevel level: Int) -> Bool {\n', '    func isSelectable(_ card: UpgradeCard, atLevel level: Int) -> Bool {\n        if true { return true }\n', [CAT]),
 ('S2 isSelectable: taken-this-level ignored', UM, '        guard !takenAt(level).contains(card.id) else { return false }\n        if card.isSecret {', '        if card.isSecret {', [CAT]),
 ('S3 isSelectable: the capstone seat routed through the ordinary rule', UM, '        if activeCapstones.contains(where: { $0.id == card.id }) { return true }\n', '', [CAT]),
 ('S4 isSelectable: the panda routed through the ordinary rule', UM, '        if card.isSecret { return pandaOffer(atLevel: level)?.id == card.id }\n', '', [CAT]),
 ('S5 acquire ignores isSelectable', UM, '        guard isSelectable(card, atLevel: level) else { return false }\n        pickCard(card, stats: stats, level: level)', '        pickCard(card, stats: stats, level: level)', [CAT]),
 ('S6 stillSelectable keeps everything', UM, '        cards.filter { isSelectable($0, atLevel: level) }', '        cards', [CAT]),
 ('S7 scene: commit goes back to the raw pickCard', GS, '        guard upgradeManager.acquire(card, stats: playerStats, level: player.currentLevel) else { return }\n        AudioManager.shared.play(.cardSelect)',
  '        upgradeManager.pickCard(card, stats: playerStats, level: player.currentLevel)\n        AudioManager.shared.play(.cardSelect)', [CAT]),
 ('S8 scene: Extra Pick never revalidates', GS, '            displayedCards.removeAll { !legal.contains($0.card.id) }\n', '', [CAT]),
 ('S9 scene: an empty table no longer resolves the Extra Pick', GS, '            if displayedCards.isEmpty {\n                extraPicksRemaining = 0', '            if false {\n                extraPicksRemaining = 0', [CAT]),
 # --- CL-93 symmetric (CC-1) and the ruled edges ---
 ('E1 Gouge no longer provides critSource', UM, '            provides: [.critSource],     // v2.1 A7a (CL-91)', '            // provides removed', [CAT]),
 ('E2 Hemorrhage ungated from critSource', UM, '            requires: [.bleedUnlocked, .critSource]', '            requires: [.bleedUnlocked]', [CAT]),
 ('E3 Frost Touch T3 ungated', UM, '            tierRequires: [3: [.polarVortex]]\n', '            tierRequires: [:]\n', [CAT]),
 ('E5 Polar Vortex no longer provides polarVortex', UM, '            provides: [.polarVortex],    // v2.1 A7a (CL-92): opens Frost Touch T3\n', '', [CAT]),
 ('E6 PV T4 grant moved to T5', UM, '            tierProvides: [4: [.glacialCondensation]],', '            tierProvides: [5: [.glacialCondensation]],', [CAT]),
 ('E7 Warp Shot unblocked', UM, '            requires: [.voidUnlocked],\n            blockedBy: [.glacialCondensation]   // v2.1 A7a (CL-93): pellets only\n        ))\n\n        // v2.1 A6: primary-shot scoped',
  '            requires: [.voidUnlocked]\n        ))\n\n        // v2.1 A6: primary-shot scoped', [CAT]),
 ('E8 Gravity Well unblocked', UM, '            blockedBy: [.glacialCondensation]   // v2.1 A7a (CL-93): the icicle leaves no well (Q3)\n', '', [CAT]),
 ('E9 Riftline unblocked', UM, "            blockedBy: [.glacialCondensation]   // v2.1 A7a (CL-93): the icicle doesn't pierce\n", '', [CAT]),
 ('E10 Mirror Edge unblocked', UM, '            requires: [.voidUnlocked],   // v2.1 A6 (CL-82)\n            blockedBy: [.glacialCondensation]   // v2.1 A7a (CL-93): pellets only\n', '            requires: [.voidUnlocked]   // v2.1 A6 (CL-82)\n', [CAT]),
 ('E11 Fracture Shot unblocked', UM, '            provides: [.pelletEffect],          // v2.1 A7a (CL-93, symmetric)\n            blockedBy: [.glacialCondensation]   // v2.1 A7a (CL-93): pellets only\n', '            provides: [.pelletEffect]          // v2.1 A7a (CL-93, symmetric)\n', [CAT]),
 ('E12 Erasure blocked too', UM, '            requires: [.voidUnlocked]   // v2.1 A6 (CL-82): gated like every capstone', '            requires: [.voidUnlocked],   // v2.1 A6 (CL-82): gated like every capstone\n            blockedBy: [.glacialCondensation]', [CAT]),
 ('Y1 CC-1: Polar Vortex T4 no longer closes on a pellet card', UM, '            tierProvides: [4: [.glacialCondensation]],\n            tierBlockedBy: [4: [.pelletEffect]]', '            tierProvides: [4: [.glacialCondensation]]', [CAT]),
 ('Y2 CC-1: Warp Shot stops granting pelletEffect', UM, '            provides: [.pelletEffect],          // v2.1 A7a (CL-93, symmetric)\n            requires: [.voidUnlocked],\n            blockedBy: [.glacialCondensation]   // v2.1 A7a (CL-93): pellets only\n        ))\n\n        // v2.1 A6: primary-shot scoped',
  '            requires: [.voidUnlocked],\n            blockedBy: [.glacialCondensation]   // v2.1 A7a (CL-93): pellets only\n        ))\n\n        // v2.1 A6: primary-shot scoped', [CAT]),
 ('Y3 CC-1: Gravity Well stops granting pelletEffect', UM, '            provides: [.voidWell, .pelletEffect],', '            provides: [.voidWell],', [CAT]),
 ('Y4 CC-1: Fracture Shot stops granting pelletEffect', UM, '            apply: { stats in stats.splitCount = 2 },\n            provides: [.pelletEffect],', '            apply: { stats in stats.splitCount = 2 },', [CAT]),
 ('Y6 CC-1: Riftline stops granting pelletEffect', UM, "            provides: [.pelletEffect],          // v2.1 A7a (CL-93, symmetric)\n            requires: [.voidUnlocked],\n            blockedBy: [.glacialCondensation]   // v2.1 A7a (CL-93): the icicle doesn't pierce", "            requires: [.voidUnlocked],\n            blockedBy: [.glacialCondensation]   // v2.1 A7a (CL-93): the icicle doesn't pierce", [CAT]),
 ('Y7 CC-1: Mirror Edge stops granting pelletEffect', UM, '            provides: [.pelletEffect],   // v2.1 A7a (CL-93, symmetric)\n            requires: [.voidUnlocked],   // v2.1 A6 (CL-82)', '            requires: [.voidUnlocked],   // v2.1 A6 (CL-82)', [CAT]),
 ('Y5 CC-1: T4 closed at T5 instead', UM, '            tierBlockedBy: [4: [.pelletEffect]]', '            tierBlockedBy: [5: [.pelletEffect]]', [CAT]),
 # --- F2: the scheduled seats obey the same-level exclusion ---
 ('L1 guarantee re-seats a capstone taken this level-up', UM, '            if takenAt(level).contains(cap.id) { continue }\n', '', [CAT]),
 ('L2 panda re-seated after being taken this level-up', UM, '           !takenAt(level).contains(panda.id),          // corrective F2: not re-seated by a reroll\n', '', [CAT]),
 # --- F3: the Reviewer's five production mutations, verbatim in intent ---
 ('F3A capstone guarantee cadence % 2 → % 3', UM, 'for (i, cap) in inProgress.enumerated() where (level + i) % 2 == 0 {', 'for (i, cap) in inProgress.enumerated() where (level + i) % 3 == 0 {', [CAT]),
 ('F3B Panda schedule on odd levels', UM, '              (level - pandaActivationLevel) % 2 == 0 else { return nil }', '              level % 2 == 1 else { return nil }', [CAT]),
 ('F3B2 Panda schedule offset by one', UM, '              (level - pandaActivationLevel) % 2 == 0 else { return nil }', '              (level - pandaActivationLevel) % 2 == 1 else { return nil }', [CAT]),
 ('F3C reset no longer clears capabilities', UM, '        pickedCardIDs.removeAll()\n        capabilities.removeAll()\n', '        pickedCardIDs.removeAll()\n', [CAT]),
 ('F3D recordCardOffered is a no-op', CM, '    func recordCardOffered(_ id: String) {\n        insert(id, forKey: Keys.cardsOffered)', '    func recordCardOffered(_ id: String) {\n        _ = id', [CAT]),
 ('F3D2 recordDiscovered is a no-op', UM, '        for card in cards { CodexManager.shared.recordCardOffered(card.id) }', '        _ = cards', [CAT]),
 ('F3E scene: level 0 into the level-up draw', GS, '        showCardSelection(upgradeManager.drawCards(count: 3, level: player.currentLevel))', '        showCardSelection(upgradeManager.drawCards(count: 3, level: 0))', [CAT]),
 ('F3E2 scene: level 0 into the acquisition', GS, '        guard upgradeManager.acquire(card, stats: playerStats, level: player.currentLevel) else { return }', '        guard upgradeManager.acquire(card, stats: playerStats, level: 0) else { return }', [CAT]),
 ('F3E3 scene: level 0 into the revalidation', GS, '                                                           atLevel: player.currentLevel).map { $0.id })', '                                                           atLevel: 0).map { $0.id })', [CAT]),
 ('F3E4 scene: level 0 into the reroll', GS, 'self.upgradeManager.drawCards(count: spreadSize, level: self.player.currentLevel)', 'self.upgradeManager.drawCards(count: spreadSize, level: 0)', [CAT]),
 # --- the seeded RNG seam ---
 ('R1 palette ignores the seed', UM, '        activeFamilies = Set(candidates.shuffled(using: &rng).prefix(cap))', '        activeFamilies = Set(candidates.shuffled().prefix(cap))', [CAT]),
 ('R2 spread shuffle ignores the seed', UM, '            let pool = available.shuffled(using: &rng)\n', '            let pool = available.shuffled()\n', [CAT]),
 ('R3 Panda roll ignores the seed', UM, '        pandaEligible = CGFloat.random(in: 0..<1, using: &rng) < GameConfig.Panda.eligibilityChance', '        pandaEligible = CGFloat.random(in: 0..<1) < GameConfig.Panda.eligibilityChance', [CAT]),
 ('R4 bonus pick ignores the seed', UM, '        return (fresh.isEmpty ? available : fresh).randomElement(using: &rng)', '        return (fresh.isEmpty ? available : fresh).randomElement()', [CAT]),
 ('R4b opening bonus ignores the seed', UM, '                let bonus = (unseen.isEmpty ? signatures : unseen).randomElement(using: &rng)', '                let bonus = (unseen.isEmpty ? signatures : unseen).randomElement()', [CAT]),
 ('R5 seed ignored entirely', UM, '        init(seed: UInt64?) { state = seed }', '        init(seed: UInt64?) { state = nil }', [CAT]),
 ('R6 seeded generator constant', UM, '            return z ^ (z >> 31)', '            return 42', [CAT]),
 # --- Codex (CL-102) ---
 ('C1 tally counts the raw stored set', UM, '            discovered: stored.intersection(live).count,', '            discovered: stored.count,', [CAT]),
 ('C2 tally: retired counted as unknown', UM, '            retired: stored.filter { retiredCardIDs[$0] != nil && !live.contains($0) }.sorted(),\n            unknown: stored.filter { retiredCardIDs[$0] == nil && !live.contains($0) }.sorted())',
  '            retired: [],\n            unknown: stored.filter { !live.contains($0) }.sorted())', [CAT]),
 ('C3 registry loses Mass Tax', UM, '        "v16_mass_tax":       "A6 Void (Mass Tax)",\n', '', [CAT]),
 ('C4 catalogIDs drops the secret card', UM, '    static var catalogIDs: [String] { buildCardPool().map { $0.id } }', '    static var catalogIDs: [String] { buildCardPool().filter { !$0.isSecret }.map { $0.id } }', [CAT]),
 ('C5 total counts the stored set', UM, '            total: live.count,', '            total: stored.count,', [CAT]),
 # --- scene wiring ---
 ('W1 random opener no longer records grants', GS, '            upgradeManager.recordDiscovered([card])\n', '', [CAT]),
 ('W2 random opener records BEFORE granting', GS, '            guard upgradeManager.acquire(card, stats: playerStats, level: player.currentLevel) else { break }\n            // v2.1 A7a (CL-102): a granted card is in your build, so the Codex\n            // counts it as discovered — it never passed through a spread.\n            upgradeManager.recordDiscovered([card])',
  '            upgradeManager.recordDiscovered([card])\n            guard upgradeManager.acquire(card, stats: playerStats, level: player.currentLevel) else { break }', [CAT]),
 ('W3 DEBUG summary back to the raw count', CM, '            liveIDs: UpgradeManager.catalogIDs)', '            liveIDs: defaults.stringArray(forKey: Keys.cardsOffered) ?? [])', [CAT]),
 ('W4 a second drawBonusCard caller appears', GS, '        guard let bonus = upgradeManager.drawBonusCard(excluding: displayedCards.map { $0.card }) else { return }',
  '        guard let bonus = upgradeManager.drawBonusCard(excluding: displayedCards.map { $0.card }) ?? upgradeManager.drawBonusCard(excluding: []) else { return }', [CAT]),
 ('W5 spreads no longer recorded as discovered', GS, '        upgradeManager.recordDiscovered(cards)\n', '', [CAT]),
 # --- the approved copy ---
 ('Q1 Everglow T5 back to 15s', UM, '"Everglow: erupt for 500% ATK every 20s"', '"Everglow: erupt for 500% ATK every 15s"', [CAT]),
 # Re-pointed in A7b S7 (its contract is unchanged: an edit to Permafrost's copy fails CP4).
 # Permafrost's pinned copy is now the approved G2-1 face, so the anchor moves to it.
 ('Q2 Permafrost copy touched (anchor re-pointed in A7b S7 to the approved G2-1 face)', UM, 'description: "Hits deal +25% to slowed enemies",', 'description: "Direct hits on slowed enemies take +25% damage",', [CAT]),
 ('Q3 Skybeam detail loses its boss sentence', UM, ' Bosses and mini-bosses take half Skybeam damage and half the +35%."', '"', [CAT]),
 ('Q4 a new face overflow (Rapid Fire)', UM, 'description: "+11% attack speed"', 'description: "+11% attack speed, which makes every single shot of yours come out faster than before"', [CAT]),
 ('Q5 Thornwall synergy line reverted', UM, '"Reflect 150% of contact damage; bosses take half"', '"Enemies that touch you take 150% of the hit back"', [CAT, GUARD]),
 ('Q6 Polar Vortex detail loses the mutual-exclusion sentence', UM, "T4: the icicle (200% damage) replaces your shot; Erasure's Echo stops. T4 is mutually exclusive with Warp Shot, Gravity Well, Mirror Edge, Fracture Shot and Riftline: whichever side you own first blocks the other.",
  "T4: the icicle (200% damage) replaces your shot, so Warp Shot, Gravity Well, Mirror Edge, Fracture Shot, Riftline's pierce and Erasure's Echo stop working, and those cards (not Erasure) stop being offered.", [CAT]),
 # --- F4: generator output completeness (the Reviewer's two, plus neighbours) ---
 ('G1 Atlas renders 79 cards but reports 80', ATLAS, "        body = ''.join(card_html(c, color) for c in group)", "        body = ''.join(card_html(c, color) for c in (group[:-1] if tag == 'fire' else group))", ['atlas']),
 ('G2 Atlas renders one card twice', ATLAS, "        body = ''.join(card_html(c, color) for c in group)", "        body = ''.join(card_html(c, color) for c in (group + group[:1] if tag == 'fire' else group))", ['atlas']),
 ('G3 Atlas drops the secret card', ATLAS, '''                 f'<div class="cards"><article class="card secret" style="--fc:#775544" id="{panda["id"]}">\'''', '''                 f'<div class="cards"><article class="card secret" style="--fc:#775544">\'''', ['atlas']),
 ('G4 canon omits every per-card section', CANON, "        for c in group:\n            o.append(card_block(c, E[c['id']], names))\n            o.append('')", '        pass', ['canon']),
 ('G5 canon loses a sidecar field on every card', CANON, "           f'- **Tell:** {e[\"tell\"]}']", "           ]", ['canon']),
 ('G6 canon omits the synergy entries', CANON, "                o.append(f'- **×{s[\"threshold\"]} {s[\"title\"]}** — ' + ' · '.join(extra))", '                pass', ['canon']),
 # --- the Atlas header (A7a corrective 10): display-only provenance, no Git commit ---
 ('AH1 Atlas header back to the commit claim (source: UpgradeManager @ HEAD)', ATLAS,
  ["    source = PROVENANCE.format(EXPECT['total'])\n", '<span class="provenance">{esc(source)}</span><span>generated {today}</span></div>'],
  ["    source = PROVENANCE.format(EXPECT['total'])\n    commit = subprocess.run(['git','rev-parse','--short','HEAD'], capture_output=True,\n"
   "                            text=True, cwd=ROOT).stdout.strip() or '?'\n", '<span>source: UpgradeManager @ <b>{commit}</b> · {today}</span></div>'], ['atlas']),
 ('AH2 Atlas header: `@ HEAD` beside the source', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span class="provenance">{esc(source)} @ HEAD</span>', ['atlas']),
 ('AH3 Atlas header: a stale commit beside the date', ATLAS, '<span>generated {today}</span>', '<span>generated {today} from 3630183</span>', ['atlas']),
 ('AH4 Atlas header: the card count off by one', ATLAS, "    source = PROVENANCE.format(EXPECT['total'])", "    source = PROVENANCE.format(EXPECT['total'] - 1)", ['atlas']),
 ('AH5 Atlas header: the draftable count shown as the card count', ATLAS, "    source = PROVENANCE.format(EXPECT['total'])", "    source = PROVENANCE.format(EXPECT['draftable'])", ['atlas']),
 ('AH6 Atlas header: the source misnamed', ATLAS, "PROVENANCE = 'Source: compiled runtime catalog · {} cards'", "PROVENANCE = 'Source: UpgradeManager.swift · {} cards'", ['atlas']),
 ('AH7 Atlas header: the provenance dropped', ATLAS, '<span class="provenance">{esc(source)}</span>', '', ['atlas']),
 ('AH8 Atlas header: the provenance printed twice', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span class="provenance">{esc(source)}</span><span class="provenance">{esc(source)}</span>', ['atlas']),
 ('AH9 Atlas page footer claims a commit', ATLAS, 'Generated by <code>tools/generate-card-atlas.py</code> from the compiled', 'Generated by <code>tools/generate-card-atlas.py</code> @ HEAD from the compiled', ['atlas']),
 # --- the Atlas provenance model (A7a corrective 11): parsed, decoded, visible text ---
 # Git/commit/hash claims, whatever the markup (AH10–AH18; the Reviewer's F1 reproductions are AH10 and AH13):
 ('AH10 Atlas: an uppercase 40-char commit hash beside the date (Reviewer F1)', ATLAS, '<span>generated {today}</span>', '<span>generated {today} 3630183ABCDEF0123456789ABCDEF0123456789A</span>', ['atlas']),
 ('AH11 Atlas: a lowercase 40-char commit hash beside the date', ATLAS, '<span>generated {today}</span>', '<span>generated {today} 3630183abcdef0123456789abcdef0123456789a</span>', ['atlas']),
 ('AH12 Atlas: a short 7-char hash (letters only) beside the date', ATLAS, '<span>generated {today}</span>', '<span>generated {today} deadbee</span>', ['atlas']),
 ('AH13 Atlas: `commit @ HEAD` in a footer with altered attributes (Reviewer F1)', ATLAS, '<footer class="page">Generated by',
  '<footer id="colophon" data-x="1" class="page">commit @ HEAD. Generated by', ['atlas']),
 ('AH14 Atlas: an entity-encoded claim (c&#111;mmit&nbsp;&#64; h&#69;AD)', ATLAS, '<span>generated {today}</span>', '<span>generated {today} c&#111;mmit&nbsp;&#64;&#x20;h&#69;AD</span>', ['atlas']),
 ('AH15 Atlas: a hash split by a zero-width space and inline markup', ATLAS, '<span>generated {today}</span>', '<span>generated {today} 36&#8203;30<b>18</b>3</span>', ['atlas']),
 ('AH16 Atlas: HEAD split across inline markup', ATLAS, '<span>generated {today}</span>', '<span>generated {today} from H<b>E</b>AD</span>', ['atlas']),
 ('AH17 Atlas: a commit claim in a tooltip', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span class="provenance" title="commit 3630183">{esc(source)}</span>', ['atlas']),
 ('AH18 Atlas: old Git-source phrasing ("via git")', ATLAS, '<span>generated {today}</span>', '<span>generated {today} via git</span>', ['atlas']),
 # Exactly one visible source label, counted by decoded text, not class (AH19–AH24; the Reviewer's F2 reproduction is AH19):
 ('AH19 Atlas: the approved label duplicated in a plain span (Reviewer F2)', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span class="provenance">{esc(source)}</span><span>{esc(source)}</span>', ['atlas']),
 ('AH20 Atlas: the approved label duplicated with another class, in the page footer', ATLAS, '<footer class="page">Generated by', '<footer class="page"><span class="credit">{esc(source)}</span> Generated by', ['atlas']),
 ('AH21 Atlas: an upper-case copy of the label in a div', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span class="provenance">{esc(source)}</span><div class="aside">{esc(source).upper()}</div>', ['atlas']),
 ('AH22 Atlas: the only label hidden', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span class="provenance" hidden>{esc(source)}</span>', ['atlas']),
 # (AH23, a `hidden` second copy of the label, is now the positive flow `atlas-hidden-copy`: hidden content is not a claim, corrective 12.)
 ('AH24 Atlas: the label with extra text in its element', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span class="provenance">{esc(source)} (approx)</span>', ['atlas']),
 # Exactly one real generated date (AH25–AH26):
 ('AH25 Atlas: a second date value', ATLAS, '<span>generated {today}</span>', '<span>generated {today}</span><span>Sep 01 2026</span>', ['atlas']),
 ('AH26 Atlas: an impossible generated date', ATLAS, '<span>generated {today}</span>', '<span>generated Feb 30 2026</span>', ['atlas']),
 # --- the Atlas provenance TREE model (A7a corrective 12): visibility, readings, channels ---
 # The Reviewer's reproductions (freeze 12):
 ('AH27 Atlas: the label inside a hidden child (Reviewer 1)', ATLAS, '<span class="provenance">{esc(source)}</span>', '<div><span hidden>{esc(source)}</span></div>', ['atlas']),
 ('AH28 Atlas: a separate sibling GIT beside the date (Reviewer 2)', ATLAS, '<span>generated {today}</span>', '<span>generated {today}</span><span>GIT</span>', ['atlas']),
 ('AH29 Atlas: a separate sibling HEAD beside the date (Reviewer 3)', ATLAS, '<span>generated {today}</span>', '<span>generated {today}</span><span>HEAD</span>', ['atlas']),
 ('AH30 Atlas: co&#x034f;mmit (a combining grapheme joiner inside; Reviewer 4)', ATLAS, '<span>generated {today}</span>', '<span>generated {today}</span><span>co&#x034f;mmit</span>', ['atlas']),
 ('AH31 Atlas: DE&#xFE0F;ADBEE (a variation selector inside; Reviewer 5)', ATLAS, '<span>generated {today}</span>', '<span>generated {today}</span><span>DE&#xFE0F;ADBEE</span>', ['atlas']),
 ('AH32 Atlas: a duplicate source label in a title attribute (Reviewer 6)', ATLAS, '<span>generated {today}</span>', '<span title="{esc(source)}">generated {today}</span>', ['atlas']),
 ('AH33 Atlas: a duplicate generated date in a title attribute (Reviewer 7)', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span class="provenance" title="generated {today}">{esc(source)}</span>', ['atlas']),
 # Visibility: every supported hider, and "painted but hidden from assistive tech":
 ('AH34 Atlas: the only label aria-hidden', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span aria-hidden="true">{esc(source)}</span>', ['atlas']),
 ('AH35 Atlas: a painted (aria-hidden) duplicate of the label', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span class="provenance">{esc(source)}</span><span aria-hidden="true">{esc(source)}</span>', ['atlas']),
 ('AH36 Atlas: the only label display:none !important', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span style="display: none !important">{esc(source)}</span>', ['atlas']),
 ('AH37 Atlas: the only label under a visibility:hidden ancestor', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span style="visibility:hidden"><b>{esc(source)}</b></span>', ['atlas']),
 ('AH38 Atlas: the only label at opacity 0', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span style="opacity:0">{esc(source)}</span>', ['atlas']),
 ('AH39 Atlas: the stylesheet hides the provenance', 'tools/card-atlas.css', RE(r'\A'), '.provenance { display:none; }\n', ['atlas']),
 # Readings: words split or glued by markup, and claims split across it:
 ('AH40 Atlas: HEAD split across adjacent inline elements', ATLAS, '<span>generated {today}</span>', '<span>generated {today}</span><span>from <b>HE</b><b>AD</b></span>', ['atlas']),
 ('AH41 Atlas: GIT glued to the date by inline elements', ATLAS, '<span>generated {today}</span>', '<span>generated {today}<b>G</b><b>IT</b></span>', ['atlas']),
 ('AH42 Atlas: a duplicate label split across generic spans', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span class="provenance">{esc(source)}</span><span>Sou<span>rce: comp</span>iled runtime catalog · {EXPECT["total"]} cards</span>', ['atlas']),
 ('AH43 Atlas: a duplicate label with a zero-width space inside', ATLAS, '<span class="provenance">{esc(source)}</span>', '<span class="provenance">{esc(source)}</span><span>So&#x200B;urce: compiled runtime catalog · {EXPECT["total"]} cards</span>', ['atlas']),
 ('AH44 Atlas: HEAD reassembled around a hidden element', ATLAS, '<span>generated {today}</span>', '<span>generated {today}</span><span>H<span hidden>x</span>EAD</span>', ['atlas']),
 # Channels: accessibility attributes count; Git claims fail even when hidden:
 ('AH45 Atlas: a duplicate source label in aria-label', ATLAS, '<span>generated {today}</span>', '<span aria-label="{esc(source)}">generated {today}</span>', ['atlas']),
 ('AH46 Atlas: a second date in an image alt', ATLAS, '<span>generated {today}</span>', '<span>generated {today}</span><img alt="Sep 01 2026">', ['atlas']),
 ('AH47 Atlas: a hidden commit claim', ATLAS, '<span>generated {today}</span>', '<span>generated {today}</span><span hidden>commit 3630183</span>', ['atlas']),
 # Normalisation and hash length:
 ('AH48 Atlas: a full-width ｃｏｍｍｉｔ', ATLAS, '<span>generated {today}</span>', '<span>generated {today}</span><span>ｃｏｍｍｉｔ</span>', ['atlas']),
 ('AH49 Atlas: a 64-hex (SHA-256) hash', ATLAS, '<span>generated {today}</span>', '<span>generated {today}</span><span>abababababababababababababababababababababababababababababababab</span>', ['atlas']),
 # --- F4 corrective 4: canon content identity (the Reviewer's two, verbatim, plus neighbours) ---
 ('G7 canon drops tier-copy emission (23 cards lose their ladders; 80 sections remain)', CANON,
  "            lines.append('- **Copy:** ' + ' · '.join(f'T{i+1} \"{t}\"' for i, t in enumerate(tiers)))", '            pass', ['canon']),
 ('G8 canon: every ×7 ladder row replaced by another ×3 row (21 rows remain)', CANON,
  "            for s in cat['synergies'][k]:\n                e = E[f'syn:{name}_{s[\"threshold\"]}']\n                o.append(f'| {s[\"threshold\"]}",
  "            for s in [x if x['threshold'] != 7 else cat['synergies'][k][0] for x in cat['synergies'][k]]:\n                e = E[f'syn:{name}_{s[\"threshold\"]}']\n                o.append(f'| {s[\"threshold\"]}", ['canon']),
 ('G9 canon drops the face line', CANON, "            lines.append(f'- **Face:** \"{c[\"description\"]}\"')", '            pass', ['canon']),
 ('G10 canon drops the MORE detail', CANON, "            lines.append(f'- **MORE detail:** \"{c[\"detail\"]}\"')", '            pass', ['canon']),
 ('G11 canon: every ×7 synergy entry replaced by another ×3 entry', CANON,
  "            for s in cat['synergies'][k]:\n                e = E[f'syn:{name}_{s[\"threshold\"]}']\n                extra = [",
  "            for s in [x if x['threshold'] != 7 else cat['synergies'][k][0] for x in cat['synergies'][k]]:\n                e = E[f'syn:{name}_{s[\"threshold\"]}']\n                extra = [", ['canon']),
 ('G12 canon prints the wrong sidecar value (Hit class ← targeting)', CANON, "           f'- **Hit class:** {e[\"hitClass\"]}',", "           f'- **Hit class:** {e[\"targeting\"]}',", ['canon']),
 ('G13 canon drops a retired id', CANON, "    for rid, why in sorted(cat['retired'].items()):", "    for rid, why in sorted(cat['retired'].items())[1:]:", ['canon']),
 ('G14 the committed canon loses one tier line', CANON_DOC, '- **Copy:** T1 "Iceburst: chilled foes that die burst into 3 ice shards"', '- **Copy:**', ['canon-file']),
 # --- F4a (corrective 5): synergy sidecar fields, by content identity ---
 ('H1 canon: all synergy sensitivities dropped (generation)', CANON, "f'sensitivities: {e[\"sensitivities\"]}' if e['sensitivities'] else ''", "''", ['canon']),
 ('H1b the committed canon: all synergy sensitivities stripped (--check)', CANON_DOC, RE(r'(^- \*\*×[0-9] [^\n]*?) · sensitivities: [^\n]*$'), r'\1', ['canon-file']),
 ('H1c the sidecar: every synergy sensitivity emptied (input validation)', SIDECAR, RE(r'("syn:[^"]+": \{[^{}]*?"sensitivities": )"[^"]*"'), r'\1""', ['canon']),
 ('H2 canon: all synergy rulings dropped (generation)', CANON, "('rulings: ' + ', '.join(e['rulings'])) if e['rulings'] else ''", "''", ['canon']),
 ('H2b the committed canon: all synergy rulings stripped (--check)', CANON_DOC, RE(r'(^- \*\*×[0-9] [^\n]*?) · rulings: [^·\n]*'), r'\1', ['canon-file']),
 ('H3 the committed canon: one synergy loses its sensitivity (--check)', CANON_DOC,
  RE(r'(^- \*\*×3 Spreading Flame\*\* — [^\n]*?) · sensitivities: [^\n]*$'), r'\1', ['canon-file']),
 ('H3b the sidecar: one synergy sensitivity emptied (input validation)', SIDECAR, RE(r'("syn:Fire_3": \{[^{}]*?"sensitivities": )"[^"]*"'), r'\1""', ['canon']),
 ('H4 the committed canon: a sensitivity moved to the wrong synergy (--check)', CANON_DOC,
  RE(r'(^- \*\*×3 Spreading Flame\*\* — [^\n]*?)( · sensitivities: [^\n]*)$(.*?^- \*\*×5 Wildfire Heart\*\* — [^\n]*?) · sensitivities: [^\n]*$'),
  r'\1\3\2', ['canon-file']),
 ('H4b canon: synergy entries drawn from the wrong identity (generation)', CANON,
  "                e = E[f'syn:{name}_{s[\"threshold\"]}']\n                extra = [",
  "                e = E[f'syn:{name}_{3 if s[\"threshold\"] != 3 else 5}']\n                extra = [", ['canon']),
 # --- F4b (corrective 5): Cross-cutting rules, and the other structured sections ---
 ('X1 canon: the Cross-cutting heading kept, all six subsections gone (generation)', CANON, "    for sec in side['crosscutting']:", "    for sec in []:", ['canon']),
 ('X1b the committed canon: all subsections and rule items removed under the heading (--check)', CANON_DOC,
  RE(r'(^## Cross-cutting rules\n\n).*?(?=^## Fire)'), r'\1', ['canon-file']),
 ('X2 the committed canon: one subsection removed (--check)', CANON_DOC, RE(r'^### Colour and feel language\n.*?(?=^## Fire)'), '', ['canon-file']),
 ('X3 the committed canon: one rule item removed (--check)', CANON_DOC, RE(r'^- \*\*Purple = danger\*\*[^\n]*\n'), '', ['canon-file']),
 ('X4 the committed canon: one subsection duplicated while another is omitted (--check)', CANON_DOC,
  RE(r'(^### Taxonomy\n.*?)(^### Drafting and eligibility\n.*?)(?=^### Damage, hits and kills)'), r'\1\1', ['canon-file']),
 ('X5 the committed canon: a rule item moved under the wrong subsection (--check)', CANON_DOC,
  RE(r'^(- Tier percentages are totals[^\n]*\n)(.*?^### Colour and feel language\n\n)'), r'\2\1', ['canon-file']),
 ('X6 canon: a tree thesis printed from the wrong tree (generation)', CANON, "        th = side['trees'][name]", "        th = side['trees']['Neutral']", ['canon']),
 ('X7 the committed canon: the travel-family index loses an entry (--check)', CANON_DOC, RE(r'(^- \*\*passive stat\*\* \([0-9]+\): )[^,]+, '), r'\1', ['canon-file']),
 ('X8 the sidecar: one cross-cutting subsection emptied (input validation)', SIDECAR, RE(r'("title": "Colour and feel language",\s*"body": \[).*?(\])'), r'\1\2', ['canon']),
 ('X9 the committed canon: the summary counts altered (--check)', CANON_DOC, '· 21 synergy tiers · 8 retired ids.', '· 21 synergy tiers · 7 retired ids.', ['canon-file']),
 # --- F4b (corrective 6): strict model equality — surplus, orphan and conflicting records ---
 ('Z1 canon: all 23 rule items ALSO printed under the parent heading, 46 in all (Reviewer F4b-1, generation)', CANON,
  "    o.append('## Cross-cutting rules\\n')\n", "    o.append('## Cross-cutting rules\\n')\n    o += [f'- {b}' for sec in side['crosscutting'] for b in sec['body']] + ['']\n", ['canon']),
 ('Z2 the committed canon: one orphan rule before any subsection', CANON_DOC,
  RE(r'(^## Cross-cutting rules\n\n)(### Taxonomy\n\n)(- Seven affinity trees[^\n]*\n)'), r'\1\3\n\2', ['canon-file']),
 ('Z3 the committed canon: a valid rule duplicated under the same subsection', CANON_DOC, RE(r'^(- Seven affinity trees[^\n]*\n)'), r'\1\1', ['canon-file']),
 ('Z4 the committed canon: a valid rule duplicated under a different subsection', CANON_DOC,
  RE(r'^(- Seven affinity trees[^\n]*\n)(.*?^### Colour and feel language\n\n)'), r'\1\2\1', ['canon-file']),
 ('Z5 the committed canon: an unknown extra rule', CANON_DOC, RE(r'(^### Colour and feel language\n\n)'), r'\1- An unknown extra rule.\n', ['canon-file']),
 ('Z5b the committed canon: stray prose inside the rules area', CANON_DOC, RE(r'(^### Taxonomy\n\n)'), r'\1Some stray prose that is not a rule.\n', ['canon-file']),
 ('Z6 canon: 18 extra travel-family rows naming not_real (Reviewer F4b-2, generation)', CANON,
  "    for f in FAMILIES:\n        if index[f]:", "    for f in FAMILIES:\n        o.append(f'- **{f}** (1): Not Real (`not_real`)')\n        if index[f]:", ['canon']),
 ('Z7 the committed canon: one extra index row naming not_real', CANON_DOC,
  RE(r'(^- \*\*draft rule\*\* \([0-9]+\): [^\n]*\n)'), r'\1- **summon** (1): Not Real (`not_real`)\n', ['canon-file']),
 ('Z8 the committed canon: a contradictory second thesis (Reviewer F4b-3)', CANON_DOC,
  RE(r'(^\*\*Thesis:\*\* Burning and big booms[^\n]*\n)'), r'\1\n**Thesis:** Fire is secretly about ice. *(nobody)* · **9 cards.**\n', ['canon-file']),
 ('Z8b canon: every tree prints a second, contradictory thesis (generation)', CANON,
  "        o.append(f'**Thesis:** {th[\"thesis\"]} *({th[\"source\"]})* · **{len(group)} cards.**\\n')",
  "        o.append(f'**Thesis:** {th[\"thesis\"]} *({th[\"source\"]})* · **{len(group)} cards.**\\n')\n        o.append('**Thesis:** Something else entirely. *(nobody)* · **0 cards.**\\n')", ['canon']),
 ('Z9 the committed canon: a second summary claiming 900 cards (Reviewer F4b-4)', CANON_DOC,
  RE(r'(^\*\*80 cards = [^\n]*\n)'), r'\1\n**900 cards = 899 draftable + 1 secret** · 7 trees + Neutral · 7 signatures · 7 capstones · 21 synergy tiers · 8 retired ids.\n', ['canon-file']),
 ('Z10 the committed canon: a summary-like record inside a tree section', CANON_DOC,
  RE(r'(^## Chill\n\n)'), r'\1**900 cards = 899 draftable + 1 secret** · 7 trees + Neutral.\n\n', ['canon-file']),
 ('Z11 the committed canon: a card field line duplicated inside a card block', CANON_DOC,
  RE(r'(^#### Kindle · `fire_1`.*?)(^- \*\*Tell:\*\*[^\n]*\n)'), r'\1\2\2', ['canon-file']),
 ('Z12 the committed canon: a ladder row duplicated with conflicting content', CANON_DOC,
  RE(r'(^\| 3 \| Spreading Flame \|[^\n]*\n)'), r'\1| 3 | Spreading Flame | Something else | x | y | z |\n', ['canon-file']),
 ('Z13 the committed canon: an unexpected extra section', CANON_DOC, RE(r'\Z'), '\n## Extra notes\n\n- A surplus record.\n', ['canon-file']),
 ('Z14 the committed canon: an extra retired-id row', CANON_DOC, RE(r'(^\| `v18_needlepoint` \|[^\n]*\n)'), r'\1| `not_real` | nothing |\n', ['canon-file']),
 ('Z15 the committed canon: an extra contents link', CANON_DOC, RE(r'(^- \[Retired ids\]\(#retired-ids\)\n)'), r'\1- [Bonus](#bonus)\n', ['canon-file']),
 # --- provenance (A7a corrective 9): the source-input fingerprint exact, the date format-only ---
 # A stamp on the committed canon that isn't the recomputed fingerprint, exactly:
 ('FP1 the committed canon carries a wrong (well-formed) fingerprint', CANON_DOC, RE(FP_STAMP), r'\g<1>' + '0' * 64 + r'\2', ['canon-file']),
 ('FP2 the committed canon carries the fingerprint truncated to 16 hex', CANON_DOC, RE(r'(source-input fingerprint `sha256:[0-9a-f]{16})[0-9a-f]{48}(`)'), r'\1\2', ['canon-file']),
 ('FP3 the committed canon carries the right fingerprint in uppercase', CANON_DOC, RE(r'(source-input fingerprint `sha256:)([0-9a-f]{64})(`)'),
  lambda m: m.group(1) + m.group(2).upper() + m.group(3), ['canon-file']),
 ('FP4 the committed canon stamped `?`', CANON_DOC, RE(FP_STAMP), r'\1?\2', ['canon-file']),
 ('FP5 the committed canon with an empty fingerprint', CANON_DOC, RE(FP_STAMP), r'\1\2', ['canon-file']),
 ('FP6 the committed canon names only a Git commit (the freeze-9 stamp)', CANON_DOC,
  RE(r'^\*Generated by `tools/generate-ability-canon\.py` \(([A-Z][a-z]{2} [0-9]{2} [0-9]{4})\) from the compiled catalog and the hand-kept sidecar '
     r'`docs/v2\.1-ability-canon-sidecar\.json`; source-input fingerprint `sha256:[0-9a-f]{64}` \(the catalog, the sidecar, '
     r'`tools/catalog-expect\.json` and the generator; `--fingerprint` itemises it\)\. '),
  r'*Generated by `tools/generate-ability-canon.py` from the compiled catalog at `3630183` (\1) and the hand-kept sidecar `docs/v2.1-ability-canon-sidecar.json`. ',
  ['canon-file']),
 ('V3 the committed canon: generation date in the wrong format', CANON_DOC, RE(r'(generate-ability-canon\.py` \()[A-Z][a-z]{2} [0-9]{2} [0-9]{4}(\))'), r'\g<1>2026-09-27\2', ['canon-file']),
 # Generation, and the fingerprint's own guard (defence in depth):
 ('FP7 generation stamps a wrong fingerprint', CANON, '    fp = source_fingerprint(cat, side)\n', "    fp = '0' * 64\n", ['canon']),
 ('FP8 the fingerprint function returns `?`', CANON, '    return hashlib.sha256(manifest.encode()).hexdigest()', "    return '?'", ['canon']),
 ('FP9 the fingerprint function returns a 16-hex digest', CANON, '    return hashlib.sha256(manifest.encode()).hexdigest()', '    return hashlib.sha256(manifest.encode()).hexdigest()[:16]', ['canon']),
 # Coverage: every input is in the fingerprint and the stamp is compared exactly. Each
 # `detects-*` check regenerates the canon, changes ONE input where the canon can't
 # show it, and passes only if --check then fails on the fingerprint alone.
 ('FP10 --check accepts any well-formed fingerprint', CANON, "re.escape(fp) + '` '", "'[0-9a-f]{64}' + '` '", ['detects-sidecar']),
 ('FP11 the fingerprint omits the sidecar', CANON, "        ('sidecar', hashlib.sha256(_canonical_json(side)).hexdigest()),\n", '', ['detects-sidecar']),
 ('FP12 the fingerprint omits the compiled catalog', CANON, "        ('catalog', hashlib.sha256(_canonical_json(cat)).hexdigest()),\n", '', ['detects-catalog']),
 ('FP13 the fingerprint omits tools/catalog-expect.json', CANON, "        ('expect', hashlib.sha256(_canonical_json(json.load(open(EXPECT)))).hexdigest()),\n", '', ['detects-expect']),
 ('FP14 the fingerprint omits the generator', CANON, "        ('generator', hashlib.sha256(open(GENERATOR, 'rb').read()).hexdigest()),\n", '', ['detects-generator']),
 # Git (a throwaway repo): a source change committed WITHOUT regenerating the canon.
 ('FP15 Git: a source change committed alone, the canon not regenerated', None, None, None, ['git-stale']),
 # === v2.1 A7b (docs/v2.1-abilities-a7b-return.md). Each seam adds its own. ===
 # --- S0a: tooling. The suite copies Nodes/ and Utils/; the four hand mirrors
 # (Growth, Chill, BossClass, Erasure) are extracted; the guard WR reads code only.
 ('B7-S0a-1 guard: the scene is read raw (comments no longer removed)', 'tools/guard-harness/main.swift',
  '    let src = SwiftSource.code(raw)\n', '    let src = raw\n', [GUARD]),
 ('B7-S0a-2 the REAL GameConfig.Chill reaches the harnesses (Permafrost 0.25 -> 0.30)', 'Sparkforge/Config/GameConfig.swift',
  'static let permafrostBonus: CGFloat = 0.25', 'static let permafrostBonus: CGFloat = 0.30', [CHILL]),
 ('B7-S0a-3 the REAL GameConfig.BossClass reaches the harnesses (damageScale 0.5 -> 0.6)', 'Sparkforge/Config/GameConfig.swift',
  'static let damageScale: CGFloat = 0.5   // capstone ability damage at 50%',
  'static let damageScale: CGFloat = 0.6   // capstone ability damage at 50%', ['void']),
 ('B7-S0a-4 the suite mutates Sparkforge/Nodes (EnemyNode: a stun stops ending fear)', 'Sparkforge/Nodes/EnemyNode.swift',
  '        stunHold.stun(duration)\n        cancelFear()   // v2.1 A6 (CL-80): a stronger control ends fear\n',
  '        stunHold.stun(duration)\n', ['void']),   # re-pointed in A7b S5 (stunTimer -> stunHold)
 # --- S0b: the geometry harness baseline and the card-detail modal guard ---
 ('B7-S0b-1 geometry: resolve stops after one push', 'Sparkforge/Config/ArenaGeometry.swift',
  'for _ in 0..<4 {', 'for _ in 0..<1 {', ['geometry']),
 ('B7-S0b-2 geometry: the exact segment test ignores the corner radius', 'Sparkforge/Systems/MeleeSector.swift',
  'return gap < cornerRadius + margin', 'return gap < margin', ['geometry']),
 ('B7-S0b-3 geometry: the placement sampler keeps a rejected point', 'Sparkforge/Config/ArenaGeometry.swift',
  'if !geometry.isBlocked(last, margin: margin) { return last }', 'if true { return last }', ['geometry']),
 # re-pointed in A7b S10: Absolute Zero's line is now its approved G2-3 text; same contract
 ('B7-S0b-4 modal: a Chill synergy line grows past one line at 40 (Polar Vortex > 665pt)', UM,
  'effect: "Non-boss foes slow; shatters come easy")', 'effect: "Non-boss foes slow for everyone; shatters come easy")', [CAT]),
 ('B7-S0b-5 modal: the node rung spacing changes under the model', 'Sparkforge/Nodes/CardDetailNode.swift',
  '                y -= 5\n', '                y -= 6\n', [CAT]),
 # --- S1: the dormant runtime deletion (G3.1, CL-127b) ---
 ('B7-S1-1 a stun chance without Overload (the retired legacy path)', 'Sparkforge/Systems/PlayerStats.swift',
  'guard overloadOwned else { return 0 }', 'guard overloadOwned else { return 0.1 }', ['shock', CAT]),
 ('B7-S1-2 dormant Arc Wake state creeps back into the scene', GS,
  '    private var pendingSpikes: [(enemy: EnemyNode?, isBoss: Bool, timer: GameTimer, mark: SKNode)] = []\n',
  '    private var pendingSpikes: [(enemy: EnemyNode?, isBoss: Bool, timer: GameTimer, mark: SKNode)] = []\n    private var arcWakeDropTimer: TimeInterval = 0\n', [CAT]), # --- S2: debug seams announce themselves; the ledger; the carried scene-boundary hardening ---
 ('B7-S2-1 A4c F2 again: the Red Smile Shatter branch returns past both meters', GS,
  '                chargeRedSmileHitMeters(.shatter)\n', '', ['redsmile']),
 ('B7-S2-2 A4c F1 again: the Red Smile boss contact registers Erasure only', GS,
  'chargeRedSmileHitMeters(.boss)    // Apex AND Erasure (corrective F1)', 'erasureRegisterHit()', ['redsmile']),
 ('B7-S2-3 the contact helper stops handing Apex its method', GS,
  'contact.chargeHitMeters(apex: { apexRegisterAttack() }, erasure:', 'contact.chargeHitMeters(apex: { }, erasure:', ['redsmile']),
 ('B7-S2-4 the gun enemy hit stops charging The Hunter', GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n', '', ['redsmile']),
 ('B7-S2-5 the carried A5 miswiring: a snowman counts as a Repulse pin', GS,
  '&& RepulseFlight.isPin(isMiniBoss: other.isMiniBoss, isSnowman: other.isSnowman,', '&& RepulseFlight.isPin(isMiniBoss: other.isMiniBoss, isSnowman: false,', [GUARD]),
 ('B7-S2-6 the Repulse launch filter ignores the snowman', GS,
  'let launchable = RepulseFlight.isLaunchable(isMiniBoss: enemy.isMiniBoss, isSnowman: enemy.isSnowman)',
  'let launchable = RepulseFlight.isLaunchable(isMiniBoss: enemy.isMiniBoss, isSnowman: false)', [GUARD]),
 ('B7-S2-7 Ironhide counts snowmen', GS,
  'hittable: isHittable(enemy), snowman: enemy.isSnowman) {', 'hittable: isHittable(enemy), snowman: false) {', [GUARD]),
 ('B7-S2-8 the forced-card banner is never shown', GS,
  'if let forced = UpgradeManager.debugForcedCardID {', 'if let forced = UpgradeManager.debugForcedCardID, forced.isEmpty {', [CAT]),
 ('B7-S2-9 the Mote flag compiles into release again', 'Sparkforge/Config/GameConfig.swift',
  ['        #if DEBUG\n        /// Dev-only: skip the mastery gate', '        static let debugForceEntrance: Bool = false\n        #endif\n'],
  ['        /// Dev-only: skip the mastery gate', '        static let debugForceEntrance: Bool = false\n'], [CAT]),
 ('B7-S2-10 liveMax counts ended holes again', GS,
  'combatLedger.recordVoidWell(preset, live: voidWells.filter { $0.state.isLive }.count)', 'combatLedger.recordVoidWell(preset, live: voidWells.count)', ['void']), # --- pre-freeze corrective 1 (the internal review's surviving mutants R1–R11, now retained) ---
 # re-pointed in A7b S10: the sweep's Shatter is now ShatterRule's `if let shatter` block; same contract
 ('B7-S2-11 (R1) a Red Smile Shatter kill returns inline, past both meters (F2 in a one-line form)', GS,
  '                onEnemyKilled(at: enemy.position, xpValue: enemy.xpValue, enemy: enemy, source: .melee)\n            }\n            if killed || shatter.endsHit {',
  '                onEnemyKilled(at: enemy.position, xpValue: enemy.xpValue, enemy: enemy, source: .melee); return nil\n            }\n            if killed || shatter.endsHit {',
  ['redsmile']),
 ('B7-S2-12 (R2) a new one-line early exit after a landed Red Smile hit', GS,
  '        rollOverload(on: enemy)   // Overload: "Hits have a 20% chance to stun"\n',
  '        rollOverload(on: enemy)   // Overload: "Hits have a 20% chance to stun"\n        if enemy.isDying { return nil }\n', ['redsmile']),
 # re-pointed in A7b S8: the anchor moved with S8's code; the mutation's contract is unchanged.
 ('B7-S2-13 (R3) a lethal Red Smile boss hit returns before its charge', GS,
  '        bossNode.takeDirectHit(hit)   // A7b S8 (CL-114c); a sweep: the DEF dial applies\n        if !bossNode.isDead { applyBossAnomaly(bossNode) }',
  '        bossNode.takeDirectHit(hit)   // A7b S8 (CL-114c); a sweep: the DEF dial applies\n        if bossNode.isDead { return }\n        if !bossNode.isDead { applyBossAnomaly(bossNode) }', ['redsmile']),
 ('B7-S0b-6 (R4) the detail panel grows 20pt past its content', 'Sparkforge/Nodes/CardDetailNode.swift',
  'let panelH = contentHeight + Self.padTop + Self.padBottom', 'let panelH = contentHeight + Self.padTop + Self.padBottom + 20', [CAT]),
 ('B7-S0b-7 (R5) the ladder trailing 3pt moves INTO the rung loop (same token order)', 'Sparkforge/Nodes/CardDetailNode.swift',
  '                y -= 5\n            }\n            y -= 3\n', '                y -= 5\n                y -= 3\n            }\n', [CAT]),
 ('B7-S0b-8 (R6) the detail layout starts 12pt down', 'Sparkforge/Nodes/CardDetailNode.swift',
  '        var y: CGFloat = 0\n', '        var y: CGFloat = -12\n', [CAT]),
 ('B7-S0b-9 (R7) the sampler give-up fallback returns the rejected point unresolved', 'Sparkforge/Config/ArenaGeometry.swift',
  'return geometry.resolve(last, actorRadius: margin)', 'return last', ['geometry']),
 ('B7-S2-14 (R8) the ledger records before the new hole is appended', GS,
  '        voidWells.append(well)\n        worldNode.addChild(well)\n        #if DEBUG\n        combatLedger.recordVoidWell(preset, live: voidWells.filter { $0.state.isLive }.count)   // live holes only (A7b S2)\n        #endif\n',
  '        #if DEBUG\n        combatLedger.recordVoidWell(preset, live: voidWells.filter { $0.state.isLive }.count)   // live holes only (A7b S2)\n        #endif\n        voidWells.append(well)\n        worldNode.addChild(well)\n',
  ['void']),
 ('B7-S1-3 (R9) a dormant Arc Wake FUNCTION (capitalised name) creeps back', GS,
  '    // MARK: - v1.8 Unit 14: False Opening (Void card)\n',
  '    private func updateArcWake(_ dt: TimeInterval) { }\n\n    // MARK: - v1.8 Unit 14: False Opening (Void card)\n', [CAT]),
 ('B7-S1-4 rollOverload regains a legacy applyStun branch', GS,
  '                combatLedger.overloadStuns += 1\n                #endif\n            }\n        }\n    }\n',
  '                combatLedger.overloadStuns += 1\n                #endif\n            }\n        } else {\n            enemy.applyStun(0.5)\n        }\n    }\n', [CAT]),
 ('B7-S2-15 (R10) The Hunter charges only on a surviving gun hit (count unchanged)', GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        if !enemyNode.isDying { apexRegisterAttack() }   // T5 Apex: every player hit charges the pounce gauge\n', ['redsmile']),
 ('B7-S2-16 (R11) the forced-card banner leaves the DEBUG block', GS,
  ['            seam.name = "geometrySeamBanner"\n            camera.addChild(seam)\n        }\n', '        if GameConfig.Mote.debugForceEntrance {\n            let seam'],
  ['            seam.name = "geometrySeamBanner"\n            camera.addChild(seam)\n        }\n        #endif\n', '        #if DEBUG\n        if GameConfig.Mote.debugForceEntrance {\n            let seam'],
  [CAT]),
 # --- corrective 2 (freeze-1 independent review, Sep 28): the five surviving reproductions ---
 ('B7-C2-1 a Red Smile meter call hidden in a /* block comment */ (the line-comment-only reader kept it)', GS,
  '                // A landed Shatter is still a primary hit: its ONE meter\n                // registration, then out — it never seeds the swing\'s chain.\n                chargeRedSmileHitMeters(.shatter)\n',
  '                /* A landed Shatter is still a primary hit: its ONE meter\n                   registration, then out — it never seeds the swing\'s chain.\n                chargeRedSmileHitMeters(.shatter) */\n',
  ['redsmile']),
 ('B7-C2-2 the correct Repulse pin call survives only in a /* block comment */; the live call passes isSnowman: false', GS,
  '                && RepulseFlight.isPin(isMiniBoss: other.isMiniBoss, isSnowman: other.isSnowman,\n                                       isHittable: isHittable(other)) {\n',
  '                /* && RepulseFlight.isPin(isMiniBoss: other.isMiniBoss, isSnowman: other.isSnowman,\n                                       isHittable: isHittable(other)) { */\n                && RepulseFlight.isPin (isMiniBoss: other.isMiniBoss, isSnowman: false,\n                                       isHittable: isHittable(other)) {\n',
  [GUARD]),
 ('B7-C2-3 The Hunter charge wrapped in a multi-line `if !enemyNode.isDying { … }`', GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        if !enemyNode.isDying {\n            apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n        }\n',
  ['redsmile']),
 ('B7-C2-4 the arena-radius formula changes; the old formula survives only in a comment', 'Sparkforge/Config/GameConfig.swift',
  '        static var radius: CGFloat { DeviceScale.arenaRadius * ArenaConfig.current.radiusScale }\n',
  '        static var radius: CGFloat { DeviceScale.arenaRadius * ArenaConfig.current.radiusScale * 1.1 }   // was: static var radius: CGFloat { DeviceScale.arenaRadius * ArenaConfig.current.radiusScale }\n',
  ['geometry']),
 ('B7-C2-5 the forced-card banner is built only under `if false { … }` inside its hot-flag branch', GS,
  ['if let forced = UpgradeManager.debugForcedCardID {\n', '+ 66)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n'],
  ['if let forced = UpgradeManager.debugForcedCardID {\n            if false {\n', '+ 66)\n            seam.zPosition = 300\n            camera.addChild(seam)\n            }\n        }\n'],
  [CAT]),
 # --- corrective 2: the shared sanitizer and its structure view, mutated directly ---
 ('B7-C2-6 SwiftSource: a nested block comment ends at its first */', 'tools/signature-draw-harness/SwiftSource.swift',
  '                        if c[i] == "/", at(i + 1) == "*" { depth += 1; out.append(contentsOf: [" ", " "]); i += 2; continue }\n', '', [CAT]),
 ('B7-C2-7 SwiftSource: string literals are not recognised (a // inside a string cuts the line)', 'tools/signature-draw-harness/SwiftSource.swift',
  '                if at(i + hashes) == "\\"" {                         // a string literal opens', '                if false {', [CAT]),
 ('B7-C2-8 SwiftSource: escapes are not honoured (an escaped quote closes the string)', 'tools/signature-draw-harness/SwiftSource.swift',
  'if c[i] == "\\\\", (0..<hashes).allSatisfy({ at(i + 1 + $0) == "#" }) {', 'if false {', [CAT]),
 ('B7-C2-9 SwiftSource: Block.depth ignores nesting', 'tools/signature-draw-harness/SwiftSource.swift',
  '                if exec[k] == "{" { d += 1 } else if exec[k] == "}" { d -= 1 }\n            }\n            return d',
  '                d = 1\n            }\n            return d', [CAT, 'redsmile']),
 ('B7-C2-10 the whole forced-card branch wrapped in `if false { … }`', GS,
  ['        if let forced = UpgradeManager.debugForcedCardID {\n', '+ 66)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n'],
  ['        if false {\n        if let forced = UpgradeManager.debugForcedCardID {\n', '+ 66)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n        }\n'],
  [CAT]),
 ('B7-C2-11 a new guard-success branch before The Hunter charge (`guard !enemyNode.isDying else { return }`)', GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        guard !enemyNode.isDying else { return }\n        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  ['redsmile']),
 # --- corrective 3 (freeze-2 independent review, Sep 28): the four new reproductions ---
 ('B7-C3-1 MW7: The Hunter registration exists only as text inside a multi-line string', GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        _ = """\n        apexRegisterAttack()\n        """\n', ['redsmile']),
 ('B7-C3-2 MW7: The Hunter registration exists only inside an inactive `#if false` region', GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        #if false\n        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n        #endif\n', ['redsmile']),
 ('B7-C3-3 WR8: `guard false else { return }` inside the Mote hot branch, before its banner', GS,
  'if GameConfig.Mote.debugForceEntrance {\n            let seam',
  'if GameConfig.Mote.debugForceEntrance {\n            guard false else { return }\n            let seam', [CAT]),
 ('B7-C3-4 WR8: the Mote hot branch sits inside an inactive `#if false` region', GS,
  ['        if GameConfig.Mote.debugForceEntrance {\n            let seam', '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n'],
  ['        #if false\n        if GameConfig.Mote.debugForceEntrance {\n            let seam', '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n        #endif\n'],
  [CAT]),
 ('B7-C3-5 WR8: `guard false else { return }` inside the forced-card hot branch, before its banner', GS,
  'if let forced = UpgradeManager.debugForcedCardID {\n',
  'if let forced = UpgradeManager.debugForcedCardID {\n            guard false else { return }\n', [CAT]),
 ('B7-C3-6 WR8: the forced-card hot branch sits inside an inactive `#if false` region', GS,
  ['        if let forced = UpgradeManager.debugForcedCardID {\n', '+ 66)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n'],
  ['        #if false\n        if let forced = UpgradeManager.debugForcedCardID {\n', '+ 66)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n        #endif\n'],
  [CAT]),
 ('B7-C3-7 SwiftSource: inactive `#if` regions stay executable', 'tools/signature-draw-harness/SwiftSource.swift',
  '            if isDirective || !active {', '            if isDirective {', [CAT, 'redsmile']),
 ('B7-C3-8 SwiftSource: a match inside a string literal counts as executable', 'tools/signature-draw-harness/SwiftSource.swift',
  '                guard shape[o] == code[o], exec[o] == code[o] else { return false }', '                guard exec[o] == code[o] || true else { return false }', [CAT, 'redsmile']),
 ('B7-C3-9 SwiftSource: the path check ignores `guard`', 'tools/signature-draw-harness/SwiftSource.swift',
  '"preconditionFailure", "guard"]', '"preconditionFailure"]', [CAT]),
 # --- corrective 4 (freeze-3 independent review, Sep 29): token boundaries, directive parsing, MW7 control flow ---
 ('B7-C4-1 MW7: the registration sits inside `#if/**/false` (a comment between directive tokens)', GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        #if/**/false\n        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n        #endif\n', ['redsmile']),
 ('B7-C4-2 MW7: the registration sits inside `#if<TAB>false`', GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        #if\tfalse\n        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n        #endif\n', ['redsmile']),
 ('B7-C4-3 MW7: the registration sits in a nested inactive region (`#if false` inside `#if DEBUG`)', GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        #if DEBUG\n        #if false\n        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n        #endif\n        #endif\n', ['redsmile']),
 ("B7-C4-4 MW7: `guard !enemyNode.isDying else { fatalError(...) }` before the registration (the Reviewer's exact form)", GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        guard !enemyNode.isDying else { fatalError("dying") }\n        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n', ['redsmile']),
 ('B7-C4-5 MW7: the same guard ending in `preconditionFailure()`', GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        guard !enemyNode.isDying else { preconditionFailure() }\n        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n', ['redsmile']),
 ('B7-C4-6 WR8: the Mote hot branch inside `#if/**/false`', GS,
  ['        if GameConfig.Mote.debugForceEntrance {\n            let seam', '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n'],
  ['        #if/**/false\n        if GameConfig.Mote.debugForceEntrance {\n            let seam', '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n        #endif\n'], [CAT]),
 ('B7-C4-7 WR8: the Mote hot branch inside `#if<TAB>false`', GS,
  ['        if GameConfig.Mote.debugForceEntrance {\n            let seam', '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n'],
  ['        #if\tfalse\n        if GameConfig.Mote.debugForceEntrance {\n            let seam', '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n        #endif\n'], [CAT]),
 ('B7-C4-8 WR8: the Mote hot branch inside `#if !DEBUG` (negation; inactive under DEBUG)', GS,
  ['        if GameConfig.Mote.debugForceEntrance {\n            let seam', '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n'],
  ['        #if !DEBUG\n        if GameConfig.Mote.debugForceEntrance {\n            let seam', '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n        #endif\n'], [CAT]),
 ('B7-C4-9 WR8: the Mote banner built only under `if false { … }` inside its hot branch', GS,
  ['if GameConfig.Mote.debugForceEntrance {\n            let seam', '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n'],
  ['if GameConfig.Mote.debugForceEntrance {\n            if false {\n            let seam', '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n            }\n        }\n'], [CAT]),
 ('B7-C4-10 SwiftSource: comments are deleted again (adjacent tokens fuse)', 'tools/signature-draw-harness/SwiftSource.swift',
  '                    while i < c.count, c[i] != "\\n" { out.append(" "); i += 1 }',
  '                    while i < c.count, c[i] != "\\n" { i += 1 }', [CAT]),
 ('B7-C4-11 SwiftSource: the directive parser skips spaces but not tabs', 'tools/signature-draw-harness/SwiftSource.swift',
  '        while k < line.endIndex, line[k] == " " || line[k] == "\\t" { k += 1 }',
  '        while k < line.endIndex, line[k] == " " { k += 1 }', [CAT]),
 ('B7-C4-12 SwiftSource: the control-flow skeleton ignores `guard`', 'tools/signature-draw-harness/SwiftSource.swift',
  'let keywords: Set<String> = ["if", "guard", "else",',
  'let keywords: Set<String> = ["if", "else",', [CAT, 'redsmile']),
 ('B7-C4-13 SwiftSource: an unsupported directive is accepted silently', 'tools/signature-draw-harness/SwiftSource.swift',
  "        guard unsupported.isEmpty else { return nil }             // a form this model can't evaluate: fail loudly\n",
  '', [CAT]),
 # --- corrective 5 (freeze-4 independent review, Sep 29): standalone statements, not calls embedded in expressions ---
 ("B7-C5-1 MW7: the registration inside a multi-line ternary `false ?` / `apexRegisterAttack()` / `: ()` (the Reviewer's exact form)", GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        false ?\n        apexRegisterAttack()\n        : ()\n', ['redsmile']),
 ('B7-C5-2 MW7: the registration inside a same-line ternary `false ? apexRegisterAttack() : ()`', GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        false ? apexRegisterAttack() : ()\n', ['redsmile']),
 ('B7-C5-3 MW7: a multi-line ternary with comments, whitespace and a tab around `?` and `:`', GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        false /* never */\n            ?   // why not\n        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n            :\t()\n', ['redsmile']),
 ("B7-C5-4 WR8: the Mote banner attached only inside a multi-line ternary `false ?` / `camera.addChild(seam)` / `: ()` (the Reviewer's exact form)", GS,
  '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n',
  '+ 78)\n            seam.zPosition = 300\n            false ?\n            camera.addChild(seam)\n            : ()\n        }\n', [CAT]),
 ('B7-C5-5 WR8: the Mote banner attached only inside a same-line ternary', GS,
  '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n',
  '+ 78)\n            seam.zPosition = 300\n            false ? camera.addChild(seam) : ()\n        }\n', [CAT]),
 ('B7-C5-6 WR8: the forced-card banner attached only inside a same-line ternary', GS,
  '+ 66)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n',
  '+ 66)\n            seam.zPosition = 300\n            false ? camera.addChild(seam) : ()\n        }\n', [CAT]),
 ('B7-C5-7 SwiftSource: the standalone check ignores what shares the line', 'tools/signature-draw-harness/SwiftSource.swift',
  '            guard onOwnLine else { return false }\n',
  '', [CAT, 'redsmile']),
 ('B7-C5-8 SwiftSource: the standalone check ignores a joining previous line', 'tools/signature-draw-harness/SwiftSource.swift',
  '            guard !joinsPrevious else { return false }\n',
  '', [CAT, 'redsmile']),
 ('B7-C5-9 SwiftSource: the standalone check ignores a joining next line', 'tools/signature-draw-harness/SwiftSource.swift',
  '            guard !joinsNext else { return false }\n',
  '', [CAT, 'redsmile']),
 # --- corrective 6 (freeze-5 independent review, Sep 29): the exact active-executable token-prefix tripwire ---
 ("B7-C6-1 MW7: the registration inside `assert(true, String(describing: try apexRegisterAttack() as Void))` (the Reviewer's exact form)", GS,
  '        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n',
  '        assert(true, String(describing:\n            try\n            apexRegisterAttack()\n            as Void\n        ))\n', ['redsmile']),
 ("B7-C6-2 WR8: the Mote banner attached only inside the same lazy `assert` argument wrapper (the Reviewer's form)", GS,
  '+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n',
  '+ 78)\n            seam.zPosition = 300\n            assert(true, String(describing:\n                try\n                camera.addChild(seam)\n                as Void\n            ))\n        }\n', [CAT]),
 ('B7-C6-3 WR8: the forced-card banner attached only inside the lazy `assert` argument wrapper', GS,
  '+ 66)\n            seam.zPosition = 300\n            camera.addChild(seam)\n        }\n',
  '+ 66)\n            seam.zPosition = 300\n            assert(true, String(describing:\n                try\n                camera.addChild(seam)\n                as Void\n            ))\n        }\n', [CAT]),
 ('B7-C6-4 SwiftSource: the tripwire tokenizer splits string literals (their internal whitespace is lost)', 'tools/signature-draw-harness/SwiftSource.swift',
  '                if let e = literalEnd[k] { out.append(String(active[k..<e])); k = e; continue }\n',
  '', [CAT]),
 ('B7-C6-5 SwiftSource: the tripwire tokenizer reads inactive `#if` regions', 'tools/signature-draw-harness/SwiftSource.swift',
  '        let active = zip(code, blanked).map { $1 ? " " : $0 }',
  '        let active = code', [CAT]),
 ('B7-C6-6 SwiftSource: the tripwire digest drops token boundaries', 'tools/signature-draw-harness/SwiftSource.swift',
  'tokens.joined(separator: "\\u{1F}")',
  'tokens.joined()', [CAT]),
 # --- S3: G1.1 The Hunter on the gun's boss hit (the MW6/MW7/MW8 contract change);
 # G1.2 Grounder / Relay Imp not boss-class; G1.3 Storm Engine = normal + 2 (CL-98);
 # G1.4 Erasure's 1-based arena band (CL-101). GameConfig.Shock is now extracted.
 ('B7-S3-1 G1.1: the boss hit no longer charges The Hunter (the pre-S3 code)', GS,
  '        apexRegisterAttack()   // T5 Apex: gun hits on the boss charge the pounce gauge too (A7b G1.1)\n', '', ['redsmile']),
 ('B7-S3-2 G1.1: the boss hit registers Apex AFTER Erasure', GS,
  '        apexRegisterAttack()   // T5 Apex: gun hits on the boss charge the pounce gauge too (A7b G1.1)\n        erasureRegisterHit()   // T1 Erasure: hits on the boss charge the meter too\n',
  '        erasureRegisterHit()   // T1 Erasure: hits on the boss charge the meter too\n        apexRegisterAttack()   // T5 Apex: gun hits on the boss charge the pounce gauge too (A7b G1.1)\n', ['redsmile']),
 ('B7-S3-3 G1.1: the boss hit charges The Hunter only while the boss lives', GS,
  '        apexRegisterAttack()   // T5 Apex: gun hits on the boss charge the pounce gauge too (A7b G1.1)\n',
  '        if !bossNode.isDead { apexRegisterAttack() }   // T5 Apex: gun hits on the boss charge the pounce gauge too (A7b G1.1)\n', ['redsmile']),
 # re-pointed in A7b S8: the anchor moved with S8's code; the mutation's contract is unchanged.
 ('B7-S3-4 G1.1: the boss hit charges The Hunter BEFORE its damage lands (moved, still unconditional)', GS,
  ('        apexRegisterAttack()   // T5 Apex: gun hits on the boss charge the pounce gauge too (A7b G1.1)\n', '        bossNode.takeDirectHit(hit, ignoresChallengeDEF: projectileNode.voidHit.flatDEFPenetration)\n'),
  ('', '        apexRegisterAttack()\n        bossNode.takeDirectHit(hit, ignoresChallengeDEF: projectileNode.voidHit.flatDEFPenetration)\n'), ['redsmile']),
 ('B7-S3-5 G1.1: the boss hit\'s Apex registration parked in an inactive `#if false` region', GS,
  '        apexRegisterAttack()   // T5 Apex: gun hits on the boss charge the pounce gauge too (A7b G1.1)\n',
  '        #if false\n        apexRegisterAttack()   // T5 Apex: gun hits on the boss charge the pounce gauge too (A7b G1.1)\n        #endif\n', ['redsmile']),
 ('B7-S3-6 G1.2: Grounder\'s pulse is boss-class again (the default)', GS,
  'self.applyBossHazardDamage(damage, shakeIntensity: 8, fromBossClass: false)', 'self.applyBossHazardDamage(damage, shakeIntensity: 8)', [GUARD]),
 ('B7-S3-7 G1.2: the Relay Imp arc is boss-class again (the default)', GS,
  'applyBossHazardDamage(cfg.relayArcDamage, shakeIntensity: 6, fromBossClass: false)', 'applyBossHazardDamage(cfg.relayArcDamage, shakeIntensity: 6)', [GUARD]),
 ('B7-S3-8 G1.2: the Relay Imp arc says `fromBossClass: true` explicitly', GS,
  'applyBossHazardDamage(cfg.relayArcDamage, shakeIntensity: 6, fromBossClass: false)', 'applyBossHazardDamage(cfg.relayArcDamage, shakeIntensity: 6, fromBossClass: true)', [GUARD]),
 ('B7-S3-9 G1.2: Grounder\'s fix parked in `#if false`, the boss-class default live in `#else`', GS,
  '                self.applyBossHazardDamage(damage, shakeIntensity: 8, fromBossClass: false)\n',
  '                #if false\n                self.applyBossHazardDamage(damage, shakeIntensity: 8, fromBossClass: false)\n                #else\n                self.applyBossHazardDamage(damage, shakeIntensity: 8)\n                #endif\n', [GUARD]),
 ('B7-S3-10 G1.2: the hazard default flips to not-boss-class (every boss hazard silently loses the class)', GS,
  '                                       fromBossClass: Bool = true) {', '                                       fromBossClass: Bool = false) {', [GUARD]),
 ('B7-S3-11 G1.2: a genuine boss hazard (the Slag Titan) is declassed too', GS,
  'self.applyBossHazardDamage(damage, shakeIntensity: 10, shakeDuration: 0.3)', 'self.applyBossHazardDamage(damage, shakeIntensity: 10, shakeDuration: 0.3, fromBossClass: false)', [GUARD]),
 ('B7-S3-12 G1.2: the hazard path ignores its flag (always boss-class)', GS,
  '        }\n\n        let outcome = applyPlayerDamage(damage, fromBossClass: fromBossClass)\n',
  '        }\n\n        let outcome = applyPlayerDamage(damage, fromBossClass: true)\n', [GUARD]),
 ('B7-S3-13 G1.3: Storm Engine\'s bonus is 0 (the spread volley = the normal count)', 'Sparkforge/Config/GameConfig.swift',
  'static let stormEngineBonusPellets: Int = 2', 'static let stormEngineBonusPellets: Int = 0', ['shock']),
 ('B7-S3-14 G1.3: Storm Engine\'s bonus is 3', 'Sparkforge/Config/GameConfig.swift',
  'static let stormEngineBonusPellets: Int = 2', 'static let stormEngineBonusPellets: Int = 3', ['shock']),
 ('B7-S3-15 G1.3: the spread volley is a fixed 3 again (the pre-S3 rule)', 'Sparkforge/Systems/PlayerStats.swift',
  'return isSpreadVolley ? normal + GameConfig.Shock.stormEngineBonusPellets : normal',
  'return isSpreadVolley ? 3 : normal', ['shock']),
 ('B7-S3-16 G1.3: the CL-98 alternative max(3, normal) (never fewer, but no Scatter gain)', 'Sparkforge/Systems/PlayerStats.swift',
  'return isSpreadVolley ? normal + GameConfig.Shock.stormEngineBonusPellets : normal',
  'return isSpreadVolley ? max(3, normal) : normal', ['shock']),
 ('B7-S3-17 G1.3: the normal count drops Scatter\'s extras', 'Sparkforge/Systems/PlayerStats.swift',
  '        let normal = 1 + extraProjectiles\n', '        let normal = 1\n', ['shock']),
 ('B7-S3-18 G1.3: the gun ignores the spread verdict', GS,
  'let shotCount = playerStats.volleyPelletCount(isSpreadVolley: isSpreadShot)',
  'let shotCount = playerStats.volleyPelletCount(isSpreadVolley: false)', [CAT]),
 ('B7-S3-19 G1.3: the gun computes its own fixed spread count again', GS,
  'let shotCount = playerStats.volleyPelletCount(isSpreadVolley: isSpreadShot)',
  'let shotCount = isSpreadShot ? 3 : 1 + playerStats.extraProjectiles', [CAT]),
 ('B7-S3-20 G1.3: Storm Engine arms every 4th volley instead of every 3rd', UM,
  '            stats.spreadShotInterval = 3\n', '            stats.spreadShotInterval = 4\n', ['shock']),
 ('B7-S3-21 G1.4: the band switch reads the 0-based id again (the pre-S3 bug: Arena 11 at 0.5x)', 'Sparkforge/Config/GameConfig.swift',
  '            switch arena + 1 {', '            switch arena {', ['void']),
 ('B7-S3-22 G1.4: the scene adds 1 as well (double-counted: Arena 10 at 0.65x)', GS,
  'GameConfig.Erasure.eventHorizonScale(arena: arenaConfig.id))', 'GameConfig.Erasure.eventHorizonScale(arena: arenaConfig.id + 1))', ['void']),
 ('B7-S3-23 G1.4: a band edge moves (Arena 11 falls through to the full timer)', 'Sparkforge/Config/GameConfig.swift',
  '            case 11...20: return 0.65   // 35% reduced', '            case 12...20: return 0.65   // 35% reduced', ['void']),
 ('B7-S3-24 G1.4: the correct call parked in `#if false`, a double-counted one live in `#else`', GS,
  '        let scale = TimeInterval(GameConfig.Erasure.eventHorizonScale(arena: arenaConfig.id))\n',
  '        #if false\n        let scale = TimeInterval(GameConfig.Erasure.eventHorizonScale(arena: arenaConfig.id))\n        #else\n        let scale = TimeInterval(GameConfig.Erasure.eventHorizonScale(arena: arenaConfig.id + 1))\n        #endif\n', ['void']),
 ('B7-S3-25 the REAL GameConfig.Shock reaches the harnesses (Overload 20% -> 25%; the Stubs mirror is retired)', 'Sparkforge/Config/GameConfig.swift',
  'static let overloadChance: CGFloat = 0.20', 'static let overloadChance: CGFloat = 0.25', ['shock']),
 # --- S4: G1.5 Rootbound (CL-96) — the ground slows by terraSlow; G1.6 Thornsoil (CL-97) — order-proof.
 ('B7-S4-1 G1.5: the ground slow reads the Growth constant again (the pre-S4 code: Rootbound does nothing)', GS,
  'enemy.applySlow(playerStats.effectiveSlow(playerStats.terraSlow), duration: 0.3)',
  'enemy.applySlow(playerStats.effectiveSlow(GameConfig.Growth.enemySlow), duration: 0.3)', [CAT]),
 ('B7-S4-2 G1.5: Rootbound adds nothing to terraSlow', UM,
  '            stats.terraSlow += 0.15                  // Rootbound\n', '            stats.terraSlow += 0.0                  // Rootbound\n', [CHILL]),
 ('B7-S4-3 G1.5: the fixed slow parked in `#if false`, the constant live in `#else`', GS,
  '            enemy.applySlow(playerStats.effectiveSlow(playerStats.terraSlow), duration: 0.3)\n',
  '            #if false\n            enemy.applySlow(playerStats.effectiveSlow(playerStats.terraSlow), duration: 0.3)\n            #else\n            enemy.applySlow(playerStats.effectiveSlow(GameConfig.Growth.enemySlow), duration: 0.3)\n            #endif\n', [CAT]),
 ('B7-S4-4 G1.5: terraSlow reachable only through a dead ternary branch', GS,
  'enemy.applySlow(playerStats.effectiveSlow(playerStats.terraSlow), duration: 0.3)',
  'enemy.applySlow(playerStats.effectiveSlow(false ? playerStats.terraSlow : GameConfig.Growth.enemySlow), duration: 0.3)', [CAT]),
 ('B7-S4-5 G1.5: PlayerStats seeds terraSlow from a literal, not the Growth config', 'Sparkforge/Systems/PlayerStats.swift',
  '    var terraSlow: CGFloat = GameConfig.Growth.enemySlow\n', '    var terraSlow: CGFloat = 0.30\n', [CAT]),
 ('B7-S4-6 G1.5: a run reset keeps the last run\'s Rootbound slow', 'Sparkforge/Systems/PlayerStats.swift',
  '        terraSlow = GameConfig.Growth.enemySlow\n', '', [CHILL]),
 ('B7-S4-7 the REAL GameConfig.Growth reaches the harnesses (the ground slow 30% -> 25%)', 'Sparkforge/Config/GameConfig.swift',
  '        static let enemySlow: CGFloat = 0.30\n', '        static let enemySlow: CGFloat = 0.25\n', [CHILL]),
 ('B7-S4-8 G1.6: Thornsoil overwrites the bite again (the pre-S4 card: Wildwood 8 -> 6)', UM,
  'apply: { stats in stats.thornsoilDPS = max(stats.thornsoilDPS, 6) },', 'apply: { stats in stats.thornsoilDPS = 6 },', [CHILL]),
 ('B7-S4-9 G1.6: Thornsoil ADDS 6 instead of raising to 6', UM,
  'apply: { stats in stats.thornsoilDPS = max(stats.thornsoilDPS, 6) },', 'apply: { stats in stats.thornsoilDPS += 6 },', [CHILL]),
 ('B7-S4-10 G1.6: Thornsoil raises the bite to 8 on its own', UM,
  'apply: { stats in stats.thornsoilDPS = max(stats.thornsoilDPS, 6) },', 'apply: { stats in stats.thornsoilDPS = max(stats.thornsoilDPS, 8) },', [CHILL]),
 # --- S5: G1.7 the snowman and the timed (Overload) stun are independent holds (R2):
 # EnemyNode wires the pure StunHold (shock SH executes it; catalog WR11 pins the wiring).
 ('B7-S5-1 G1.7: ending a snowman clears the timed stun again (the pre-S5 bug)', 'Sparkforge/Nodes/EnemyNode.swift',
  '    private func endSnowman(melted: Bool) {\n        snowmanNode?.removeFromParent()\n',
  '    private func endSnowman(melted: Bool) {\n        stunHold = StunHold()\n        snowmanNode?.removeFromParent()\n', [CAT]),
 ('B7-S5-2 G1.7: becoming a snowman writes its duration into the timed stun again', 'Sparkforge/Nodes/EnemyNode.swift',
  '                            bossClassScale: GameConfig.BossClass.debuffScale) != nil else { return false }\n        showSnowman()\n',
  '                            bossClassScale: GameConfig.BossClass.debuffScale) != nil else { return false }\n        stunHold.stun(duration)\n        showSnowman()\n', [CAT]),
 ('B7-S5-3 G1.7: EnemyNode.isStunned ignores the snowman hold', 'Sparkforge/Nodes/EnemyNode.swift',
  'var isStunned: Bool { stunHold.isStunned(snowman: snowman.isSnowman) }', 'var isStunned: Bool { stunHold.isStunned(snowman: false) }', [CAT]),
 ('B7-S5-4 G1.7: a snowman pauses the timed stun (the hold ticks only outside the form)', 'Sparkforge/Nodes/EnemyNode.swift',
  '        stunHold.tick(deltaTime)\n', '        if !isSnowman { stunHold.tick(deltaTime) }\n', [CAT]),
 ('B7-S5-5 G1.7: Overload shows its stars but never holds the body', 'Sparkforge/Nodes/EnemyNode.swift',
  '        guard !isDying, overloadStun.tryStun(duration: duration) else { return false }\n        stunHold.stun(duration)\n',
  '        guard !isDying, overloadStun.tryStun(duration: duration) else { return false }\n', [CAT]),
 ('B7-S5-6 G1.7: the status tick parked in `#if false` (a timed stun never ends)', 'Sparkforge/Nodes/EnemyNode.swift',
  '        stunHold.tick(deltaTime)\n', '        #if false\n        stunHold.tick(deltaTime)\n        #endif\n', [CAT]),
 ('B7-S5-7 G1.7: a DEBUG-only reset in endSnowman (active in the proved configuration)', 'Sparkforge/Nodes/EnemyNode.swift',
  '    private func endSnowman(melted: Bool) {\n        snowmanNode?.removeFromParent()\n',
  '    private func endSnowman(melted: Bool) {\n        #if DEBUG\n        stunHold = StunHold()\n        #endif\n        snowmanNode?.removeFromParent()\n', [CAT]),
 ('B7-S5-8 G1.7: the Void trap writes the timed stun (R2; WR23 re-pointed to stunHold)', 'Sparkforge/Nodes/EnemyNode.swift',
  '        cancelFear()\n        showTrapRing()\n        return true\n',
  '        cancelFear()\n        stunHold.stun(wellRemaining)\n        showTrapRing()\n        return true\n', ['void']),
 ('B7-S5-9 StunHold: the snowman hold no longer stuns', 'Sparkforge/Systems/StunHold.swift',
  'func isStunned(snowman: Bool) -> Bool { remaining > 0 || snowman }', 'func isStunned(snowman: Bool) -> Bool { remaining > 0 }', ['shock']),
 ('B7-S5-10 StunHold: a new timed stun overwrites a longer one', 'Sparkforge/Systems/StunHold.swift',
  'mutating func stun(_ duration: TimeInterval) { remaining = max(remaining, duration) }',
  'mutating func stun(_ duration: TimeInterval) { remaining = duration }', ['shock']),
 ('B7-S5-11 StunHold: the timed stun runs at half speed', 'Sparkforge/Systems/StunHold.swift',
  'mutating func tick(_ dt: TimeInterval) { if remaining > 0 { remaining -= dt } }',
  'mutating func tick(_ dt: TimeInterval) { if remaining > 0 { remaining -= dt / 2 } }', ['shock']),
 # --- S6: G1.8 four independent vulnerability channels (CL-107/116) + G2-5 the Apex T4 face.
 # damage-pipeline VC executes VulnerabilityChannels; catalog WR12 pins every body and writer.
 ('B7-S6-1 shared-slot regression: writing one source writes every channel', 'Sparkforge/Systems/VulnerabilityChannels.swift',
  '    mutating func set(_ source: Source, _ value: CGFloat) {\n        switch source {\n        case .frostbite: frostbite = value\n        case .marked:    marked = value\n        case .called:    called = value\n        case .fracture:  fracture = value\n        }\n    }\n',
  '    mutating func set(_ source: Source, _ value: CGFloat) {\n        frostbite = value; marked = value; called = value; fracture = value\n    }\n', ['damage-pipeline']),
 ('B7-S6-2 stacking instead of max: the channels multiply', 'Sparkforge/Systems/VulnerabilityChannels.swift',
  'var multiplier: CGFloat { max(1.0, frostbite, marked, called, fracture) }',
  'var multiplier: CGFloat { frostbite * marked * called * fracture }', ['damage-pipeline']),
 ('B7-S6-3 stacking instead of max: the bonuses add', 'Sparkforge/Systems/VulnerabilityChannels.swift',
  'var multiplier: CGFloat { max(1.0, frostbite, marked, called, fracture) }',
  'var multiplier: CGFloat { 1.0 + (frostbite - 1) + (marked - 1) + (called - 1) + (fracture - 1) }', ['damage-pipeline']),
 ('B7-S6-4 Fracture omitted from the resolution', 'Sparkforge/Systems/VulnerabilityChannels.swift',
  'var multiplier: CGFloat { max(1.0, frostbite, marked, called, fracture) }',
  'var multiplier: CGFloat { max(1.0, frostbite, marked, called) }', ['damage-pipeline']),
 ('B7-S6-5 wrong-source clearing in the store: clearing one source clears them all', 'Sparkforge/Systems/VulnerabilityChannels.swift',
  '    mutating func clear(_ source: Source) { set(source, 1.0) }', '    mutating func clear(_ source: Source) { self = VulnerabilityChannels() }', ['damage-pipeline']),
 ('B7-S6-6 the shared accessor drifts to one channel (Frostbite only)', 'Sparkforge/Systems/VulnerabilityChannels.swift',
  'var vulnerabilityMultiplier: CGFloat { vulnerability.multiplier }', 'var vulnerabilityMultiplier: CGFloat { vulnerability.frostbite }', ['damage-pipeline', CAT]),
 ('B7-S6-7 wrong-source clearing in the scene: letting go of the lasso clears Marked', GS,
  'calledEnemy?.vulnerability.clear(.called)', 'calledEnemy?.vulnerability.clear(.marked)', [CAT]),
 ('B7-S6-8 weaker overwriting stronger: Called writes into the Frostbite channel', GS,
  'e.vulnerability.set(.called, GameConfig.BossClass.scaledDebuff(', 'e.vulnerability.set(.frostbite, GameConfig.BossClass.scaledDebuff(', [CAT]),
 ('B7-S6-9 Fracture omitted: EnemyNode writes Fracture into the Frostbite channel', 'Sparkforge/Nodes/EnemyNode.swift',
  '        vulnerability.set(.fracture, multiplier)\n', '        vulnerability.set(.frostbite, multiplier)\n', [CAT]),
 ('B7-S6-10 the strongest expiring reveals nothing: Frostbite closing resets the whole store', 'Sparkforge/Nodes/EnemyNode.swift',
  '        case .closed: vulnerability.clear(.frostbite)\n', '        case .closed: vulnerability = VulnerabilityChannels()\n', [CAT]),
 ('B7-S6-11 shared-slot regression: Marked waits for an empty body again', GS,
  'if e.timeAlive >= GameConfig.Apex.markLifetime && !e.vulnerability.isActive(.marked) {',
  'if e.timeAlive >= GameConfig.Apex.markLifetime && e.vulnerabilityMultiplier == 1.0 {', [CAT]),
 ('B7-S6-12 boss drift: the Marchwarden keeps its own stored multiplier (marks never reach it)', 'Sparkforge/Nodes/MarchwardenNode.swift',
  '    var vulnerability = VulnerabilityChannels()   // A7b S6: capstone-debuff vulnerability channels\n',
  '    var vulnerability = VulnerabilityChannels()   // A7b S6: capstone-debuff vulnerability channels\n    var vulnerabilityMultiplier: CGFloat = 1.0\n', [CAT]),
 # re-pointed in A7b S8: the anchor moved with S8's code; the mutation's contract is unchanged.
 ('B7-S6-13 boss drift: the Quench Warden resolves only Called', 'Sparkforge/Nodes/QuenchWardenNode.swift',
  '        let scaled = resolved ?? (vulnerabilityMultiplier == 1.0\n',
  '        let scaled = resolved ?? (vulnerability.called == 1.0\n', [CAT]),
 # re-pointed in A7b S8: the anchor moved with S8's code; the mutation's contract is unchanged.
 ('B7-S6-14 a consumer applies the resolved value twice (EnemyNode takeDamage)', 'Sparkforge/Nodes/EnemyNode.swift',
  '            : Int((CGFloat(amount) * vulnerabilityMultiplier).rounded()))\n        let healthBefore = health\n',
  '            : Int((CGFloat(amount) * vulnerabilityMultiplier * vulnerabilityMultiplier).rounded()))\n        let healthBefore = health\n', [CAT]),
 ('B7-S6-15 G2-5: the Apex T4 face reverts to the old copy', UM,
  '                "Marked: bosses at once, foes after 10s: +35%",\n', '                "Marked: foes alive 10s take +35% damage",\n', [CAT]),
 # --- S6 corrective 7: the independent review of freeze 10 (FAIL, proof strength only)
 # found three production-shaped mutants that survived every harness. They are
 # retained VERBATIM (the Reviewer's exact strings, wr12-probes.py) and killed by
 # the real-node vulnerability harness, which executes the production nodes.
 ('B7-S6R-1 REVIEW-S6-Fracture-early-return: applyFracture returns before its channel write', 'Sparkforge/Nodes/EnemyNode.swift',
  '    func applyFracture(_ multiplier: CGFloat, duration: TimeInterval) {\n',
  '    func applyFracture(_ multiplier: CGFloat, duration: TimeInterval) {\n        if duration > 0 { return }\n', [VULN]),
 ('B7-S6R-2 REVIEW-S6-Fracture-clear-before-expiry: Fracture cleared on every tick BUT its expiry', 'Sparkforge/Nodes/EnemyNode.swift',
  'if fractureWindow.tick(deltaTime) { vulnerability.clear(.fracture) }',
  'if !fractureWindow.tick(deltaTime) { vulnerability.clear(.fracture) }', [VULN]),
 ('B7-S6R-3 REVIEW-S6-Marchwarden-bypasses-resolved-damage: the resolved value is computed but raw damage reaches HP', 'Sparkforge/Nodes/MarchwardenNode.swift',
  'let dealt = challengedDamage(scaled, raw: amount, ignoresChallengeDEF: ignoresChallengeDEF)',
  'let dealt = challengedDamage(amount, raw: amount, ignoresChallengeDEF: ignoresChallengeDEF)', [VULN]),
 # --- S7: G1.9 94a — ONE DirectHitDamage block on all four direct-hit chains (CL-94/114/115)
 # + G2-1 the Permafrost copy. damage-pipeline DH executes the routine; catalog WR13 and
 # redsmile MW8 pin each chain's call, Forge ahead of it, and its path to takeDamage.
 # re-pointed in A7b S8: the anchor moved with S8's code; the mutation's contract is unchanged.
 ('B7-S7-1 the block truncates again (a 1-damage hit gains nothing)', 'Sparkforge/Systems/DirectHitDamage.swift',
  '        return DirectHit(basis: VoidRounding.damage(exact, unit: rounding.unit),\n                         dealt: VoidRounding.damage(exact * vulnerability, unit: rounding.unit))',
  '        return DirectHit(basis: Int(exact),\n                         dealt: Int(exact * vulnerability))', ['damage-pipeline']),
 # re-pointed in A7b S8: the anchor moved with S8's code; the mutation's contract is unchanged.
 ('B7-S7-2 one rounding PER amplifier (same unit) instead of once', 'Sparkforge/Systems/DirectHitDamage.swift',
  '        let exact = CGFloat(prefix) * amplifiers.product * overcharge\n',
  '        let exact = CGFloat(VoidRounding.damage(CGFloat(VoidRounding.damage(CGFloat(VoidRounding.damage(CGFloat(prefix) * amplifiers.permafrost, unit: rounding.unit)) * amplifiers.brittleCold, unit: rounding.unit)) * amplifiers.openWounds, unit: rounding.unit)) * overcharge\n', ['damage-pipeline']),
 ('B7-S7-3 the amplifiers ADD instead of multiplying', 'Sparkforge/Systems/DirectHitDamage.swift',
  'var product: CGFloat { permafrost * brittleCold * openWounds }', 'var product: CGFloat { permafrost + brittleCold + openWounds - 2 }', ['damage-pipeline']),
 ('B7-S7-4 Brittle Cold dropped from the block', 'Sparkforge/Systems/DirectHitDamage.swift',
  'var product: CGFloat { permafrost * brittleCold * openWounds }', 'var product: CGFloat { permafrost * openWounds }', ['damage-pipeline']),
 # re-pointed in A7b S8: the anchor moved with S8's code; the mutation's contract is unchanged.
 ('B7-S7-5 a 0 prefix invents 1 damage', 'Sparkforge/Systems/DirectHitDamage.swift',
  '                         dealt: VoidRounding.damage(exact * vulnerability, unit: rounding.unit))',
  '                         dealt: max(1, VoidRounding.damage(exact * vulnerability, unit: rounding.unit)))', ['damage-pipeline']),
 ('B7-S7-6 applicability: Permafrost ignores an arena-wide slow (Q-C5)', 'Sparkforge/Systems/DirectHitDamage.swift',
  'if permafrostBonus > 0 && (slowed || arenaSlowed) {', 'if permafrostBonus > 0 && slowed {', ['damage-pipeline']),
 ('B7-S7-7 applicability: Brittle Cold ignores a stunned foe', 'Sparkforge/Systems/DirectHitDamage.swift',
  'if brittleCold && (slowed || frozen || stunned) {', 'if brittleCold && (slowed || frozen) {', ['damage-pipeline']),
 ('B7-S7-8 applicability: a boss gets Open Wounds without bleeding', 'Sparkforge/Systems/DirectHitDamage.swift',
  '        var a = DirectHitAmplifiers()\n        if openWoundsBonus > 0 && bleeding { a.openWounds = 1 + openWoundsBonus }\n        return a\n    }\n}',
  '        var a = DirectHitAmplifiers()\n        if openWoundsBonus > 0 { a.openWounds = 1 + openWoundsBonus }\n        return a\n    }\n}', ['damage-pipeline']),
 ('B7-S7-9 the block threshold is a constant ½, not a fresh draw', 'Sparkforge/Systems/DirectHitDamage.swift',
  '    init(unit: CGFloat = CGFloat.random(in: 0..<1)) {', '    init(unit: CGFloat = 0.5) {', ['damage-pipeline']),
 # re-pointed in A7b S8: the anchor moved with S8's code; the mutation's contract is unchanged.
 ("B7-S7-10 the gun reuses the shot's spent A6 threshold for the block (CL-114e)", GS,
  '            overcharge: projectileNode.overchargeFactor, vulnerability: enemyNode.vulnerabilityMultiplier,\n            rounding: projectileNode.hitRounding)',
  '            overcharge: projectileNode.overchargeFactor, vulnerability: enemyNode.vulnerabilityMultiplier,\n            rounding: DirectHitRounding(unit: projectileNode.a6Rounding.unit))', [CAT]),
 ('B7-S7-11 the projectile\'s block threshold is copied from its A6 draw', 'Sparkforge/Nodes/ProjectileNode.swift',
  '    let hitRounding = DirectHitRounding()\n', '    lazy var hitRounding = DirectHitRounding(unit: a6Rounding.unit)\n', [CAT]),
 ('B7-S7-12 Forge offense back AFTER the block on the gun (CL-114b)', GS,
  ('        // v1.9 Forge Path (Unit 2b) — Ferocity offensive + Opportunist.\n        // A7b S7 (CL-114b): the last INTEGER step, ahead of the amplifier block.\n        damage = applyForgeOffense(damage,\n                                   healthPercent: enemyNode.healthPercent,\n                                   bossClass: enemyNode.isMiniBoss,\n                                   impaired: enemyNode.isSlowed || enemyNode.isFrozen || enemyNode.isStunned,\n                                   relentlessTarget: enemyNode)\n',
   '            rounding: projectileNode.hitRounding)\n\n        // v1.6: shield reduction applies after all bonuses'),
  ('',
   '            rounding: projectileNode.hitRounding)\n        damage = applyForgeOffense(damage,\n                                   healthPercent: enemyNode.healthPercent,\n                                   bossClass: enemyNode.isMiniBoss,\n                                   impaired: enemyNode.isSlowed || enemyNode.isFrozen || enemyNode.isStunned,\n                                   relentlessTarget: enemyNode)\n\n        // v1.6: shield reduction applies after all bonuses'), [CAT, 'redsmile']),
 # re-pointed in A7b S8: the anchor moved with S8's code; the mutation's contract is unchanged.
 ('B7-S7-13 the gun computes the block but discards it', GS,
  '        var hit = DirectHitDamage.resolve(damage, .onEnemy(\n            permafrostBonus: playerStats.slowedDamageBonus, slowed: enemyNode.isSlowed,',
  '        var hit = DirectHit(basis: damage, dealt: damage)\n        _ = DirectHitDamage.resolve(damage, .onEnemy(\n            permafrostBonus: playerStats.slowedDamageBonus, slowed: enemyNode.isSlowed,', [CAT, 'redsmile']),
 ('B7-S7-14 the sweep passes the wrong flag (Permafrost reads frozen, not slowed)', GS,
  '            permafrostBonus: playerStats.slowedDamageBonus, slowed: enemy.isSlowed,',
  '            permafrostBonus: playerStats.slowedDamageBonus, slowed: enemy.isFrozen,', [CAT]),
 # re-pointed in A7b S8: the anchor moved with S8's code; the mutation's contract is unchanged.
 ('B7-S7-15 applicability: the boss sweep takes Permafrost under an arena-wide slow', GS,
  "        // — with Overcharge's factor and the boss's resolved vulnerability since S8.\n        let hit = DirectHitDamage.resolve(damage, .onBoss(\n            openWoundsBonus: playerStats.bleedingEnemyDamageTaken, bleeding: bossStatus.bleed.isBleeding),",
  "        // — with Overcharge's factor and the boss's resolved vulnerability since S8.\n        let hit = DirectHitDamage.resolve(damage, .onEnemy(\n            permafrostBonus: playerStats.slowedDamageBonus, slowed: false, arenaSlowed: playerStats.globalEnemySlow > 0,\n            brittleCold: false, brittleColdFactor: 1, frozen: false, stunned: false,\n            openWoundsBonus: playerStats.bleedingEnemyDamageTaken, bleeding: bossStatus.bleed.isBleeding),", [CAT]),
 ('B7-S7-16 a truncating Open Wounds step creeps back in after the gun\'s boss block', GS,
  '            rounding: projectileNode.hitRounding)\n\n        // v2.1 A4a: bosses take DoTs',
  '            rounding: projectileNode.hitRounding)\n        if playerStats.bleedingEnemyDamageTaken > 0 && bossStatus.bleed.isBleeding {\n            damage = Int(CGFloat(damage) * (1.0 + playerStats.bleedingEnemyDamageTaken))\n        }\n\n        // v2.1 A4a: bosses take DoTs', [CAT, 'redsmile']),
 ('B7-S7-17 an extra write between the sweep\'s boss block and its takeDamage', GS,
  '            rounding: DirectHitRounding())\n        // A kill is credited by the boss\'s own `onLethalHit` chokepoint.',
  '            rounding: DirectHitRounding())\n        damage = max(1, damage - 1)\n        // A kill is credited by the boss\'s own `onLethalHit` chokepoint.', [CAT]),
 # re-pointed in A7b S8: the anchor moved with S8's code; the mutation's contract is unchanged.
 ("B7-S7-18 Braceguard's halving moves ahead of the sweep's block", GS,
  ('            rounding: DirectHitRounding())\n\n        if shielded { hit.shield(by: BraceguardNode.shieldDamageMultiplier) }\n', '        damage = applyForgeOffense(damage,\n                                   healthPercent: enemy.healthPercent,\n'),
  ('            rounding: DirectHitRounding())\n\n', '        if shielded { damage = max(1, Int(CGFloat(damage) * BraceguardNode.shieldDamageMultiplier)) }\n        damage = applyForgeOffense(damage,\n                                   healthPercent: enemy.healthPercent,\n'), [CAT]),
 ('B7-S7-19 G2-1: the Permafrost detail reverts', UM,
  'detail: "Your projectiles and Red Smile sweeps deal 25% more damage to slowed enemies, whatever slowed them. Damage between whole numbers rounds up by chance.",',
  'detail: "Slowed enemies take 25% more damage, regardless of the slow\'s source.",', [CAT]),
 # --- S7 corrective 8: the independent review of freeze 12 (FAIL, proof strength only)
 # found two production-shaped mutants that survived every harness. Retained VERBATIM
 # (the Reviewer's exact strings, reproductions.json) and killed by the executed
 # distribution checks on the default draw (DH7) and on 20,000 REAL projectiles (RP).
 ('B7-S7R-1 REVIEW-S7 rng-two-point: the block threshold\'s default draw is two-point, not uniform', 'Sparkforge/Systems/DirectHitDamage.swift',
  'init(unit: CGFloat = CGFloat.random(in: 0..<1))', 'init(unit: CGFloat = Bool.random() ? 0.0 : 0.999999)', ['damage-pipeline', VULN]),
 ('B7-S7R-2 REVIEW-S7 projectile-discard-draw: a shot draws its threshold, then keeps a constant ½', 'Sparkforge/Nodes/ProjectileNode.swift',
  'let hitRounding = DirectHitRounding()', 'let hitRounding = DirectHitRounding().unit >= 0 ? DirectHitRounding(unit: 0.5) : DirectHitRounding()', [VULN, CAT]),
 # --- S8: G1.9 94b/94c — the resolved vulnerability and Overcharge join the one block
 # (CL-114b), Overcharge leaves the base (CL-114a), direct hits use the target's direct
 # entry (CL-114c), Overkill / Chain Lightning keep the pre-vulnerability basis (CL-114d).
 # Defined at S8; RUN in the consolidated regression pass (Brandon, Oct 1: per-slice
 # mutation runs deferred).
 ('B7-S8-1 EnemyNode\'s direct entry applies the vulnerability again', 'Sparkforge/Nodes/EnemyNode.swift',
  '        let scaled = resolved ?? (vulnerabilityMultiplier == 1.0\n',
  '        let scaled = resolved.map { Int((CGFloat($0) * vulnerabilityMultiplier).rounded()) } ?? (vulnerabilityMultiplier == 1.0\n', [VULN]),
 ('B7-S8-2 the Slag Titan\'s direct entry applies the vulnerability again', 'Sparkforge/Nodes/BossNode.swift',
  '        let scaled = resolved ?? (vulnerabilityMultiplier == 1.0\n',
  '        let scaled = resolved.map { Int((CGFloat($0) * vulnerabilityMultiplier).rounded()) } ?? (vulnerabilityMultiplier == 1.0\n', [VULN]),
 ('B7-S8-3 the DEF dial\'s execute check reads the post-vulnerability value', 'Sparkforge/Nodes/ArenaBossNode.swift',
  'takeDamage(hit.basis, ignoresChallengeDEF: ignoresChallengeDEF, resolved: hit.dealt)',
  'takeDamage(hit.dealt, ignoresChallengeDEF: ignoresChallengeDEF, resolved: hit.dealt)', [VULN, CAT]),
 ('B7-S8-4 the block drops the resolved vulnerability (dealt = basis)', 'Sparkforge/Systems/DirectHitDamage.swift',
  '                         dealt: VoidRounding.damage(exact * vulnerability, unit: rounding.unit))',
  '                         dealt: VoidRounding.damage(exact, unit: rounding.unit))', ['damage-pipeline', VULN]),
 ('B7-S8-5 the vulnerability rounds separately (two roundings, not one)', 'Sparkforge/Systems/DirectHitDamage.swift',
  '                         dealt: VoidRounding.damage(exact * vulnerability, unit: rounding.unit))',
  '                         dealt: VoidRounding.damage(CGFloat(VoidRounding.damage(exact, unit: rounding.unit)) * vulnerability, unit: rounding.unit))', ['damage-pipeline']),
 ('B7-S8-6 the block ignores Overcharge\'s factor', 'Sparkforge/Systems/DirectHitDamage.swift',
  '        let exact = CGFloat(prefix) * amplifiers.product * overcharge\n',
  '        let exact = CGFloat(prefix) * amplifiers.product\n', ['damage-pipeline']),
 ('B7-S8-7 the split floors the whole multiplier (Overcharge counted twice)', 'Sparkforge/Systems/DirectHitDamage.swift',
  '    var base: Int { max(1, Int(overchargeFree)) }', '    var base: Int { max(1, Int(multiplier)) }', ['damage-pipeline']),
 ('B7-S8-8 fireProjectile keeps Overcharge in the shot\'s base', GS,
  '            pierces: playerStats.pierceCount,\n            damageMultiplier: overcharge.overchargeFree,',
  '            pierces: playerStats.pierceCount,\n            damageMultiplier: overcharge.multiplier,', [CAT]),
 ('B7-S8-9 the sweep base reads shotFractionDamage again (Overcharge in the base)', GS,
  '        var damage = overcharge.base\n', '        var damage = playerStats.shotFractionDamage(GameConfig.RedSmile.damageFraction)\n', [CAT]),
 ('B7-S8-10 an excluded shot (the acorn) gets the Overcharge split', GS,
  '            damageMultiplier: playerStats.effectiveDamageMultiplier\n                * GameConfig.NatureCanon.acornDamageFraction,',
  '            damageMultiplier: OverchargeSplit(playerStats.overchargeParts(scale: GameConfig.NatureCanon.acornDamageFraction)).overchargeFree,', [CAT]),
 ('B7-S8-11 Overkill / Chain Lightning read the post-vulnerability value (CL-114d)', GS,
  '        // A7b S8 (CL-114d): Overkill and Chain Lightning keep the pre-vulnerability basis.\n        damage = hit.basis\n',
  '        // A7b S8 (CL-114d): Overkill and Chain Lightning keep the pre-vulnerability basis.\n        damage = hit.dealt\n', [CAT, 'redsmile']),
 ('B7-S8-12 Braceguard halves only the delivered value', 'Sparkforge/Systems/DirectHitDamage.swift',
  '        basis = max(1, Int(CGFloat(basis) * multiplier))\n', '', ['damage-pipeline']),
 ('B7-S8-13 the Spurhound\'s direct entry skips its punish window', 'Sparkforge/Nodes/SpurhoundNode.swift',
  '        super.takeDirectHit(DirectHit(basis: hit.basis, dealt: punished(hit.dealt)))\n', '        super.takeDirectHit(hit)\n', [CAT]),
 ('B7-S8-14 the gun\'s boss hit enters through takeDamage (vulnerability applied twice)', GS,
  '        bossNode.takeDirectHit(hit, ignoresChallengeDEF: projectileNode.voidHit.flatDEFPenetration)\n',
  '        bossNode.takeDamage(hit.dealt, ignoresChallengeDEF: projectileNode.voidHit.flatDEFPenetration)\n', [CAT, 'redsmile', 'void']),
 ('B7-S8-15 the Overcharge-free multiplier still includes Overcharge', 'Sparkforge/Systems/PlayerStats.swift',
  '    var overchargeFreeDamageMultiplier: CGFloat {\n        var total = damageMultiplier\n',
  '    var overchargeFreeDamageMultiplier: CGFloat {\n        var total = damageMultiplier + overchargeCurrentBonus\n', ['damage-pipeline', CAT]),
 # --- S9: G1.10 the replacement icicle's crit + Calculated Strike (CL-117) ---
 ('B7-S9-1 the icicle never crits again (CL-117)', GS,
  '            isCrit: isCrit,\n            spawnsGravityWell: false,', '            isCrit: false,\n            spawnsGravityWell: false,', [CAT]),
 ('B7-S9-2 the icicle no longer counts toward Calculated Strike', GS,
  'let isCrit = rollShotCrit(directAttack: true)', 'let isCrit = rollShotCrit(directAttack: false)', [CAT]),
 ('B7-S9-3 the icicle\'s own shatter shards crit again', GS,
  '                           rollsCrit: false,   // v2.1 A7b S9 (CL-117): the icicle\'s crit stays on the icicle\n', '', [CAT]),
 ('B7-S9-4 Iceburst\'s shards stop critting (they aren\'t the icicle\'s)', GS,
  '                           damageScale: GameConfig.PolarVortex.shardMult,\n                           allowModifiers: false,\n',
  '                           damageScale: GameConfig.PolarVortex.shardMult,\n                           allowModifiers: false,\n                           rollsCrit: false,\n', [CAT]),
 ('B7-S9-5 the absorbed pellets roll crit and count toward Calculated Strike', GS,
  '            return\n        }\n\n        // v2.1 A7b S9 (CL-117): the icicle\'s own shatter shards don\'t roll crit.',
  '            _ = rollShotCrit(directAttack: true)\n            return\n        }\n\n        // v2.1 A7b S9 (CL-117): the icicle\'s own shatter shards don\'t roll crit.', [CAT]),
 ('B7-S9-6 Calculated Strike counts every shot, fragments and shards included', GS,
  '        if playerStats.forgeCalculatedStrike && directAttack {', '        if playerStats.forgeCalculatedStrike {', [CAT]),
 ('B7-S9-7 every other shot loses its crit roll (the default flips)', GS,
  '                                rollsCrit: Bool = true,', '                                rollsCrit: Bool = false,', [CAT]),
 # --- S10: G1.11 Shatter (CL-99, CL-118) and the Chill copy batch (G2-2/3/4/6) ---
 ('B7-S10-1 elites are executed again (the pre-S10 rule)', SHATTER,
  '        guard elite else { return .execute }\n', '        return .execute\n', [CHILL, VULN]),
 ('B7-S10-2 the elite chunk loses its floor of 1', SHATTER,
  '        return .chunk(AnomalyState.chunkDamage(maxHealth: maxHealth,\n                                               fraction: GameConfig.Chill.shatterEliteFraction))',
  '        return .chunk(Int(CGFloat(maxHealth) * GameConfig.Chill.shatterEliteFraction))', [CHILL]),
 ('B7-S10-3 the threshold turns strict (exactly 40% no longer shatters)', SHATTER,
  'totalSlow >= threshold', 'totalSlow > threshold', [CHILL]),
 ('B7-S10-4 an unslowed foe can shatter on the arena\'s slow alone', SHATTER,
  'guard chance > 0, slowed, totalSlow', 'guard chance > 0, totalSlow', [CHILL]),
 ('B7-S10-5 a chunk ends the hit even when the elite survives (CL-118a)', SHATTER,
  '    var endsHit: Bool { self == .execute }', '    var endsHit: Bool { true }', [CHILL]),
 ('B7-S10-6 an execute that doesn\'t kill lets the hit go on', SHATTER,
  '    var endsHit: Bool { self == .execute }', '    var endsHit: Bool { false }', [CHILL]),
 ('B7-S10-7 the elite chunk takes the boss fraction', SHATTER,
  'fraction: GameConfig.Chill.shatterEliteFraction))', 'fraction: GameConfig.Chill.spikeBossFraction))', [CHILL, VULN]),
 ('B7-S10-8 the roll admits roll == chance', SHATTER,
  'roll < chance', 'roll <= chance', [CHILL]),
 ('B7-S10-9 the gun\'s Shatter exit returns past both meters (A4c F2\'s twin, CL-118c)', GS,
  '                apexRegisterAttack()\n                erasureRegisterHit()\n                if let index = projectiles.firstIndex',
  '                if let index = projectiles.firstIndex', ['redsmile', CAT]),
 ('B7-S10-10 the gun\'s Shatter exit charges Apex but not Erasure', GS,
  '                apexRegisterAttack()\n                erasureRegisterHit()\n                if let index = projectiles.firstIndex',
  '                apexRegisterAttack()\n                if let index = projectiles.firstIndex', ['redsmile', CAT]),
 ('B7-S10-11 the gun\'s Shatter kill drops the Iceburst generation (CL-118c)', GS,
  'source: projectileNode.killSource,\n                              iceburstGeneration: projectileNode.iceburstGeneration)\n            }\n            if killed || shatter.endsHit {',
  'source: projectileNode.killSource)\n            }\n            if killed || shatter.endsHit {', [CAT]),
 ('B7-S10-12 the gun\'s surviving elite never takes the rest of the hit (CL-118a)', GS,
  '            if killed || shatter.endsHit {\n                // CL-118c', '            if true {\n                // CL-118c', ['redsmile', CAT]),
 ('B7-S10-13 the sweep\'s surviving elite never takes the rest of the swing (CL-118a)', GS,
  '            if killed || shatter.endsHit {\n                // A landed Shatter', '            if true {\n                // A landed Shatter', [CAT]),
 ('B7-S10-14 the gun\'s Shatter ignores the arena\'s slow', GS,
  'totalSlow: enemyNode.currentSlow + playerStats.globalEnemySlow,', 'totalSlow: enemyNode.currentSlow,', [CAT]),
 ('B7-S10-15 the gun\'s shatter lands through the direct entry (the vulnerability skips the chunk)', GS,
  'let killed = enemyNode.takeDamage(shatter.damage(health: enemyNode.health))',
  'let killed = enemyNode.takeDirectHit(DirectHit(basis: shatter.damage(health: enemyNode.health), dealt: shatter.damage(health: enemyNode.health)))', [CAT]),
 ('B7-S10-16 Absolute Zero no longer lowers the threshold', UM,
  'stats.shatterSlowThreshold = GameConfig.Chill.absoluteZeroShatterThreshold', 'stats.shatterSlowThreshold = GameConfig.Chill.shatterSlowThreshold', [CHILL, CAT]),
 ('B7-S10-17 a run reset keeps the last threshold', 'Sparkforge/Systems/PlayerStats.swift',
  '        shatterSlowThreshold = GameConfig.Chill.shatterSlowThreshold\n', '', [CHILL, CAT]),
 ('B7-S10-18 the Shatter line reverts to "Frozen enemies burst when struck" (G2-2)', UM,
  'effect: "Slowed foes may shatter (elites: 20% HP)")', 'effect: "Frozen enemies burst when struck")', [CAT]),
 ('B7-S10-19 Whiteout\'s detail drops the elite duration (G2-6)', UM,
  'snowman for 3s (elites for half as long). Each enemy', 'snowman for 3s. Each enemy', [CAT]),
 ('B7-S10-20 Glacial Drift\'s detail drops "non-boss" (G2-4)', UM,
  'slowing non-boss enemies by 50%', 'slowing enemies by 50%', [CAT]), # --- S11: CL-119 A1 Erasure's lone-boss fallback, CL-120 B1' Unstable Core ---
 ('B7-S11-1 a full meter never falls back to a lone boss (CL-119 A1)', GS,
  '            } else if let b = boss, isHittable(b) {\n                releaseUnstableCharge()\n                triggerUnstable(onBoss: b)\n            }\n',
  '            }\n', [CAT]),
 ('B7-S11-2 the fallback lurches at a vanished boss (the Faceted Lie\'s charge no longer holds)', GS,
  '} else if let b = boss, isHittable(b) {', '} else if let b = boss, !b.isDead {', [CAT]),
 ('B7-S11-3 a boss lurch rolls the whole table', GS,
  '        switch Int.random(in: 0..<3) {\n        case 0: erasureRiftBurst(at: pos, includeBoss: true)',
  '        switch Int.random(in: 0..<7) {\n        case 0: erasureRiftBurst(at: pos, includeBoss: true)', [CAT]),
 ('B7-S11-4 the boss Rift Burst misses the boss', GS,
  'case 0: erasureRiftBurst(at: pos, includeBoss: true)', 'case 0: erasureRiftBurst(at: pos)', [CAT]),
 ('B7-S11-5 the boss Damage Echo lands at full (not the boss-class 50%)', GS,
  'b.takeDamage(GameConfig.BossClass.scaledDamage(dmg, isBossClass: true))\n            }\n        ]))',
  'b.takeDamage(dmg)\n            }\n        ]))', [CAT]),
 ('B7-S11-6 the boss Fracture never ends', GS,
  '        if bossFractureWindow.tick(dt) { b.vulnerability.clear(.fracture) }   // v2.1 A7b S11 (CL-119 A1)\n', '', [CAT]),
 ('B7-S11-7 a boss lurch doesn\'t advance the Rift Cannon', GS,
  '        default: erasureFracture(onBoss: bossNode)\n        }\n        fireRiftCannonIfDue()\n',
  '        default: erasureFracture(onBoss: bossNode)\n        }\n', [CAT]),
 ('B7-S11-8 Unstable Core still costs you with nothing in range (CL-120)', GS,
  'if !playerStats.unbrokenWindow.isActive && struck {', 'if !playerStats.unbrokenWindow.isActive {', [CAT]),
 ('B7-S11-9 a dying body counts as struck', GS,
  '                if !enemy.isDying { struck = true }\n', '                struck = true\n', [CAT]),
 ('B7-S11-10 a new boss inherits the old boss\'s Fracture window', GS,
  '        bossFractureWindow = GameTimer()   // v2.1 A7b S11: nor an Erasure Fracture window\n', '', [CAT]),
 # --- S12: CL-127a hittability for every targeter, CL-126 the gun's auto-aim ---
 # B7-S12-1/2/3/5 re-pointed in A7b S13: the loops became nearestVisible(…) calls; same contracts
 ('B7-S12-1 Chain Lightning jumps onto a phased body', GS,
  'among: enemies.filter { e in isHittable(e) && !visited.contains(where: { $0 === e }) },',
  'among: enemies.filter { e in !e.isDying && !visited.contains(where: { $0 === e }) },', [CAT]),
 ('B7-S12-2 the Electro Pulse targets a phased body', GS,
  '            from: player.position, among: enemies.filter { isHittable($0) },',
  '            from: player.position, among: enemies.filter { !$0.isDying },', [CAT]),
 ('B7-S12-3 a Sentry coil shocks a phased body', GS,
  '                from: origin, among: enemies.filter { isHittable($0) },',
  '                from: origin, among: enemies.filter { !$0.isDying },', [CAT]),
 ('B7-S12-4 a Sentry coil shocks the vanished Faceted Lie', GS,
  '} else if let b = boss, isHittable(b), origin.distance', '} else if let b = boss, !b.isDead, origin.distance', [CAT]),
 ('B7-S12-5 Relay Burn arcs onto dying and phased bodies again', GS,
  'among: enemies.filter { $0 !== source && isHittable($0) },', 'among: enemies.filter { $0 !== source },', [CAT]),
 ('B7-S12-6 the gun aims at a phased enemy (CL-126)', GS,
  '        for enemy in enemies where isHittable(enemy) {\n            let dist = player.position.distance(to: enemy.position)\n            if dist < range && dist < closestDist {',
  '        for enemy in enemies where !enemy.isDying {\n            let dist = player.position.distance(to: enemy.position)\n            if dist < range && dist < closestDist {', [CAT]),
 ('B7-S12-7 the gun aims at the vanished Faceted Lie (CL-126)', GS,
  '        if let boss = boss, isHittable(boss) {', '        if let boss = boss, !boss.isDead {', [CAT]),
 ('B7-S12-8 the gun homes on an intangible lassoed prey (CL-126)', GS,
  'let node = lassoTargetNode, isHittableTarget(node),', 'let node = lassoTargetNode,', [CAT]),
 ('B7-S11-11 Erasure\'s T1 rung claims "bosses too" (the CL-119 copy constraint)', UM,
  'full meter → a lurch (a lone boss: 50%)"', 'full meter → a lurch, bosses too"', [CAT]),
 ('B7-S11-12 Everglow\'s detail drops the pulse\'s boss exclusion (CL-121 C2)', UM,
  'The pulse skips bosses; mini-bosses take half. Bosses', 'Mini-bosses take half pulse damage. Bosses', [CAT]), # --- S13: CL-109 / CL-123 arcs and hops see their target; Skybeam homing LOS ---
 ('B7-S13-1 nearestVisible ignores the Carrier (arcs cross the slab)', 'Sparkforge/Config/ArenaGeometry.swift',
  '            if segmentBlockedExact(origin, p, travelRadius: travelRadius) { continue }\n', '', ['geometry', CAT]),
 ('B7-S13-2 nearestVisible takes the first visible, not the nearest', 'Sparkforge/Config/ArenaGeometry.swift',
  '            best = candidate\n            bestDistance = d\n', '            return candidate\n', ['geometry']),
 ('B7-S13-3 nearestVisible admits a target exactly at the range', 'Sparkforge/Config/ArenaGeometry.swift',
  '            guard d < bestDistance else { continue }', '            guard d <= bestDistance else { continue }', ['geometry']),
 ('B7-S13-4 Chain Lightning hops ignore the Carrier', GS,
  'guard let target = arenaGeometry.nearestVisible(\n                from: from, among:', 'guard let target = ArenaGeometry.open.nearestVisible(\n                from: from, among:', [CAT]),
 ('B7-S13-5 the T4 network loses its exemption (or T1–T3 lose sight)', GS,
  'let sight = network ? ArenaGeometry.open : arenaGeometry', 'let sight = arenaGeometry', [CAT]),
 ('B7-S13-6 the coils\' boss fallback ignores the Carrier', GS,
  ',\n                      !sight.segmentBlockedExact(origin, b.position, travelRadius: GameConfig.Geometry.arcTravelRadius) {', ' {', [CAT]),
 ('B7-S13-7 Skybeam homing hands auto-aim an occluded prey again', GS,
  '            if !(solid && arenaGeometry.segmentBlocked(\n                    player.position, node.position,', '            if !(false && arenaGeometry.segmentBlocked(\n                    player.position, node.position,', [CAT]),
 # --- S14: CL-124 one path-tested shove; the Vine Wall order; lion, flowers, Rich Soil ---
 ('B7-S14-1 pathShove never stops (shoves go through the Carrier)', 'Sparkforge/Config/ArenaGeometry.swift',
  '        guard segmentBlockedExact(from, to, travelRadius: radius) else { return to }', '        return to', ['geometry']),
 ('B7-S14-2 pathShove keeps the blocked half (lands inside the Carrier)', 'Sparkforge/Config/ArenaGeometry.swift',
  '        return from + (to - from) * lo\n    }\n\n    /// The safe anchor', '        return from + (to - from) * hi\n    }\n\n    /// The safe anchor', ['geometry']),
 ('B7-S14-3 the rescue shove skips the path test again', GS,
  'shove(enemy, along: enemy.position - player.position, by: 40)   // v2.1 A7b S14 (CL-124a)\n                }\n            }\n            worldNode.shake(intensity: 8, duration: 0.25)\n            damageCooldownTimer = 1.0  // Generous',
  'enemy.position += (enemy.position - player.position).normalized * 40\n                }\n            }\n            worldNode.shake(intensity: 8, duration: 0.25)\n            damageCooldownTimer = 1.0  // Generous', [CAT]),
 ('B7-S14-4 the deer\'s knock skips the path test', GS,
  'self.shove(e, along: e.position - origin, by: GameConfig.NatureCanon.deerKnockback)', 'e.position += (e.position - origin).normalized * GameConfig.NatureCanon.deerKnockback', [CAT]),
 ('B7-S14-5 Implosion\'s pull skips the path test', GS,
  'shove(e, along: pos - e.position, by: GameConfig.Erasure.implosionPull)', 'e.position += (pos - e.position).normalized * GameConfig.Erasure.implosionPull', [CAT]),
 ('B7-S14-6 the Vine Wall pushes after the frame\'s resolve again', GS,
  '        applyVineWallEdge(dt)    // v2.1 A7b S14: the hedge\'s push, by the same rule\n', '', [CAT]),
 ('B7-S14-7 the lion walks into the Carrier (no resolve)', GS,
  '        lion.position = arenaGeometry.resolve(lion.position, actorRadius: GameConfig.Tree.lionFootprintRadius)\n', '', [CAT]),
 ('B7-S14-8 a flower may root past the arena wall', 'Sparkforge/Config/ArenaGeometry.swift',
  'if p.length + margin <= arenaRadius, !geometry.isBlocked(p, margin: margin) { return p }', 'if !geometry.isBlocked(p, margin: margin) { return p }', ['geometry']),
 ('B7-S14-9 Rich Soil skips the garden cap again', GS,
  '            zone.setRadius(min(cap, zone.radius * radiusScale))', '            zone.setRadius(zone.radius * radiusScale)', [CAT]),
 # --- S15: CL-127d boss hazards reach the live body ---
 ('B7-S15-1 the scene never writes the live radius (hazards keep the constant)', GS,
  '        (boss as? PlayerReachHazards)?.playerHitRadius = playerStats.effectiveCollisionRadius\n', '', [CAT]),
 ('B7-S15-2 the Faceted Lie\'s plates reach the unshrunk body', 'Sparkforge/Nodes/FacetedLieNode.swift',
  'FacetedLieNode.falseSafePlateReach + playerHitRadius', 'FacetedLieNode.falseSafePlateReach + GameConfig.Player.collisionRadius', [CAT]),
 ('B7-S15-3 the Quench Field clamps the unshrunk body', GS,
  '                let maxDist = GameConfig.Arena.radius - playerStats.effectiveCollisionRadius\n                if player.position.length > maxDist {\n                    player.position = player.position.normalized * maxDist\n                }\n                resolvePlayerAgainstGeometry(cause: .pull)',
  '                let maxDist = GameConfig.Arena.radius - GameConfig.Player.collisionRadius\n                if player.position.length > maxDist {\n                    player.position = player.position.normalized * maxDist\n                }\n                resolvePlayerAgainstGeometry(cause: .pull)', [CAT]),
 ('B7-S15-4 the Dynamo Choir stops adopting the live radius', 'Sparkforge/Nodes/DynamoChoirNode.swift',
  'ArenaBossNode, PlayerReachHazards {', 'ArenaBossNode {', [VULN, CAT]), # --- S16: CL-125's retained invariant ---
 ('B7-S16-1 the Unmade Star arrives without wiping the board (CL-125)', GS,
  '        for e in enemies { e.removeFromParent() }\n        enemies.removeAll()\n\n        // 2) Pickup spawns off for the fight.',
  '\n        // 2) Pickup spawns off for the fight.', [CAT]),
 ('B7-S16-2 wave spawns ignore a boss on the field (CL-125)', GS,
  'if spawnEvent.shouldSpawnEnemy && boss == nil { spawnEnemy() }', 'if spawnEvent.shouldSpawnEnemy { spawnEnemy() }', [CAT]), # --- v2.1 geometry Unit 4: Arena 6 registered + presented; the BGM deck ---
 ('U4-1 the Splitworks is not registered (arena 6 unreachable)', 'Sparkforge/Config/ArenaConfig.swift',
  'starAnvil, splitworks]', 'starAnvil]', [CAT, 'void']),
 ('U4-2 Boss Mode has no Marchwarden spawner (its stage would be skipped)', GS,
  '        case "marchwarden":    spawnMarchwarden()   // v2.1 geometry Unit 4\n', '', [CAT]),
 ('U4-3 clearing Arena 6 grants no Marchworn', GS,
  '            SkinManager.shared.unlockEarned("spark_marchworn")\n', '', [CAT]),
 ('U4-4 a Spurhound kill is booked as a melee enemy', GS,
  '        case is SpurhoundNode:   return .spurhound\n', '', [CAT]),
 ('U4-5 the bestiary\'s Marchwarden line overflows the live wrapper', CM,
  'for an army that will never come."', 'for an army that will never, ever, ever come back to the broken road again."', [CAT]),
 ('U4-6 the deck may open a cycle with the track that just played', 'Sparkforge/Systems/BGMDeck.swift',
  '            remaining.swapAt(0, Int.random(in: 1..<remaining.count, using: &rng))\n', '', ['bgm']),
 ('U4-7 the deck reshuffles mid-cycle', 'Sparkforge/Systems/BGMDeck.swift',
  '        if remaining.isEmpty { reshuffle(using: &rng) }', '        reshuffle(using: &rng)', ['bgm']),
 ('U4-8 a failed track stays in the deck', 'Sparkforge/Systems/BGMDeck.swift',
  '        eligible.removeAll { $0 == track }\n', '', ['bgm']),
 # U4-9 / U4-10 re-pointed after the review (the transport moved into BGMPolicy + perform); same contracts
 ('U4-9 a context change switches the song (not continuous)', 'Sparkforge/Systems/BGMDeck.swift',
  '        case .contextChanged:\n            return hasPlayer ? .none : .startDeck',
  '        case .contextChanged:\n            return .playNext', ['bgm']),
 ('U4-10 BGM ON draws a new song instead of resuming', 'Sparkforge/Systems/MusicManager.swift',
  '        case .resume:\n            if let current = player { resume(current, fadeIn: fadeIn) }',
  '        case .resume:\n            playNext(fadeIn: true)', [CAT]),
 # --- v2.1 geometry Unit 4: the independent review's fixes ---
 ('U4-11 the last arena\'s title card ignores its own line (review M1)', 'Sparkforge/Scenes/TitleScene.swift',
  'arenaReadyLabel.text = arena.finalFelledLine.isEmpty', 'arenaReadyLabel.text = true', [CAT]),
 ('U4-12 a Boss Mode swap leaves gardens and flowers where they were (review m4)', GS,
  '        cultivatedZones.forEach(clamp)\n        flowers.forEach(clamp)\n', '', [CAT]),
 # U4-13 re-pointed after the re-review (the refusal now goes through deck.refused); same contract
 ('U4-13 a refused start drops the track for the session (review m2)', 'Sparkforge/Systems/MusicManager.swift',
  '                let dropped = deck.refused(url)', '                deck.failed(url); let dropped = true', [CAT]),
 ('U4-14 the user-audio check runs at every song change (review N1)', 'Sparkforge/Systems/MusicManager.swift',
  '        if !everStarted, AVAudioSession.sharedInstance().isOtherAudioPlaying {', '        if AVAudioSession.sharedInstance().isOtherAudioPlaying {', [CAT]),
 ('U4-15 an ended interruption draws a new song (the reviewer\'s surviving mutant)', 'Sparkforge/Systems/BGMDeck.swift',
  '        case .toggledOn, .interruptionEnded, .becameActive:\n            return hasPlayer ? .resume : .startDeck',
  '        case .toggledOn, .becameActive:\n            return hasPlayer ? .resume : .startDeck\n        case .interruptionEnded:\n            return .playNext', ['bgm']),
 ('U4-16 the Column Advances searches the wrong layer again (review N4)', GS,
  'let solids = self.arenaLayer.children.filter', 'let solids = self.worldNode.children.filter', [CAT]),
 # --- the re-review's follow-ups ---
 ('U4-17 a track refused twice in a row is never dropped (the deck can wedge)', 'Sparkforge/Systems/BGMDeck.swift',
  '        if lastRefused == track {\n            failed(track)', '        if false, lastRefused == track {\n            failed(track)', ['bgm']),
 ('U4-18 BGM OFF neither fades nor pauses', 'Sparkforge/Systems/MusicManager.swift',
  '        case .pause:\n            player?.setVolume(0,', '        case .pause:\n            break\n            player?.setVolume(0,', [CAT]),
 ('U4-19 the START of an interruption resumes the song', 'Sparkforge/Systems/MusicManager.swift',
  'AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }', 'AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }', [CAT]),
 ('U4-20 a decode error keeps the broken track and goes silent', 'Sparkforge/Systems/MusicManager.swift',
  '        perform(.trackBroken, fadeIn: false)', '', [CAT]),
 ('U4-21 the Boss Mode fit ignores the safe area (under the notch)', 'Sparkforge/Scenes/TitleScene.swift',
  'let fit = min(1, (size.height - insets.top - insets.bottom - 16) / panelH)', 'let fit = min(1, (size.height - 16) / panelH)', [CAT]),
]

COPY_DIRS = ['Sparkforge/Systems', 'Sparkforge/Config', 'Sparkforge/Scenes', 'Sparkforge/Nodes', 'Sparkforge/Utils', 'tools', 'docs']
# v2.1 geometry Unit 4: large READ-ONLY assets are linked, not copied (the bgm
# harness's BA1 hashes the 20 tracks; no mutant ever edits them). rmtree unlinks
# a symlink rather than following it, so cleanup never touches the originals.
LINK_DIRS = ['Sparkforge/Audio']


def apply_mutation(text, old, new):
    """→ (mutated text, None) or (None, reason)."""
    import re as _re
    if isinstance(old, RE):
        out, n = _re.subn(old, new, text, flags=_re.S | _re.M)
        return (out, None) if n else (None, '0 regex matches')
    if isinstance(old, (list, tuple)):
        for o, n in zip(old, new):
            if text.count(o) != 1:
                return None, f'{text.count(o)} matches for {o[:40]!r}'
            text = text.replace(o, n)
        return text, None
    if text.count(old) != 1:
        return None, f'{text.count(old)} matches'
    return text.replace(old, new), None


def fresh_copy():
    tmp = tempfile.mkdtemp(prefix='a7a-mut-')
    for d in COPY_DIRS:
        shutil.copytree(os.path.join(ROOT, d), os.path.join(tmp, d),
                        ignore=shutil.ignore_patterns('__pycache__'))
    for d in LINK_DIRS:
        if os.path.isdir(os.path.join(ROOT, d)):
            os.symlink(os.path.join(ROOT, d), os.path.join(tmp, d))
    return tmp


def _canon(tmp, *args):
    return subprocess.run(['python3', os.path.join(tmp, CANON), *args], capture_output=True, text=True, cwd=tmp, timeout=TIMEOUT)


def _edit(tmp, rel, old, new):
    p = os.path.join(tmp, rel)
    text = open(p).read()
    if text.count(old) != 1:
        raise LookupError(f'{rel}: {text.count(old)} matches for {old[:40]!r}')
    open(p, 'w').write(text.replace(old, new))


def _git(tmp):
    def git(*a):
        return subprocess.run(['git', '-c', 'user.name=a7a-suite', '-c', 'user.email=a7a-suite@example.invalid',
                               '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', *a],
                              cwd=tmp, capture_output=True, text=True)
    return git


# One authoritative input changed where the canon can't show it (the sidecar's and
# the expectations' `_about` notes; Panda's chance, which the catalog carries and
# the canon doesn't print; a comment in the generator): only the fingerprint can
# notice these.
UNSEEN_EDITS = {
    'sidecar': (SIDECAR, '"_about": "', '"_about": "Edited after generation. '),
    'expect': ('tools/catalog-expect.json', '"_about": "', '"_about": "Edited after generation. '),
    'catalog': ('Sparkforge/Config/GameConfig.swift', 'static let eligibilityChance: CGFloat = 0.0927', 'static let eligibilityChance: CGFloat = 0.0928'),
    'generator': (CANON, "\nif __name__ == '__main__':", "\n# edited after generation\nif __name__ == '__main__':"),
}
# Positive Atlas controls (baseline): markup changes that alter nothing a reader
# sees or hears must still validate — classes, attribute order and extra
# attributes, tag case, entities, an inline <b> (restyled); the label's wrapper
# removed or replaced (Reviewer 8); a copy that is `hidden` (not a claim: the
# former AH23); invisible characters inside the label.
LBL = '<span class="provenance">{esc(source)}</span>'
ATLAS_POSITIVE = {
    'atlas-restyled': [
        (LBL, '<span data-role="source" class="label-x">Source:&#32;compiled&nbsp;runtime catalog &middot; <b>{EXPECT["total"]}</b>&#x20;cards</span>'),
        ('<span>generated {today}</span>', "<span class='when' data-x=\"1\">generated&nbsp;{today}</span>"),
        ('<div class="stats">', '<DIV data-x="1"   class="stats wide" id="stats">'),
        ('<footer class="page">Generated by', "<FOOTER data-role=\"colophon\"  class='page-x'>Generated by")],
    'atlas-unwrapped': [(LBL, '{esc(source)}')],
    'atlas-rewrapped': [(LBL, '<em class="x">{esc(source)}</em>')],
    'atlas-rewrapped-block': [(LBL, '<div data-k="v">{esc(source)}</div>')],
    'atlas-hidden-copy': [(LBL, LBL + '<span hidden>{esc(source)}</span><span hidden title="{esc(source)}">x</span>')],
    'atlas-invisible-chars': [(LBL, '<span class="provenance">So&#x200B;urce: compiled runtime cat&#x034F;alog · {EXPECT["total"]} cards</span>')],
}
FLOWS = {'git-onecommit', 'git-stale'} | set(ATLAS_POSITIVE) | {f'detects-{k}' for k in UNSEEN_EDITS}


def _flow(tmp, check):
    """The fingerprint's multi-step checks (each on its own copy)."""
    def last(r):
        return (r.stdout + r.stderr).strip().splitlines()[-1][:120] if (r.stdout + r.stderr).strip() else f'exit {r.returncode}'
    doc = os.path.join(tmp, CANON_DOC)
    if check.startswith('detects-'):
        # Regenerate, change one input unseen, --check: must fail on the fingerprint ALONE.
        which = check[len('detects-'):]
        gen = _canon(tmp)
        if gen.returncode != 0:
            return 'fail', f'{check}: generation failed: {last(gen)}'
        _edit(tmp, *UNSEEN_EDITS[which])
        r = _canon(tmp, '--check', doc)
        problems = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith('  ')]
        if r.returncode != 0 and len(problems) == 1 and 'source-input fingerprint' in problems[0]:
            return 'pass', ''
        return 'fail', f'{check}: ' + ('the changed input was accepted' if r.returncode == 0 else f'rejected, but not on the fingerprint alone: {last(r)}')
    if check in ATLAS_POSITIVE:
        for old, new in ATLAS_POSITIVE[check]:
            _edit(tmp, ATLAS, old, new)
        r = subprocess.run(['python3', os.path.join(tmp, ATLAS), os.path.join(tmp, 'atlas.html')],
                           capture_output=True, text=True, cwd=tmp, timeout=TIMEOUT)
        if 'Traceback' in r.stdout + r.stderr:
            return 'invalid', f'{check}: {last(r)}'
        return ('pass', '') if r.returncode == 0 else ('fail', f'{check}: a change that alters nothing a reader sees was rejected: {last(r)}')
    git = _git(tmp)
    git('init', '-q'); git('add', '-A'); git('commit', '-qm', 'base')
    if check == 'git-stale':
        # A source change committed on its own; the canon is not regenerated.
        _edit(tmp, *UNSEEN_EDITS['catalog'])
        git('add', '-A'); git('commit', '-qm', 'source only')
        if git('rev-list', '--count', 'HEAD').stdout.strip() != '2':
            return 'invalid', f'{check}: the throwaway Git history was not built'
        r = _canon(tmp, '--check', doc)
        return ('pass', '') if r.returncode == 0 else ('fail', f'{check}: {last(r)}')
    # git-onecommit — the A7a closeout shape: a source change and its regenerated
    # canon in ONE commit. The fingerprint validates before and after that commit
    # and after a later unrelated one.
    _edit(tmp, UM, 'description: "+11% attack speed"', 'description: "+12% attack speed"')
    steps = [('the old canon is rejected once the source changes', _canon(tmp, '--check', doc).returncode != 0),
             ('regeneration', _canon(tmp).returncode == 0),
             ('--check before the commit', _canon(tmp, '--check', doc).returncode == 0)]
    git('add', '-A'); git('commit', '-qm', 'source and canon, one commit')
    steps.append(('--check after the single commit', _canon(tmp, '--check', doc).returncode == 0))
    open(os.path.join(tmp, 'unrelated.txt'), 'w').write('later')
    git('add', 'unrelated.txt'); git('commit', '-qm', 'unrelated')
    steps.append(('--check after a later unrelated commit', _canon(tmp, '--check', doc).returncode == 0))
    steps.append(('the throwaway Git history (3 commits)', git('rev-list', '--count', 'HEAD').stdout.strip() == '3'))
    bad = [name for name, ok in steps if not ok]
    return ('pass', '') if not bad else ('fail', f'{check}: failed at ' + ', '.join(bad))


def run_check(tmp, check):
    """→ ('pass'|'fail'|'invalid'|'timeout', detail)."""
    if check in FLOWS:
        try:
            return _flow(tmp, check)
        except subprocess.TimeoutExpired:
            subprocess.run(['pkill', '-f', tmp])
            return 'timeout', f'{check} ran past {TIMEOUT}s'
        except LookupError as e:                   # the flow's own edit didn't apply: the suite is stale
            return 'invalid', f'{check}: {e}'
    if check == 'atlas':
        cmd = ['python3', os.path.join(tmp, ATLAS), os.path.join(tmp, 'atlas.html')]
    elif check == 'canon':
        cmd = ['python3', os.path.join(tmp, CANON), os.path.join(tmp, 'canon.md')]
    elif check == 'canon-file':          # the committed packet validates against the catalog
        cmd = ['python3', os.path.join(tmp, CANON), '--check', os.path.join(tmp, 'docs/v2.1-ability-canon.md')]
    else:
        cmd = ['sh', os.path.join(tmp, 'tools', f'{check}-harness', 'run.sh')]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=tmp, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        subprocess.run(['pkill', '-f', tmp])
        return 'timeout', f'{check} ran past {TIMEOUT}s'
    out = r.stdout + r.stderr
    if check in ('atlas', 'canon', 'canon-file'):
        if 'Traceback' in out or 'error:' in out:
            return 'invalid', out.strip().splitlines()[-1][:160]
        return ('pass', '') if r.returncode == 0 else ('fail', f'{check}: ' + out.strip().splitlines()[-1][:120])
    # A printed FAIL is an assertion, even when the harness stops early (RS0
    # exits rather than spin on a broken generator). No FAIL and no summary
    # means it didn't compile or crashed: INVALID, never coverage.
    fails = [l.split('  ')[1].split(' ')[0] for l in out.splitlines() if l.startswith('FAIL')]
    if fails:
        return 'fail', ', '.join(f'{check}:{f}' for f in fails[:6])
    if 'passed' not in out:
        return 'invalid', next((l for l in out.splitlines() if 'error:' in l), out[-160:])[:160]
    return 'pass', ''


def run_one(m):
    name, rel, old, new, checks = m
    if rel is not None and any(rel == d or rel.startswith(d + '/') for d in LINK_DIRS):
        # A linked dir is the REAL repo's (fresh_copy symlinks it): editing it
        # would write through. Refuse before copying (independent review N5).
        return name, 'INVALID', f'{rel} is under a linked read-only dir'
    tmp = fresh_copy()
    try:
        if rel is not None:                     # None: an environment/Git control, no source edit
            p = os.path.join(tmp, rel)
            mutated, why = apply_mutation(open(p).read(), old, new)
            if mutated is None:
                return name, 'NO-MATCH', why
            open(p, 'w').write(mutated)
        killed = []
        for c in checks:
            verdict, detail = run_check(tmp, c)
            if verdict in ('invalid', 'timeout'):
                return name, verdict.upper(), detail
            if verdict == 'fail':
                killed.append(detail)
        return name, ('KILLED' if killed else 'SURVIVED'), '; '.join(killed)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    # For the log only: every copy recomputes the fingerprint itself (no Git, no environment).
    fp = subprocess.run(['python3', os.path.join(ROOT, CANON), '--fingerprint'],
                        capture_output=True, text=True, cwd=ROOT, check=True).stdout.strip().splitlines()[-1]
    print(f'source-input {fp}', flush=True)
    args = sys.argv[1:]
    jobs = 4
    if '-j' in args:
        i = args.index('-j'); jobs = int(args[i + 1]); del args[i:i + 2]
    chosen = [m for m in M if not args or any(m[0].startswith(a) for a in args)]
    # The baseline: the unmutated tree must pass every check the chosen mutants use.
    tmp = fresh_copy()
    positive = sorted({c for m in chosen for c in m[4] if c != 'git-stale'}
                      | ({'canon', 'canon-file', 'git-onecommit'} | {f for f in FLOWS if f.startswith('detects-')}
                         if any(c.startswith(('canon', 'git', 'detects')) for m in chosen for c in m[4]) else set())
                      | (set(ATLAS_POSITIVE) if any(c == 'atlas' for m in chosen for c in m[4]) else set()))
    try:
        for c in positive:
            where = fresh_copy() if c in FLOWS else tmp    # a flow edits its copy: it gets its own
            try:
                verdict, detail = run_check(where, c)
            finally:
                if where != tmp:
                    shutil.rmtree(where, ignore_errors=True)
            if verdict != 'pass':
                print(f'BASELINE FAILED: {c} → {verdict} {detail}')
                sys.exit(2)
        print(f'baseline: the unmutated tree passes {positive}', flush=True)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        for name, verdict, detail in pool.map(run_one, chosen):
            results[name] = verdict
            print(f'{verdict:9} {name}  [{detail}]', flush=True)
    killed = sum(v == 'KILLED' for v in results.values())
    print(f'\n{killed}/{len(chosen)} killed')
    sys.exit(0 if killed == len(chosen) else 1)


if __name__ == '__main__':
    main()
