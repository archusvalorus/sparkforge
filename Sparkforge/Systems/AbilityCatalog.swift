// AbilityCatalog.swift
// Sparkforge
//
// v2.2 catalog migration (CL-113), Unit J1: the loader for the authored
// ability catalog, `Sparkforge/Catalog/ability-catalog.json`.
//
// The file holds DEFINITIONS: card ids, names, copy, trees, flags, offer gates
// and order, the synergy copy, and the retired ids. Effects and numbers are
// native (`AbilityBehaviors`, `GameConfig`). `load` joins the two and returns
// either a whole catalog or a failure that lists every problem it found.
//
// Since J2 (the runtime cutover) this is the game's only catalog: `installed`
// loads the bundled file once, `GameViewController` consults it before the
// title (a failure shows `CatalogErrorScene`, ruling D1), and `UpgradeManager`
// reads `current`. Where the bytes come from is `AbilityCatalogSource`.
//
// The loader's contract (ruling D1, Oct 4 2026):
//   • ATOMIC. One problem anywhere rejects the whole file. There is no partial
//     catalog, no skipped card, no default filled in for a missing value, and
//     no fallback pool.
//   • ACTIONABLE. Each diagnostic has a stable code, the place in the file
//     (with the card id when there is one) and a sentence saying what to fix.
//     The loader keeps going after a problem where it safely can, so one run
//     reports them together.
//   • STRICT. Unknown keys are rejected: a misspelt optional key must never
//     read as "absent". A newer schema version is rejected, not guessed at.
//   • Card ORDER is preserved exactly. It is behaviour: the seeded shuffle,
//     the capstone guarantee's parity and the gateway-pity tie-break all read
//     the pool in order.

import Foundation

// MARK: - Diagnostics

/// One problem found while loading the catalog.
struct CatalogDiagnostic: Equatable, CustomStringConvertible {

    enum Code: String, CaseIterable {
        // The document itself
        case malformedJSON, wrongType, missingField, unknownField, emptyText
        case unsupportedSchema, unsupportedSchemaVersion
        // Vocabulary
        case treesMismatch, unknownTree, sameSecondaryTree
        case unknownCapability, duplicateCapability, undeclaredCapability
        // Cards
        case noCards, duplicateID, retiredIDIsLive, duplicateRetiredID
        case tierListTooShort, tierOneGate, tierNamesIncomplete
        // The join with native behaviour
        case missingBehavior, tierCountMismatch, unboundBehavior, duplicateBehaviorKey
        case secretScheduleMismatch, nativeIDMissing
        // The source
        case resourceUnavailable
        // Synergies
        case synergyTreeNotColoured, synergyLadderMismatch
        case missingSynergyBehavior, unboundSynergyBehavior
    }

    let code: Code
    /// Where in the file, e.g. `cards[41] "bleed_4" .tiers[3].face`.
    let path: String
    /// What is wrong and what to change.
    let message: String

    var description: String { "[\(code.rawValue)] \(path): \(message)" }
}

/// Why a catalog was rejected. Carries every diagnostic the loader found.
struct CatalogLoadFailure: Error, CustomStringConvertible {
    let diagnostics: [CatalogDiagnostic]

    /// One line, for a player-facing error state and the first log line.
    var summary: String {
        let count = diagnostics.count
        guard let first = diagnostics.first else { return "Ability catalog failed to load." }
        return "Ability catalog failed to load: \(count) problem\(count == 1 ? "" : "s"). First: \(first.code.rawValue) at \(first.path)."
    }

    /// Everything, one diagnostic per line, for logs and development builds.
    var report: String {
        ([summary] + diagnostics.map { "  " + $0.description }).joined(separator: "\n")
    }

    var description: String { report }
}

// MARK: - Catalog

struct AbilityCatalog {

    static let schemaName = "sparkforge.ability-catalog"
    static let supportedSchemaVersion = 1

    /// The file's portable tree keys and the Swift tag each one means, in
    /// `Tag.allCases` order. The file's `trees` list must match this exactly;
    /// each tree's `name` must equal the tag's raw value, which live saves
    /// persist (`sf_bannedFamily`, `sf_synergies_seen`) and so never changes.
    static let treeKeys: [(key: String, tag: UpgradeManager.Tag)] = [
        ("fire", .fire), ("shock", .shock), ("bleed", .bleed), ("guard", .guardT),
        ("void", .voidT), ("chill", .chill), ("growth", .growth), ("neutral", .neutral),
    ]

    /// The card counts at which a tree's synergy tiers fire. The trigger rule
    /// itself is native (`UpgradeManager.checkSynergies`); the file must state
    /// exactly these for every coloured tree.
    static let synergyThresholds = [3, 5, 7]

    /// Every card, in file order, with its native effects bound.
    let cards: [UpgradeManager.UpgradeCard]
    /// Synergy copy per tree, thresholds ascending.
    let synergyTiers: [UpgradeManager.Tag: [UpgradeManager.SynergyTier]]
    /// Synergy stat effects, keyed like the Codex's persistence id:
    /// "<Tag.rawValue>_<threshold>", e.g. "Fire_3".
    let synergyEffects: [String: (PlayerStats) -> Void]
    /// Retired card id → the note on what retired it.
    let retiredCardIDs: [String: String]

    static func synergyKey(_ tag: UpgradeManager.Tag, _ threshold: Int) -> String {
        "\(tag.rawValue)_\(threshold)"
    }

    // MARK: Load

    /// The app's catalog, loaded once from `AbilityCatalogSource`. Consulted
    /// at startup (GameViewController) before anything can draw a card.
    static let installed: Result<AbilityCatalog, CatalogLoadFailure> = load(source: AbilityCatalogSource.data)

    /// The installed catalog. Only reachable after `installed` succeeded: the
    /// startup check blocks the game otherwise, so this stop is a backstop for
    /// a code path that skipped it, never a fallback (ruling D1).
    static var current: AbilityCatalog {
        switch installed {
        case .success(let catalog): return catalog
        case .failure(let failure): preconditionFailure(failure.summary)
        }
    }

    /// Load from a source of bytes; a source that throws is one diagnostic.
    static func load(source: () throws -> Data,
                     behaviors: AbilityBehaviors.Registry = AbilityBehaviors.registry) -> Result<AbilityCatalog, CatalogLoadFailure> {
        let data: Data
        do {
            data = try source()
        } catch {
            return .failure(CatalogLoadFailure(diagnostics: [CatalogDiagnostic(
                code: .resourceUnavailable, path: "bundle",
                message: "The ability catalog could not be read: \(error). The file ships inside the app; reinstall or update the app.")]))
        }
        return load(data, behaviors: behaviors)
    }

    /// Parse, validate and bind. Returns a whole catalog or a failure listing
    /// every problem found; never anything in between.
    static func load(_ data: Data,
                     behaviors: AbilityBehaviors.Registry = AbilityBehaviors.registry) -> Result<AbilityCatalog, CatalogLoadFailure> {
        var loader = Loader(behaviors: behaviors)
        let catalog = loader.run(data)
        if let catalog, loader.diagnostics.isEmpty { return .success(catalog) }
        if loader.diagnostics.isEmpty {
            // Unreachable by construction; refuse rather than hand back nothing silently.
            loader.report(.malformedJSON, "$", "The catalog could not be built and no cause was recorded.")
        }
        return .failure(CatalogLoadFailure(diagnostics: loader.diagnostics))
    }
}

// MARK: - Loader

private struct Loader {

    typealias Tag = UpgradeManager.Tag
    typealias Capability = UpgradeManager.Capability
    typealias Code = CatalogDiagnostic.Code

    let behaviors: AbilityBehaviors.Registry
    var diagnostics: [CatalogDiagnostic] = []

    /// What every card entry STATES, recorded even when the entry has another
    /// problem and yields no card. The cross-card checks read these, so one
    /// broken card is reported once, not again as a "missing" id or an
    /// "unbound" behaviour.
    private var statedCards: [(index: Int, id: String, path: String, isSecret: Bool)] = []
    private var statedBehaviorKeys: Set<String> = []

    init(behaviors: AbilityBehaviors.Registry) { self.behaviors = behaviors }

    mutating func report(_ code: Code, _ path: String, _ message: String) {
        diagnostics.append(CatalogDiagnostic(code: code, path: path, message: message))
    }

    // MARK: Strict readers

    private static func isBoolean(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private mutating func object(_ value: Any?, _ path: String) -> [String: Any]? {
        guard let dict = value as? [String: Any] else {
            report(.wrongType, path, "Expected an object here.")
            return nil
        }
        return dict
    }

    private mutating func array(_ owner: [String: Any], _ key: String, _ path: String, required: Bool = true) -> [Any]? {
        guard let value = owner[key] else {
            if required { report(.missingField, path, "Add the required list `\(key)`.") }
            return nil
        }
        guard let list = value as? [Any] else {
            report(.wrongType, "\(path).\(key)", "`\(key)` must be a list.")
            return nil
        }
        return list
    }

    /// A non-empty string. A present-but-empty string is an error, never "absent".
    private mutating func text(_ owner: [String: Any], _ key: String, _ path: String, required: Bool = true) -> String? {
        guard let value = owner[key] else {
            if required { report(.missingField, path, "Add the required text `\(key)`.") }
            return nil
        }
        guard !Self.isBoolean(value), let string = value as? String else {
            report(.wrongType, "\(path).\(key)", "`\(key)` must be text.")
            return nil
        }
        guard !string.isEmpty else {
            report(.emptyText, "\(path).\(key)", "`\(key)` is empty. Write the text, or remove the key if it is optional.")
            return nil
        }
        return string
    }

    /// An optional flag: absent means false; anything but true/false is an error.
    private mutating func flag(_ owner: [String: Any], _ key: String, _ path: String) -> Bool {
        guard let value = owner[key] else { return false }
        guard Self.isBoolean(value), let bool = value as? Bool else {
            report(.wrongType, "\(path).\(key)", "`\(key)` must be true or false.")
            return false
        }
        return bool
    }

    private mutating func integer(_ owner: [String: Any], _ key: String, _ path: String) -> Int? {
        guard let value = owner[key] else {
            report(.missingField, path, "Add the required number `\(key)`.")
            return nil
        }
        guard !Self.isBoolean(value), let number = value as? NSNumber,
              number.doubleValue == number.doubleValue.rounded(), let int = Int(exactly: number.doubleValue) else {
            report(.wrongType, "\(path).\(key)", "`\(key)` must be a whole number.")
            return nil
        }
        return int
    }

    private mutating func rejectUnknownKeys(_ owner: [String: Any], allowed: Set<String>, _ path: String) {
        for key in owner.keys.sorted() where !allowed.contains(key) {
            report(.unknownField, "\(path).\(key)", "`\(key)` is not a key this schema version knows. Check the spelling; allowed here: \(allowed.sorted().joined(separator: ", ")).")
        }
    }

    /// An optional list of capability keys, each declared and known to Swift.
    private mutating func capabilities(_ owner: [String: Any], _ key: String, _ path: String, declared: Set<String>) -> Set<Capability> {
        guard owner[key] != nil, let list = array(owner, key, path) else { return [] }
        var out: Set<Capability> = []
        for (i, item) in list.enumerated() {
            let itemPath = "\(path).\(key)[\(i)]"
            guard !Self.isBoolean(item), let name = item as? String else {
                report(.wrongType, itemPath, "A capability must be text.")
                continue
            }
            guard let capability = Capability(rawValue: name) else {
                report(.unknownCapability, itemPath, "`\(name)` is not a capability native code knows. Check the spelling, or add the case to `UpgradeManager.Capability` first.")
                continue
            }
            if !declared.contains(name) {
                report(.undeclaredCapability, itemPath, "`\(name)` is used here but missing from the file's top-level `capabilities` list. Add it there.")
            }
            if !out.insert(capability).inserted {
                report(.duplicateCapability, itemPath, "`\(name)` is listed twice in `\(key)`. Remove the repeat.")
            }
        }
        return out
    }

    // MARK: Run

    private struct CardDraft {
        let id: String
        let behaviorKey: String
        let card: (CardBehavior) -> UpgradeManager.UpgradeCard
        let tierCount: Int
        let path: String
    }

    mutating func run(_ data: Data) -> AbilityCatalog? {
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data)
        } catch {
            report(.malformedJSON, "$", "The file is not valid JSON: \(error.localizedDescription)")
            return nil
        }
        guard let root = object(parsed, "$") else { return nil }

        // Schema first: a file in another schema can't be judged by these rules.
        guard let schema = text(root, "schema", "$") else { return nil }
        guard schema == AbilityCatalog.schemaName else {
            report(.unsupportedSchema, "$.schema", "This is `\(schema)`; the loader reads `\(AbilityCatalog.schemaName)` only.")
            return nil
        }
        guard let version = integer(root, "schemaVersion", "$") else { return nil }
        guard version == AbilityCatalog.supportedSchemaVersion else {
            report(.unsupportedSchemaVersion, "$.schemaVersion", "The file is schema version \(version); this build reads version \(AbilityCatalog.supportedSchemaVersion) only. Ship the matching app build or convert the file.")
            return nil
        }
        rejectUnknownKeys(root, allowed: ["schema", "schemaVersion", "trees", "capabilities", "cards", "synergies", "retired"], "$")

        let treeByKey = readTrees(root)
        let declared = readDeclaredCapabilities(root)
        let retired = readRetired(root)
        let drafts = readCards(root, treeByKey: treeByKey, declared: declared)
        let synergies = readSynergies(root, treeByKey: treeByKey)

        checkIdentity(retired: retired)
        let cards = bind(drafts)

        guard diagnostics.isEmpty else { return nil }
        return AbilityCatalog(cards: cards, synergyTiers: synergies.tiers, synergyEffects: synergies.effects, retiredCardIDs: retired)
    }

    // MARK: Trees and capabilities

    private mutating func readTrees(_ root: [String: Any]) -> [String: Tag] {
        let expected = AbilityCatalog.treeKeys
        let byKey = Dictionary(uniqueKeysWithValues: expected.map { ($0.key, $0.tag) })
        guard let list = array(root, "trees", "$") else { return byKey }
        if list.count != expected.count {
            report(.treesMismatch, "$.trees", "The file lists \(list.count) trees; native code has \(expected.count) (\(expected.map { $0.key }.joined(separator: ", ")), in that order).")
        }
        for (i, item) in list.enumerated() {
            let path = "$.trees[\(i)]"
            guard let tree = object(item, path) else { continue }
            rejectUnknownKeys(tree, allowed: ["key", "name"], path)
            guard let key = text(tree, "key", path), let name = text(tree, "name", path), i < expected.count else { continue }
            if key != expected[i].key || name != expected[i].tag.rawValue {
                report(.treesMismatch, path, "Expected `\(expected[i].key)` / \"\(expected[i].tag.rawValue)\" at this position, found `\(key)` / \"\(name)\". Tree keys, names and order are fixed by native code and by live saves.")
            }
        }
        return byKey
    }

    private mutating func readDeclaredCapabilities(_ root: [String: Any]) -> Set<String> {
        guard let list = array(root, "capabilities", "$") else { return [] }
        var out: Set<String> = []
        for (i, item) in list.enumerated() {
            let path = "$.capabilities[\(i)]"
            guard !Self.isBoolean(item), let name = item as? String else {
                report(.wrongType, path, "A capability must be text.")
                continue
            }
            if Capability(rawValue: name) == nil {
                report(.unknownCapability, path, "`\(name)` is not a capability native code knows. Check the spelling, or add the case to `UpgradeManager.Capability` first.")
            }
            if !out.insert(name).inserted {
                report(.duplicateCapability, path, "`\(name)` is declared twice. Remove the repeat.")
            }
        }
        return out
    }

    // MARK: Retired ids

    private mutating func readRetired(_ root: [String: Any]) -> [String: String] {
        guard let list = array(root, "retired", "$") else { return [:] }
        var out: [String: String] = [:]
        for (i, item) in list.enumerated() {
            let path = "$.retired[\(i)]"
            guard let entry = object(item, path) else { continue }
            rejectUnknownKeys(entry, allowed: ["id", "note"], path)
            guard let id = text(entry, "id", path), let note = text(entry, "note", path) else { continue }
            if out[id] != nil {
                report(.duplicateRetiredID, "\(path) \"\(id)\"", "`\(id)` is retired twice. Keep one entry.")
            }
            out[id] = note
        }
        return out
    }

    // MARK: Cards

    private mutating func readCards(_ root: [String: Any], treeByKey: [String: Tag], declared: Set<String>) -> [CardDraft] {
        guard let list = array(root, "cards", "$") else { return [] }
        if list.isEmpty {
            report(.noCards, "$.cards", "The card list is empty. A catalog with no cards is never valid.")
        }
        var drafts: [CardDraft] = []
        for (index, item) in list.enumerated() {
            if let draft = readCard(item, index: index, treeByKey: treeByKey, declared: declared) { drafts.append(draft) }
        }
        return drafts
    }

    private mutating func tree(_ owner: [String: Any], _ key: String, _ path: String, treeByKey: [String: Tag], required: Bool) -> Tag? {
        guard let name = text(owner, key, path, required: required) else { return nil }
        guard let tag = treeByKey[name] else {
            report(.unknownTree, "\(path).\(key)", "`\(name)` is not a tree. Use one of: \(AbilityCatalog.treeKeys.map { $0.key }.joined(separator: ", ")).")
            return nil
        }
        return tag
    }

    private mutating func readCard(_ item: Any, index: Int, treeByKey: [String: Tag], declared: Set<String>) -> CardDraft? {
        var path = "$.cards[\(index)]"
        guard let entry = object(item, path) else { return nil }
        let id = text(entry, "id", path)
        if let id { path += " \"\(id)\"" }
        let before = diagnostics.count

        rejectUnknownKeys(entry, allowed: ["id", "name", "tree", "secondaryTree", "signature", "capstone", "secret",
                                           "face", "detail", "provides", "requires", "blockedBy", "tiers", "behavior"], path)
        let name = text(entry, "name", path)
        let primary = tree(entry, "tree", path, treeByKey: treeByKey, required: true)
        let secondary = entry["secondaryTree"] == nil ? nil : tree(entry, "secondaryTree", path, treeByKey: treeByKey, required: true)
        if let primary, let secondary, primary == secondary {
            report(.sameSecondaryTree, "\(path).secondaryTree", "The secondary tree repeats the primary. Remove `secondaryTree`, or name a different tree.")
        }
        let face = text(entry, "face", path)
        let detail = text(entry, "detail", path, required: false)
        let isSignature = flag(entry, "signature", path)
        let isCapstone = flag(entry, "capstone", path)
        let isSecret = flag(entry, "secret", path)
        let provides = capabilities(entry, "provides", path, declared: declared)
        let requires = capabilities(entry, "requires", path, declared: declared)
        let blockedBy = capabilities(entry, "blockedBy", path, declared: declared)
        let behaviorKey = text(entry, "behavior", path)
        if let id { statedCards.append((index, id, path, isSecret)) }
        if let behaviorKey { statedBehaviorKeys.insert(behaviorKey) }

        // Tiers: absent = a one-tier card. Present = the whole ladder, tier 1 first.
        var tierFaces: [String]? = nil
        var tierNames: [String]? = nil
        var tierRequires: [Int: Set<Capability>] = [:]
        var tierProvides: [Int: Set<Capability>] = [:]
        var tierBlockedBy: [Int: Set<Capability>] = [:]
        if entry["tiers"] != nil, let list = array(entry, "tiers", path) {
            if list.count < 2 {
                report(.tierListTooShort, "\(path).tiers", "A `tiers` list needs at least 2 entries. For a one-tier card, remove `tiers`: `face` is its only line.")
            }
            var faces: [String] = []
            var names: [String] = []
            for (i, tierItem) in list.enumerated() {
                let tierPath = "\(path).tiers[\(i)]"
                guard let tier = object(tierItem, tierPath) else { continue }
                rejectUnknownKeys(tier, allowed: ["name", "face", "provides", "requires", "blockedBy"], tierPath)
                if let line = text(tier, "face", tierPath) { faces.append(line) }
                if let tierName = text(tier, "name", tierPath, required: false) { names.append(tierName) }
                let needs = capabilities(tier, "requires", tierPath, declared: declared)
                let grants = capabilities(tier, "provides", tierPath, declared: declared)
                let blocks = capabilities(tier, "blockedBy", tierPath, declared: declared)
                if i == 0, !(needs.isEmpty && grants.isEmpty && blocks.isEmpty) {
                    report(.tierOneGate, tierPath, "Tier 1 takes its gates from the card: move `provides` / `requires` / `blockedBy` up to the card level.")
                }
                if !needs.isEmpty { tierRequires[i + 1] = needs }
                if !grants.isEmpty { tierProvides[i + 1] = grants }
                if !blocks.isEmpty { tierBlockedBy[i + 1] = blocks }
            }
            if !names.isEmpty && names.count != list.count {
                report(.tierNamesIncomplete, "\(path).tiers", "\(names.count) of \(list.count) tiers have a `name`. Give every tier a name, or none.")
            }
            if faces.count == list.count { tierFaces = faces }
            if names.count == list.count { tierNames = names }
        }
        let tierCount = (entry["tiers"] as? [Any])?.count ?? 1

        // Any problem above makes this card unusable; the load fails as a whole.
        guard diagnostics.count == before,
              let id, let name, let primary, let face, let behaviorKey else { return nil }

        return CardDraft(id: id, behaviorKey: behaviorKey, card: { behavior in
            UpgradeManager.UpgradeCard(
                id: id, name: name, tag: primary, secondaryTag: secondary,
                description: face,
                apply: behavior.tiers.first ?? { _ in },
                higherTiers: Array(behavior.tiers.dropFirst()),
                tierDescriptions: tierFaces, detail: detail,
                isCapstone: isCapstone, isSignature: isSignature,
                provides: provides, requires: requires,
                tierRequires: tierRequires, tierProvides: tierProvides,
                blockedBy: blockedBy, tierBlockedBy: tierBlockedBy,
                isSecret: isSecret, tierNames: tierNames)
        }, tierCount: tierCount, path: path)
    }

    // MARK: Identity

    private mutating func checkIdentity(retired: [String: String]) {
        var seen: [String: Int] = [:]
        for card in statedCards {
            if let first = seen[card.id] {
                report(.duplicateID, card.path, "`\(card.id)` is already used by cards[\(first)]. Card ids are permanent and unique (saves store them).")
            } else {
                seen[card.id] = card.index
            }
            if let note = retired[card.id] {
                report(.retiredIDIsLive, card.path, "`\(card.id)` is a retired id (\(note)). A retired id is never reused: old saves would count the new card as discovered. Pick a new id.")
            }
        }
        // Native code names these ids outside the catalog; each needs a definition.
        for id in behaviors.nativeCardIDs where seen[id] == nil {
            report(.nativeIDMissing, "$.cards", "Native code refers to card `\(id)` and the file has no such card. Restore the card, or remove the native reference first.")
        }
        // The secret scheduler offers exactly one id; its definition must be secret.
        let scheduled = behaviors.scheduledSecretCardID
        if let card = statedCards.first(where: { $0.id == scheduled }) {
            if !card.isSecret {
                report(.secretScheduleMismatch, card.path, "`\(scheduled)` is the card the secret scheduler offers; mark it `\"secret\": true`, or it would also enter ordinary draws.")
            }
        } else {
            report(.secretScheduleMismatch, "$.cards", "The secret scheduler offers `\(scheduled)` and the file has no such card.")
        }
    }

    // MARK: Binding

    private mutating func bind(_ drafts: [CardDraft]) -> [UpgradeManager.UpgradeCard] {
        for key in behaviors.duplicateKeys.sorted() {
            report(.duplicateBehaviorKey, "native registry", "Behaviour key `\(key)` is registered twice in `AbilityBehaviors`. Keep one.")
        }
        var cards: [UpgradeManager.UpgradeCard] = []
        for draft in drafts {
            let key = draft.behaviorKey
            guard let behavior = behaviors.cards[key] else {
                report(.missingBehavior, "\(draft.path).behavior", "No native behaviour is registered as `\(key)`. Check the spelling, or add the effect to `AbilityBehaviors` first.")
                continue
            }
            guard behavior.tiers.count == draft.tierCount else {
                report(.tierCountMismatch, draft.path, "The file gives this card \(draft.tierCount) tier\(draft.tierCount == 1 ? "" : "s"); native behaviour `\(key)` has \(behavior.tiers.count). They must match: add or remove tier lines here, or tiers there.")
                continue
            }
            cards.append(draft.card(behavior))
        }
        for key in behaviors.cards.keys.sorted() where !statedBehaviorKeys.contains(key) {
            report(.unboundBehavior, "native registry", "Native behaviour `\(key)` is bound by no card. Bind it from a card's `behavior`, or delete the effect.")
        }
        return cards
    }

    // MARK: Synergies

    private mutating func readSynergies(_ root: [String: Any], treeByKey: [String: Tag])
        -> (tiers: [Tag: [UpgradeManager.SynergyTier]], effects: [String: (PlayerStats) -> Void]) {
        var tiers: [Tag: [UpgradeManager.SynergyTier]] = [:]
        var effects: [String: (PlayerStats) -> Void] = [:]
        // What the entries STATE, kept even for an entry with another problem,
        // so that problem isn't reported again as a gap in the ladder or an
        // unbound effect.
        var statedKeys: Set<String> = []
        var statedThresholds: [Tag: [Int]] = [:]
        guard let list = array(root, "synergies", "$") else { return (tiers, effects) }

        for (i, item) in list.enumerated() {
            var path = "$.synergies[\(i)]"
            guard let entry = object(item, path) else { continue }
            rejectUnknownKeys(entry, allowed: ["tree", "threshold", "title", "effect", "behavior"], path)
            let tag = tree(entry, "tree", path, treeByKey: treeByKey, required: true)
            let threshold = integer(entry, "threshold", path)
            if let tag, let threshold { path += " \"\(tag.rawValue) ×\(threshold)\"" }
            let title = text(entry, "title", path)
            let effect = text(entry, "effect", path)
            let key = text(entry, "behavior", path)
            if let key { statedKeys.insert(key) }
            if let tag, tag == .neutral {
                report(.synergyTreeNotColoured, path, "Neutral is not a colour and has no synergy ladder. Remove this entry.")
                continue
            }
            if let tag, let threshold { statedThresholds[tag, default: []].append(threshold) }
            guard let tag, let threshold, let title, let effect, let key else { continue }
            guard let native = behaviors.synergies[key] else {
                report(.missingSynergyBehavior, "\(path).behavior", "No native synergy effect is registered as `\(key)`. Check the spelling, or add the effect to `AbilityBehaviors` first.")
                continue
            }
            tiers[tag, default: []].append(UpgradeManager.SynergyTier(threshold: threshold, title: title, effect: effect))
            effects[AbilityCatalog.synergyKey(tag, threshold)] = native
        }

        // Every coloured tree states exactly the native thresholds, ascending.
        for (key, tag) in AbilityCatalog.treeKeys where tag != .neutral {
            let found = statedThresholds[tag] ?? []
            if found != AbilityCatalog.synergyThresholds {
                report(.synergyLadderMismatch, "$.synergies (\(key))", "Tree `\(key)` lists thresholds \(found); it must list exactly \(AbilityCatalog.synergyThresholds), in that order (the native trigger rule fires at those counts).")
            }
        }
        for key in behaviors.synergies.keys.sorted() where !statedKeys.contains(key) {
            report(.unboundSynergyBehavior, "native registry", "Native synergy effect `\(key)` is bound by no synergy entry. Bind it, or delete the effect.")
        }
        return (tiers, effects)
    }
}
