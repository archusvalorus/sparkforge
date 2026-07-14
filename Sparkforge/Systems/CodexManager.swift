// CodexManager.swift
// Sparkforge
//
// v1.8 Unit 5 — lifetime "Codex" discovery across all runs: which synergy
// tiers have fired, which cards have been offered, and which enemy families
// have been encountered/defeated. Read by the Codex pages (Units 6–9).
//
// Shape mirrors ProgressionManager: a shared singleton, an `sf_` Keys block,
// computed UserDefaults access. ADD-ONLY by construction — every key reads
// empty on a save that predates it (`stringArray` → [], missing data → [:]),
// so no existing save can break and no migration is needed. Keys are
// live-player data: never rename them.

import Foundation

final class CodexManager {

    static let shared = CodexManager()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let synergiesSeen       = "sf_synergies_seen"        // [String] e.g. "Fire_3"
        static let cardsOffered        = "sf_cards_offered"         // [String] card ids
        static let bestiaryEncountered = "sf_bestiary_encountered"  // [String] family ids
        static let bestiaryKills       = "sf_bestiary_kills"        // JSON [familyID: Int]
    }

    // Per-kill bestiary data is cached in memory so a heavy swarm never decodes
    // from UserDefaults per kill (60fps canon); writes go through immediately.
    private lazy var encounteredCache: Set<String> =
        Set(defaults.stringArray(forKey: Keys.bestiaryEncountered) ?? [])
    private lazy var killsCache: [String: Int] =
        Self.decodeKills(defaults.data(forKey: Keys.bestiaryKills))

    private init() {}

    // MARK: - Synergies (discovered = the tier fired in a run)

    /// Stable persistence id for a synergy tier, e.g. "Fire_3". Tag rawValues
    /// ("Fire", "Guard", "Void", …) are stable, so this id is too.
    func synergyID(tag: UpgradeManager.Tag, tier: Int) -> String {
        return "\(tag.rawValue)_\(tier)"
    }

    func recordSynergySeen(tag: UpgradeManager.Tag, tier: Int) {
        insert(synergyID(tag: tag, tier: tier), forKey: Keys.synergiesSeen)
    }

    func hasSeenSynergy(tag: UpgradeManager.Tag, tier: Int) -> Bool {
        return contains(synergyID(tag: tag, tier: tier), forKey: Keys.synergiesSeen)
    }

    // MARK: - Cards (discovered = ever OFFERED in a selection, picked or not)

    func recordCardOffered(_ id: String) {
        insert(id, forKey: Keys.cardsOffered)
    }

    func hasOfferedCard(_ id: String) -> Bool {
        return contains(id, forKey: Keys.cardsOffered)
    }

    // MARK: - Bestiary

    /// Marks the family encountered AND increments its lifetime kill count.
    /// v1.8 records encounters at defeat time; `recordEncounter` exists for a
    /// future on-sight reveal (see the Unit 9 note) without a schema change.
    func recordDefeat(_ family: BestiaryFamily) {
        markEncountered(family)
        killsCache[family.rawValue, default: 0] += 1
        persistKills()
    }

    /// Marks a family encountered without recording a kill.
    func recordEncounter(_ family: BestiaryFamily) {
        markEncountered(family)
    }

    func hasEncountered(_ family: BestiaryFamily) -> Bool {
        return encounteredCache.contains(family.rawValue)
    }

    func kills(of family: BestiaryFamily) -> Int {
        return killsCache[family.rawValue] ?? 0
    }

    private func markEncountered(_ family: BestiaryFamily) {
        guard encounteredCache.insert(family.rawValue).inserted else { return }
        defaults.set(Array(encounteredCache), forKey: Keys.bestiaryEncountered)
    }

    private func persistKills() {
        if let data = try? JSONEncoder().encode(killsCache) {
            defaults.set(data, forKey: Keys.bestiaryKills)
        }
    }

    private static func decodeKills(_ data: Data?) -> [String: Int] {
        guard let data = data,
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
        return dict
    }

    // MARK: - Set-as-array helpers (for the rarely-written stores)

    private func insert(_ value: String, forKey key: String) {
        var set = Set(defaults.stringArray(forKey: key) ?? [])
        guard set.insert(value).inserted else { return }
        defaults.set(Array(set), forKey: key)
    }

    private func contains(_ value: String, forKey key: String) -> Bool {
        return (defaults.stringArray(forKey: key) ?? []).contains(value)
    }

    // MARK: - Debug / reset

    #if DEBUG
    /// Snapshot of lifetime discovery — printed at run start so persistence can
    /// be validated across app restarts before any Codex page exists (Units 6–9).
    func debugSummary() -> String {
        let syn = (defaults.stringArray(forKey: Keys.synergiesSeen) ?? []).sorted()
        let cards = (defaults.stringArray(forKey: Keys.cardsOffered) ?? []).count
        let enc = encounteredCache.sorted()
        return """
        [Codex] synergies seen (\(syn.count)): \(syn)
        [Codex] cards offered: \(cards)
        [Codex] bestiary encountered (\(enc.count)): \(enc)
        [Codex] bestiary kills: \(killsCache)
        """
    }
    #endif

    /// Testing helper — wipes all Codex discovery (parity with
    /// ProgressionManager.resetAll).
    func resetAll() {
        defaults.removeObject(forKey: Keys.synergiesSeen)
        defaults.removeObject(forKey: Keys.cardsOffered)
        defaults.removeObject(forKey: Keys.bestiaryEncountered)
        defaults.removeObject(forKey: Keys.bestiaryKills)
        encounteredCache = []
        killsCache = [:]
    }
}

// MARK: - Bestiary family registry

/// One entry per enemy archetype, in display order. rawValue is the STABLE
/// persistence id — never rename (live-player data). GameScene maps live enemy
/// nodes onto these; the bestiary page (Unit 9) renders them.
enum BestiaryFamily: String, CaseIterable {
    case melee        = "melee"
    case ranged       = "ranged"
    case ashling      = "ashling"
    case braceguard   = "braceguard"
    case relayImp     = "relay_imp"
    case grounder     = "grounder"
    case staticHalo   = "static_halo"
    case circuitWasp  = "circuit_wasp"
    case miniBoss     = "mini_boss"
    case slagTitan    = "slag_titan"
    case quenchWarden = "quench_warden"
    case dynamoChoir  = "dynamo_choir"
    /// Reserved v2.0 slot — the hidden nemesis. Present in the schema NOW so it
    /// doesn't churn at v2.0; the bestiary page MUST skip entries where
    /// `hiddenUntilFutureVersion` is true until Mote ships. See
    /// docs/mote-v2.0-handoff.md (card = VERY purple + neon-white at reveal).
    case mote         = "mote"

    /// Provisional display names — Unit 9 finalizes copy with the Lyra brief.
    /// Bosses already carry their canonical names.
    var displayName: String {
        switch self {
        case .melee:        return "Melee"
        case .ranged:       return "Ranged"
        case .ashling:      return "Ashling"
        case .braceguard:   return "Braceguard"
        case .relayImp:     return "Relay Imp"
        case .grounder:     return "Grounder"
        case .staticHalo:   return "Static Halo"
        case .circuitWasp:  return "Circuit Wasp"
        case .miniBoss:     return "Mini-Boss"
        case .slagTitan:    return "The Slag Titan"
        case .quenchWarden: return "The Quench Warden"
        case .dynamoChoir:  return "The Dynamo Choir"
        case .mote:         return "????"
        }
    }

    var isBoss: Bool {
        switch self {
        case .slagTitan, .quenchWarden, .dynamoChoir: return true
        default: return false
        }
    }

    /// The bestiary page must not render this entry until its version ships
    /// (Mote = v2.0). Keeps the schema stable across the version boundary.
    var hiddenUntilFutureVersion: Bool { self == .mote }
}
