// ParityAttribution.swift — v2.2 Neutral rework, N1 corrective pass (Oct 12).
// Test support only; compiled by tools/catalog-harness/run.sh, never by the app.
//
// Replaces ParityMask (independent review, must-fix 1): that kit deleted three
// PlayerStats fields from both sides everywhere, so an unrelated change to any
// other writer of those fields (Surge's move bonus doubled) passed unseen.
//
// This kit never masks. The frozen legacy fixtures stay the record; from them
// and the reviewed overlay it builds the EXPECTED current document explicitly,
// then the harness requires the actual document to equal it:
//   • a retired card's own records are gone, and every start state, scenario
//     and recorded run that took it loses exactly the legacy contribution the
//     fixture itself recorded for that card (cards[id].default, per tier);
//   • a rewritten card's own records become the overlay's reviewed expectation,
//     and every state / scenario / run that took it shifts by
//     (overlay delta − legacy delta) for the tier taken;
//   • everything else — every other card and synergy on EVERY field, every
//     scenario step, every run's final state — must equal the record.
// The attribution is per card and per tier. Values in the attributed fields
// are compared as numbers within 1e-12 (the expected value is the same sum in
// a different order); every other leaf is compared byte for byte.

import Foundation

struct ParityOverlay {
    let unit: String
    let retired: Set<String>
    let fields: Set<String>
    let cards: [String: Any]                 // dump-shaped records for the rewritten cards
    let expectedDeltas: [String: [[String: [String]]]]
    let retiredNotes: [String: String]
    let counts: [String: Int]
    /// PlayerStats stored fields that did not exist in the legacy record → their default leaves (v2.2 N2).
    let addedFields: [String: String]
    /// Fields every writer of which MULTIPLIES (v2.2 N4: `fireRateMultiplier`,
    /// rate ratios). Their effects are ratios, their shifts compose by product.
    let multiplicativeFields: Set<String>

    init?(json: [String: Any]) {
        guard let unit = json["unit"] as? String,
              let retired = json["retired"] as? [String],
              let fields = json["fields"] as? [String],
              let cards = json["cards"] as? [String: Any],
              let deltas = json["expectedDeltas"] as? [String: [[String: [String]]]],
              let notes = json["retiredNotes"] as? [String: String],
              let counts = json["counts"] as? [String: Int] else { return nil }
        self.unit = unit
        self.retired = Set(retired)
        self.fields = Set(fields)
        self.cards = cards
        self.expectedDeltas = deltas
        self.retiredNotes = notes
        self.counts = counts
        self.addedFields = (json["addedFields"] as? [String: String]) ?? [:]
        self.multiplicativeFields = Set((json["multiplicativeFields"] as? [String]) ?? [])
    }

    /// Cards whose EFFECT the overlay rewrites (they have an expectation).
    var rewritten: Set<String> { Set(expectedDeltas.keys) }
    /// Cards whose authored RECORD changed copy only: their effect must equal the legacy record exactly.
    var copyOnly: Set<String> { Set(cards.keys).subtracting(expectedDeltas.keys) }
}

enum ParityAttribution {
    typealias Delta = [String: Double]          // field → change
    typealias Pairs = [String: [String]]        // field → ["num:before", "num:after"]
    static let tolerance = 1e-12

    static func number(_ leaf: String) -> Double? {
        if leaf.hasPrefix("num:") { return Double(leaf.dropFirst(4)) }
        if leaf.hasPrefix("int:") { return Double(leaf.dropFirst(4)) }
        return nil
    }
    /// A numeric leaf as ParitySnapshot writes it: `num:` with Swift's shortest
    /// round-trip text, or `int:` when the field's existing leaf is an integer.
    static func leaf(_ x: Double, like: String) -> String { like.hasPrefix("int:") ? "int:\(Int(x.rounded()))" : "num:\(x)" }

    /// Per-tier field changes of a recorded ladder: a difference, or (for a
    /// multiplicative field, v2.2 N4) the ratio after ÷ before.
    static func deltas(_ tiers: [Pairs], mult: Set<String> = []) -> [Delta] {
        tiers.map { tier in
            var d: Delta = [:]
            for (field, pair) in tier where pair.count == 2 {
                if let b = number(pair[0]), let a = number(pair[1]) { d[field] = mult.contains(field) ? (b != 0 ? a / b : .nan) : a - b }
            }
            return d
        }
    }
    /// The neutral element of a field's shift: 0 (additive) or 1 (multiplicative).
    static func identity(_ field: String, _ mult: Set<String>) -> Double { mult.contains(field) ? 1 : 0 }
    static func parse(_ label: String) -> (id: String, tier: Int)? {
        let parts = label.split(separator: " ")
        guard parts.count == 2, parts[1].hasPrefix("T"), let tier = Int(parts[1].dropFirst()) else { return nil }
        return (String(parts[0]), tier)
    }
    static func add(_ into: inout Delta, _ d: Delta, mult: Set<String> = []) {
        for (f, v) in d { into[f] = mult.contains(f) ? (into[f] ?? 1) * v : (into[f] ?? 0) + v }
    }
    /// Apply a field's shift to a value.
    static func apply(_ field: String, _ value: Double, _ shift: Double, _ mult: Set<String>) -> Double {
        mult.contains(field) ? value * shift : value + shift
    }
    static func same(_ a: Double, _ b: Double) -> Bool { abs(a - b) <= tolerance }

    // MARK: The ground: what each affected card did (legacy record) and does (overlay)

    struct Ground {
        let overlay: ParityOverlay
        let legacyTiers: [String: [Delta]]      // retired + rewritten ids → legacy per-tier deltas (the fixture's own record)
        let currentTiers: [String: [Delta]]     // rewritten ids → overlay per-tier deltas
        let defaults: [String: String]          // the default state's leaves
        /// Every field an attribution can touch: derived, not declared.
        let attributedFields: Set<String>
        /// Why the ground could not be taken (a precondition failed), else nil.
        let problem: String?

        init(legacy: [String: Any], overlay: ParityOverlay) {
            self.overlay = overlay
            let cards = (legacy["cards"] as? [String: [String: [[String: [String]]]]]) ?? [:]
            var defaults = (legacy["defaultState"] as? [String: String]) ?? [:]
            for (field, leaf) in overlay.addedFields { defaults[field] = leaf }   // v2.2 N2: fields the legacy record never had
            self.defaults = defaults
            var lt: [String: [Delta]] = [:], ct: [String: [Delta]] = [:], fields: Set<String> = [], problems: [String] = []
            for id in overlay.retired.union(overlay.rewritten).sorted() {
                guard let perState = cards[id], let fromDefault = perState["default"] else { problems.append("\(id) is not in the legacy record"); continue }
                if overlay.retired.contains(id) && overlay.rewritten.contains(id) { problems.append("\(id) is both retired and rewritten") }
                let d = ParityAttribution.deltas(fromDefault, mult: overlay.multiplicativeFields)
                // Precondition for attributing a step by a fixed delta: the legacy
                // effect was the same from every recorded start state (additive,
                // or a set that nothing else writes; for a multiplicative field
                // the same RATIO — v2.2 N4).
                for (state, tiers) in perState {
                    let other = ParityAttribution.deltas(tiers, mult: overlay.multiplicativeFields)
                    guard other.count == d.count, zip(other, d).allSatisfy({ x, y in x.keys == y.keys && x.allSatisfy { f, v in ParityAttribution.same(v, y[f] ?? .nan) } }) else {
                        problems.append("\(id): the legacy effect differs from state \(state) (not attributable by a fixed delta)"); break
                    }
                }
                lt[id] = d
                for tier in d { fields.formUnion(tier.keys) }
            }
            for (id, tiers) in overlay.expectedDeltas {
                let d = ParityAttribution.deltas(tiers, mult: overlay.multiplicativeFields)
                ct[id] = d
                for tier in d { fields.formUnion(tier.keys) }
                if overlay.cards[id] == nil { problems.append("\(id) has an expectation but no rewritten record") }
            }
            for (field, leaf) in overlay.addedFields where ParityAttribution.number(leaf) == nil { problems.append("added field \(field) has a non-numeric default \(leaf)") }
            self.legacyTiers = lt
            self.currentTiers = ct
            self.attributedFields = fields
            self.problem = problems.isEmpty ? nil : problems.joined(separator: "; ")
        }

        func isRetired(_ label: String) -> Bool { ParityAttribution.parse(label).map { overlay.retired.contains($0.id) } ?? false }
        func isRewritten(_ label: String) -> Bool { ParityAttribution.parse(label).map { overlay.rewritten.contains($0.id) } ?? false }
        func legacyDelta(_ id: String, _ tier: Int) -> Delta { (legacyTiers[id].flatMap { tier - 1 < $0.count ? $0[tier - 1] : nil }) ?? [:] }
        func currentDelta(_ id: String, _ tier: Int) -> Delta { (currentTiers[id].flatMap { tier - 1 < $0.count ? $0[tier - 1] : nil }) ?? [:] }
        /// v2.2 N5 (Chain Reaction): the overlay tier's NON-numeric pairs (e.g. a Bool the
        /// card SETS), exact and state-independent — never an attributed (numeric) field.
        func exactPairs(_ id: String, _ tier: Int) -> Pairs {
            guard let tiers = overlay.expectedDeltas[id], tier >= 1, tier - 1 < tiers.count else { return [:] }
            return tiers[tier - 1].filter { $0.value.count == 2 && ParityAttribution.number($0.value[0]) == nil && ParityAttribution.number($0.value[1]) == nil }
        }

        /// What one legacy step contributes to the attributed fields NOW minus
        /// what it contributed THEN. Nil for a step the overlay does not name.
        func shift(_ label: String) -> Delta? {
            guard let (id, tier) = ParityAttribution.parse(label), overlay.retired.contains(id) || overlay.rewritten.contains(id) else { return nil }
            let leg = legacyDelta(id, tier), cur = overlay.retired.contains(id) ? [:] : currentDelta(id, tier)
            let mult = overlay.multiplicativeFields
            var d: Delta = [:]
            for f in Set(leg.keys).union(cur.keys) {
                d[f] = mult.contains(f) ? (cur[f] ?? 1) / (leg[f] ?? 1) : (cur[f] ?? 0) - (leg[f] ?? 0)
            }
            return d
        }
        func shift(steps: [String], excluding id: String? = nil) -> Delta {
            var total: Delta = [:]
            for label in steps where ParityAttribution.parse(label)?.id != id {
                if let d = shift(label) { ParityAttribution.add(&total, d, mult: overlay.multiplicativeFields) }
            }
            return total
        }
    }

    // MARK: Shifting recorded values

    /// A diff-from-default with its AFTER values shifted (a field whose shifted
    /// value returns to the default leaves the diff; a shifted field that was
    /// not in the diff joins it).
    static func shiftAfter(_ changed: Pairs, by shift: Delta, defaults: [String: String], mult: Set<String> = []) -> Pairs {
        var out = changed
        for (field, delta) in shift where delta != identity(field, mult) {
            let before = changed[field]?[0] ?? defaults[field] ?? "num:0.0"
            guard let b = number(before), let a = number(changed[field]?[1] ?? before) else { continue }
            let after = apply(field, a, delta, mult)
            if same(after, b) { out[field] = nil } else { out[field] = [before, leaf(after, like: before)] }
        }
        return out
    }
    /// A step's diff with BOTH values of the shifted fields moved (the step
    /// itself is unchanged; it ran on a shifted state).
    static func shiftBoth(_ pairs: Pairs, by shift: Delta, mult: Set<String> = []) -> Pairs {
        var out = pairs
        for (field, delta) in shift where delta != identity(field, mult) {
            guard let pair = pairs[field], pair.count == 2, let b = number(pair[0]), let a = number(pair[1]) else { continue }
            out[field] = [leaf(apply(field, b, delta, mult), like: pair[0]), leaf(apply(field, a, delta, mult), like: pair[0])]
        }
        return out
    }

    // MARK: The expected current effect document

    static func expectedEffects(legacy: [String: Any], ground: Ground) -> [String: Any] {
        var out = legacy
        let mult = ground.overlay.multiplicativeFields
        // v2.2 N2: stored fields the legacy record never had — present now, at
        // their defaults, changed only where an overlay delta names them.
        if !ground.overlay.addedFields.isEmpty {
            var paths = Set((legacy["fieldPaths"] as? [String]) ?? [])
            paths.formUnion(ground.overlay.addedFields.keys)
            out["fieldPaths"] = paths.sorted()
            out["defaultState"] = ground.defaults
        }
        let legacyStates = (legacy["startStates"] as? [String: [String: Any]]) ?? [:]
        var states: [String: Any] = [:]
        var stateShift: [String: Delta] = [:]
        var stateSteps: [String: [String]] = [:]
        for (name, state) in legacyStates {
            let steps = (state["steps"] as? [String]) ?? []
            let total = ground.shift(steps: steps)
            stateShift[name] = total
            stateSteps[name] = steps
            let changed = (state["changedFromDefault"] as? Pairs) ?? [:]
            states[name] = ["steps": steps.filter { !ground.isRetired($0) },
                            "changedFromDefault": shiftAfter(changed, by: total, defaults: ground.defaults, mult: mult)]
        }
        out["startStates"] = states

        /// The legacy state's value of a field (after its steps).
        func legacyStateValue(_ name: String, _ field: String) -> Double? {
            let changed = (legacyStates[name]?["changedFromDefault"] as? Pairs) ?? [:]
            return number(changed[field]?[1] ?? ground.defaults[field] ?? "")
        }

        var cards: [String: Any] = [:]
        for (id, perStateAny) in (legacy["cards"] as? [String: Any]) ?? [:] {
            if ground.overlay.retired.contains(id) { continue }
            let perState = (perStateAny as? [String: [[String: [String]]]]) ?? [:]
            var expectedPerState: [String: [[String: [String]]]] = [:]
            for (name, tiers) in perState {
                let steps = stateSteps[name] ?? []
                // A card's record is taken from the state WITHOUT the card's own steps.
                let total = ground.shift(steps: steps, excluding: id)
                if let current = ground.currentTiers[id] {
                    // Rewritten: the overlay's ladder from this state's (shifted) value.
                    var value: [String: Double] = [:]
                    for field in ground.attributedFields {
                        var base: Double
                        if let pair = tiers.first?[field], pair.count == 2, let b = number(pair[0]) { base = b }
                        else {
                            base = legacyStateValue(name, field) ?? 0
                            for label in steps {
                                if let (own, tier) = parse(label), own == id, let d = ground.legacyDelta(own, tier)[field] {
                                    base = mult.contains(field) ? base / d : base - d
                                }
                            }
                        }
                        value[field] = apply(field, base, total[field] ?? identity(field, mult), mult)
                    }
                    var expected: [[String: [String]]] = []
                    for (index, tier) in current.enumerated() {
                        var record: Pairs = [:]
                        for (field, delta) in tier {
                            let b = value[field] ?? 0
                            let like = ground.defaults[field] ?? "num:0.0"
                            let a = apply(field, b, delta, mult)
                            record[field] = [leaf(b, like: like), leaf(a, like: like)]
                            value[field] = a
                        }
                        // v2.2 N5: a NON-numeric pair (a Bool the card SETS) is exact — carried verbatim.
                        for (field, pair) in ground.exactPairs(id, index + 1) { record[field] = pair }
                        expected.append(record)
                    }
                    expectedPerState[name] = expected
                } else {
                    expectedPerState[name] = tiers.map { shiftBoth($0, by: total, mult: mult) }
                }
            }
            cards[id] = expectedPerState
        }
        out["cards"] = cards

        var synergies: [String: Any] = [:]
        for (key, perStateAny) in (legacy["synergies"] as? [String: Any]) ?? [:] {
            var expectedPerState: [String: Pairs] = [:]
            for (name, pairs) in (perStateAny as? [String: Pairs]) ?? [:] {
                expectedPerState[name] = shiftBoth(pairs, by: stateShift[name] ?? [:], mult: mult)
            }
            synergies[key] = expectedPerState
        }
        out["synergies"] = synergies

        var targeted: [Any] = []
        for scenario in (legacy["targeted"] as? [[String: Any]]) ?? [] {
            var total: Delta = [:]
            var value: [String: Double] = [:]
            for field in ground.attributedFields { value[field] = number(ground.defaults[field] ?? "") ?? 0 }
            var steps: [Any] = []
            for record in (scenario["steps"] as? [[String: Any]]) ?? [] {
                let label = (record["step"] as? String) ?? ""
                let changed = (record["changed"] as? Pairs) ?? [:]
                if ground.isRetired(label) {
                    add(&total, ground.shift(label) ?? [:], mult: mult)   // the step is gone; later values lose its contribution
                    continue
                }
                if ground.isRewritten(label), let (id, tier) = parse(label) {
                    var expected: Pairs = [:]
                    for (field, delta) in ground.currentDelta(id, tier) {
                        let b = value[field] ?? 0
                        let like = ground.defaults[field] ?? "num:0.0"
                        let a = apply(field, b, delta, mult)
                        expected[field] = [leaf(b, like: like), leaf(a, like: like)]
                        value[field] = a
                    }
                    for (field, pair) in ground.exactPairs(id, tier) { expected[field] = pair }   // v2.2 N5: exact non-numeric pairs
                    add(&total, ground.shift(label) ?? [:], mult: mult)
                    steps.append(["step": label, "changed": expected])
                    continue
                }
                let shifted = shiftBoth(changed, by: total, mult: mult)
                for field in ground.attributedFields { if let pair = shifted[field], pair.count == 2, let a = number(pair[1]) { value[field] = a } }
                steps.append(["step": label, "changed": shifted])
            }
            targeted.append(["name": scenario["name"] ?? "", "steps": steps])
        }
        out["targeted"] = targeted
        return out
    }

    /// The expected final diff of a recorded run segment replayed now: the
    /// legacy final shifted by every acquired pick the overlay names.
    static func expectedFinal(segment: [String: Any], ground: Ground) -> Pairs {
        var total: Delta = [:]
        for case let row as [String: Any] in segment["levels"] as? [Any] ?? [] {
            for case let pick as [String: Any] in row["picks"] as? [Any] ?? [] {
                guard let id = pick["id"] as? String, let tier = pick["tier"] as? Int, pick["acquired"] as? Bool == true else { continue }
                if let d = ground.shift("\(id) T\(tier)") { add(&total, d, mult: ground.overlay.multiplicativeFields) }
            }
        }
        let recorded = (segment["finalStatsChangedFromDefault"] as? Pairs) ?? [:]
        return shiftAfter(recorded, by: total, defaults: ground.defaults, mult: ground.overlay.multiplicativeFields)
    }

    // MARK: Comparing: exact everywhere, numeric within 1e-12 on the attributed fields

    static func firstDifference(expected: Any?, actual: Any?, tolerant: Set<String>, path: String = "", field: String? = nil) -> String {
        switch (expected, actual) {
        case (let x as [String: Any], let y as [String: Any]):
            for key in Set(x.keys).union(y.keys).sorted() {
                let d = firstDifference(expected: x[key], actual: y[key], tolerant: tolerant, path: path.isEmpty ? key : path + "." + key, field: key)
                if !d.isEmpty { return d }
            }
            return ""
        case (let x as [Any], let y as [Any]):
            if x.count != y.count { return "\(path): \(x.count) items ≠ \(y.count)" }
            for i in x.indices {
                let d = firstDifference(expected: x[i], actual: y[i], tolerant: tolerant, path: "\(path)[\(i)]", field: field)
                if !d.isEmpty { return d }
            }
            return ""
        case (let x as String, let y as String):
            if x == y { return "" }
            if let f = field, tolerant.contains(f), let a = number(x), let b = number(y), same(a, b) { return "" }
            return "\(path): expected \(x) ≠ actual \(y)"
        case (let x as NSObject, let y as NSObject):
            return x == y ? "" : "\(path): expected \(x) ≠ actual \(y)"
        case (nil, nil):
            return ""
        default:
            return "\(path): present on one side only"
        }
    }

    // MARK: The expected catalog dump (unchanged from the J-era overlay rule)

    /// The legacy dump with the overlay applied: retired ids leave the card
    /// list; rewritten cards are replaced in place; the retired table gains the
    /// overlay's notes.
    static func expectedDump(legacy: [String: Any], overlay: ParityOverlay) -> [String: Any] {
        var out = legacy
        let cards = (legacy["cards"] as? [[String: Any]]) ?? []
        out["cards"] = cards.compactMap { card -> [String: Any]? in
            guard let id = card["id"] as? String else { return card }
            if overlay.retired.contains(id) { return nil }
            if let rewritten = overlay.cards[id] as? [String: Any] { return rewritten }
            return card
        }
        var retired = (legacy["retired"] as? [String: String]) ?? [:]
        for (id, note) in overlay.retiredNotes { retired[id] = note }
        out["retired"] = retired
        return out
    }
}
