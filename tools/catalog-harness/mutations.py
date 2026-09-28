#!/usr/bin/env python3
"""A7a retained mutation suite (test support — tools/ is not in the app target).

Each mutant is an exact-string edit (or a short list of them, applied in
order, each matching exactly once; or `RE(pattern)` → every regex match) on a throwaway copy of the repo
(Sparkforge/Systems, Config, Scenes, tools, docs); the listed checks then run
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
CM = 'Sparkforge/Systems/CodexManager.swift'
ATLAS, CANON = 'tools/generate-card-atlas.py', 'tools/generate-ability-canon.py'
CANON_DOC = 'docs/v2.1-ability-canon.md'
SIDECAR = 'docs/v2.1-ability-canon-sidecar.json'
CAT, CHILL, SIG, GUARD = 'catalog', 'chill', 'signature-draw', 'guard'
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
 ('Q2 deferred Permafrost copy touched', UM, 'description: "Slowed enemies take +25% damage",', 'description: "Direct hits on slowed enemies take +25% damage",', [CAT]),
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
]

COPY_DIRS = ['Sparkforge/Systems', 'Sparkforge/Config', 'Sparkforge/Scenes', 'tools', 'docs']


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
