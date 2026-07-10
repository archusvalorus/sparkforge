// ForgePathManager.swift
// Sparkforge
//
// v1.7 Forge Paths: Forge Levels now earn PICKS instead of flat
// bonuses — one pick per two levels, spent on permanent nodes across
// three branches (Vitality / Ferocity / Cunning). Each node is worth
// roughly two old flat levels, so the power budget matches the system
// it replaces; specialization is the new upside.
//
// Migration is implicit: picks earned are a pure function of forge
// level, so existing players arrive with their whole history banked —
// (level + 1) / 2 picks, rounded generously. Nobody loses progress.
// Respec is a v1.8+ question.

import Foundation

final class ForgePathManager {

    static let shared = ForgePathManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let pathPicks = "sf_forge_path_picks"
    }

    // MARK: - Branches

    enum Branch: String, CaseIterable {
        case vitality = "Vitality"
        case ferocity = "Ferocity"
        case cunning  = "Cunning"

        var icon: String {
            switch self {
            case .vitality: return "💚"
            case .ferocity: return "⚔️"
            case .cunning:  return "🎯"
            }
        }

        var colorHex: UInt32 {
            switch self {
            case .vitality: return 0x66AA66
            case .ferocity: return 0xFF6633
            case .cunning:  return 0x44BBFF
            }
        }
    }

    // MARK: - Nodes

    struct Node {
        let name: String
        let effectText: String
        let apply: (PlayerStats) -> Void
    }

    /// Node cycles — the Nth pick in a branch grants cycle[N % count].
    /// Each node ≈ two levels of the old flat bonuses (power budget).
    private static let cycles: [Branch: [Node]] = [
        .vitality: [
            Node(name: "Tempered Vessel", effectText: "+4 Max HP") { stats in
                stats.maxHP += 4
                stats.currentHP += 4
            },
            Node(name: "Iron Bones", effectText: "+2 DEF") { stats in
                stats.defense += 2
            }
        ],
        .ferocity: [
            Node(name: "Whetted Edge", effectText: "+2 ATK") { stats in
                stats.baseAttack += 2
            },
            Node(name: "Stoked Furnace", effectText: "+4% damage") { stats in
                stats.damageMultiplier += 0.04
            }
        ],
        .cunning: [
            Node(name: "Keen Eye", effectText: "+4% crit chance") { stats in
                stats.critChance += 0.04
            },
            Node(name: "Light Step", effectText: "+4% move speed") { stats in
                stats.moveSpeedMultiplier += 0.04
            }
        ]
    ]

    // MARK: - Picks

    /// Every pick ever made, in order (cycle positions depend on order)
    private(set) var picks: [Branch] = []

    /// One pick per two forge levels, rounded up — migration-generous
    var picksEarned: Int {
        (ProgressionManager.shared.forgeLevel + 1) / 2
    }

    var picksAvailable: Int {
        max(0, picksEarned - picks.count)
    }

    func countInBranch(_ branch: Branch) -> Int {
        picks.filter { $0 == branch }.count
    }

    /// The node the next pick in this branch would grant
    func nextNode(for branch: Branch) -> Node? {
        guard let cycle = Self.cycles[branch], !cycle.isEmpty else { return nil }
        return cycle[countInBranch(branch) % cycle.count]
    }

    /// Spend one available pick on a branch
    func choose(_ branch: Branch) {
        guard picksAvailable > 0 else { return }
        picks.append(branch)
        save()
    }

    // MARK: - Apply

    /// Replay every pick through its branch cycle onto run stats
    func applyPathBonuses(to stats: PlayerStats) {
        var branchCounts: [Branch: Int] = [:]
        for branch in picks {
            guard let cycle = Self.cycles[branch], !cycle.isEmpty else { continue }
            let index = branchCounts[branch, default: 0]
            cycle[index % cycle.count].apply(stats)
            branchCounts[branch] = index + 1
        }
    }

    // MARK: - Summary

    /// Branches with at least one pick, in canonical order, with counts
    var summary: [(branch: Branch, count: Int)] {
        Branch.allCases.compactMap { branch in
            let count = countInBranch(branch)
            return count > 0 ? (branch, count) : nil
        }
    }

    // MARK: - Persistence

    private func save() {
        defaults.set(picks.map(\.rawValue), forKey: Keys.pathPicks)
    }

    private func load() {
        let raw = defaults.stringArray(forKey: Keys.pathPicks) ?? []
        picks = raw.compactMap(Branch.init(rawValue:))
    }

    // MARK: - Reset (testing)

    func resetAll() {
        picks = []
        defaults.removeObject(forKey: Keys.pathPicks)
    }

    private init() {
        load()
    }
}
