// ForgePathManager.swift
// Sparkforge
//
// v1.9 Forge Path rework (Unit 1 — data model): the infinite 2-node cycle is
// replaced with AUTHORED vertical ladders per branch (nodes 1–20), with a 1-of-2
// FORK at every 5th level (5/10/15/20). Content spec:
// docs/forge-path-ladders-v1.9.md. Kickoff: docs/forge-path-rework-kickoff.md.
//
// Persistence is backward-compatible: `sf_forge_path_picks` (the ordered branch
// list, live data) is UNCHANGED — existing players' picks replay onto the new
// ladders. Fork choices persist separately in `sf_forge_path_forks`.
//
// Unit 1 wires the STAT nodes (HP/DEF/ATK/dmg/crit/move/pickup). Behavioral
// nodes (regen, damage reduction, kill-stacks, etc.) are defined here with their
// display text but a no-op apply — their effects land in Unit 2. Fork options
// that are pure stats are wired now; behavioral fork options are stubbed too.

import Foundation

final class ForgePathManager {

    static let shared = ForgePathManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let pathPicks = "sf_forge_path_picks"   // live data — never rename
        static let pathForks = "sf_forge_path_forks"   // v1.9: fork choices
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

    /// One side of a milestone fork.
    struct ForkOption {
        let name: String
        let effectText: String
        let apply: (PlayerStats) -> Void
    }

    /// A single authored ladder node. Normal nodes carry one `apply`; fork nodes
    /// (every 5th level) carry two options resolved by the player's stored choice.
    struct Node {
        let level: Int
        let name: String
        let effectText: String
        let apply: (PlayerStats) -> Void
        let fork: (a: ForkOption, b: ForkOption)?

        /// Normal node.
        init(_ level: Int, _ name: String, _ effectText: String,
             apply: @escaping (PlayerStats) -> Void) {
            self.level = level
            self.name = name
            self.effectText = effectText
            self.apply = apply
            self.fork = nil
        }

        /// A behavioral node whose in-run effect lands in Unit 2 (no-op apply for now).
        static func behavioral(_ level: Int, _ name: String, _ effectText: String) -> Node {
            Node(level, name, effectText, apply: { _ in /* Unit 2 */ })
        }

        /// Milestone fork node.
        init(fork level: Int, _ title: String, a: ForkOption, b: ForkOption) {
            self.level = level
            self.name = title
            self.effectText = "A: \(a.name) · B: \(b.name)"
            self.apply = { _ in }   // resolved via the stored fork choice, not this
            self.fork = (a, b)
        }
    }

    /// Behavioral fork option (effect lands in Unit 2).
    private static func fx(_ name: String, _ text: String) -> ForkOption {
        ForkOption(name: name, effectText: text, apply: { _ in /* Unit 2 */ })
    }

    // MARK: - Authored ladders (1–20). Content: docs/forge-path-ladders-v1.9.md.

    private static let ladders: [Branch: [Node]] = [
        .vitality: [
            Node(1, "Tempered Vessel", "+5 Max HP") { $0.maxHP += 5; $0.currentHP += 5 },
            Node(2, "Iron Bones", "+2 DEF") { $0.defense += 2 },
            Node(3, "Deep Reserve", "+5 Max HP") { $0.maxHP += 5; $0.currentHP += 5 },
            Node(4, "Reinforced Frame", "+2 DEF") { $0.defense += 2 },
            Node(fork: 5, "Recovery or Prevention",
                 a: ForkOption(name: "Regenerator", effectText: "Recover 1 HP every 8s") { $0.forgeRegenerator = true },
                 b: ForkOption(name: "Braced Impact", effectText: "First hit every 12s deals 25% less") { $0.forgeBracedImpact = true }),
            Node(6, "Tempered Blood", "+5 Max HP") { $0.maxHP += 5; $0.currentHP += 5 },
            Node(7, "Layered Plating", "+2 DEF") { $0.defense += 2 },
            Node(8, "Durable Core", "+5 Max HP") { $0.maxHP += 5; $0.currentHP += 5 },
            Node(9, "Hardened Shell", "+2 DEF") { $0.defense += 2 },
            Node(fork: 10, "Preserve or Survive",
                 a: ForkOption(name: "Vital Surplus", effectText: "Above 75% HP: +5% damage reduction") { $0.forgeVitalSurplusDR = GameConfig.ForgePath.vitalSurplusDR },
                 b: ForkOption(name: "Last Stand", effectText: "Below 35% HP: +10% damage reduction") { $0.forgeLastStandDR = GameConfig.ForgePath.lastStandDR }),
            Node(11, "Deepened Vessel", "+6 Max HP") { $0.maxHP += 6; $0.currentHP += 6 },
            Node(12, "Forged Spine", "+3 DEF") { $0.defense += 3 },
            Node(13, "Restoration", "+5% healing received") { $0.forgeRestorationBonus = GameConfig.ForgePath.restorationBonus },
            Node(14, "Steady Pulse", "After 10s undamaged, recover 2 HP") { $0.forgeSteadyPulse = true },
            Node(fork: 15, "Crowds or Priority",
                 a: ForkOption(name: "Hold the Line", effectText: "5+ enemies near: +8% damage reduction") { $0.forgeHoldLineDR = GameConfig.ForgePath.holdLineDR },
                 b: ForkOption(name: "Giantkiller's Guard", effectText: "−10% damage from boss-class") { $0.forgeGiantkillerDR = GameConfig.ForgePath.giantkillerDR }),
            Node(16, "Iron Lungs", "+6 Max HP") { $0.maxHP += 6; $0.currentHP += 6 },
            Node(17, "Tempered Plate", "+3 DEF") { $0.defense += 3 },
            Node(18, "Defiant Recovery", "After taking damage, +10% healing for 4s") { $0.forgeDefiant = true },
            Node.behavioral(19, "Unshaken", "−10% duration of slows/impairments"),   // Unit 2 (no player-impair system yet)
            Node(fork: 20, "Emergency or Insurance",
                 a: ForkOption(name: "Second Breath", effectText: "Once/45s: below 25% HP restores 10% Max HP") { $0.forgeSecondBreath = true },
                 b: ForkOption(name: "Unyielding", effectText: "Once/45s: the next hit >20% Max HP is halved") { $0.forgeUnyielding = true }),
        ],
        .ferocity: [
            Node(1, "Whetted Edge", "+1 ATK") { $0.baseAttack += 1 },
            Node(2, "Stoked Furnace", "+1% damage") { $0.damageMultiplier += 0.01 },
            Node(3, "Honed Point", "+1 ATK") { $0.baseAttack += 1 },
            Node(4, "Bellows", "+1% damage") { $0.damageMultiplier += 0.01 },
            Node(fork: 5, "Risk or Reliability",
                 a: fx("Berserker", "Below 50% HP: +5% damage"),
                 b: ForkOption(name: "Executioner", effectText: "+2 ATK") { $0.baseAttack += 2 }),
            Node(6, "Tempered Edge", "+1 ATK") { $0.baseAttack += 1 },
            Node(7, "Furnace Pressure", "+1% damage") { $0.damageMultiplier += 0.01 },
            Node(8, "Keen Steel", "+1 ATK") { $0.baseAttack += 1 },
            Node(9, "Full Bellows", "+1% damage") { $0.damageMultiplier += 0.01 },
            Node(fork: 10, "Swarms or Priority",
                 a: fx("Cleaver", "4+ enemies near: +8% damage"),
                 b: fx("Headsman", "+10% damage to boss-class")),
            Node(11, "Forged Edge", "+2 ATK") { $0.baseAttack += 2 },
            Node(12, "White Heat", "+1.5% damage") { $0.damageMultiplier += 0.015 },
            Node.behavioral(13, "Rising Heat", "A kill grants +1% damage for 3s (stacks 5)"),
            Node.behavioral(14, "Opening Blow", "+10% damage to enemies above 90% HP"),
            Node(fork: 15, "Momentum or Patience",
                 a: fx("Bloodrush", "A kill grants +5% attack speed for 4s (stacks 3)"),
                 b: fx("Cold Fury", "Every 8s without a kill, +10% to the next enemy hit")),
            Node(16, "Hammered Point", "+2 ATK") { $0.baseAttack += 2 },
            Node(17, "Roaring Furnace", "+1.5% damage") { $0.damageMultiplier += 0.015 },
            Node.behavioral(18, "Relentless Pressure", "Repeated hits on one foe: +1%/stack to +5%"),
            Node.behavioral(19, "Overkill", "On kill, excess damage bursts to nearby foes"),
            Node(fork: 20, "Sustained or Decisive",
                 a: fx("Warpath", "After 6s of continuous damage, +10% damage"),
                 b: fx("Killing Stroke", "Every 12s, the next direct attack deals +75%")),
        ],
        .cunning: [
            Node(1, "Keen Eye", "+1% crit chance") { $0.critChance += 0.01 },
            Node(2, "Light Step", "+1% move speed") { $0.moveSpeedMultiplier += 0.01 },
            Node(3, "Sharp Focus", "+1% crit chance") { $0.critChance += 0.01 },
            Node(4, "Fleet Footing", "+1% move speed") { $0.moveSpeedMultiplier += 0.01 },
            Node(fork: 5, "Precision or Mobility",
                 a: ForkOption(name: "Deadeye", effectText: "+10% critical damage") { $0.critMultiplier += 0.10 },
                 b: ForkOption(name: "Windrunner", effectText: "+3% move speed") { $0.moveSpeedMultiplier += 0.03 }),
            Node(6, "Clear Sight", "+1% crit chance") { $0.critChance += 0.01 },
            Node(7, "Quickened Step", "+1% move speed") { $0.moveSpeedMultiplier += 0.01 },
            Node(8, "Long Reach", "+5% pickup radius") { $0.pickupRadiusMultiplier += 0.05 },
            Node(9, "Practiced Motion", "+1% move speed") { $0.moveSpeedMultiplier += 0.01 },
            Node(fork: 10, "Collection or Escape",
                 a: ForkOption(name: "Magnetized", effectText: "+15% pickup radius") { $0.pickupRadiusMultiplier += 0.15 },
                 b: fx("Slipstream", "After a near-miss, +8% move speed for 2s")),
            Node(11, "Trained Eye", "+1.5% crit chance") { $0.critChance += 0.015 },
            Node(12, "Swift Form", "+1.5% move speed") { $0.moveSpeedMultiplier += 0.015 },
            Node.behavioral(13, "Opportunist", "+5% damage to impaired foes"),
            Node.behavioral(14, "Efficient Sweep", "Collecting XP grants +5% pickup for 2s (stacks 3)"),
            Node(fork: 15, "Consistency or Volatility",
                 a: fx("Calculated Strike", "Every 5th direct attack is a guaranteed crit"),
                 b: fx("Lucky Break", "Crits have a 10% chance to deal +50% crit damage")),
            Node(16, "Refined Focus", "+1.5% crit chance") { $0.critChance += 0.015 },
            Node(17, "Effortless Motion", "+1.5% move speed") { $0.moveSpeedMultiplier += 0.015 },
            Node.behavioral(18, "Read the Room", "When an elite/boss enters, +8% move speed for 4s"),
            Node.behavioral(19, "Salvager", "Forge XP Coins are attracted from 10% farther"),
            Node(fork: 20, "Planned or Emergency",
                 a: fx("Foresight", "+1 reroll per run"),
                 b: fx("Second Look", "Once/run: passing a whole offer regenerates it free")),
        ],
    ]

    static let ladderLength = 20   // authored depth (21–50 come later)

    // MARK: - State

    /// Every pick ever made, in order. The Nth pick in a branch = its level N.
    private(set) var picks: [Branch] = []

    /// Fork choices, keyed "Branch:level" → true = option B, false/absent = A.
    private var forkChoices: [String: Bool] = [:]

    private func forkKey(_ branch: Branch, _ level: Int) -> String { "\(branch.rawValue):\(level)" }

    /// One pick per two forge levels, rounded up — migration-generous.
    var picksEarned: Int {
        (ProgressionManager.shared.forgeLevel + 1) / 2
    }

    var picksAvailable: Int {
        max(0, picksEarned - picks.count)
    }

    func countInBranch(_ branch: Branch) -> Int {
        picks.filter { $0 == branch }.count
    }

    private func node(_ branch: Branch, level: Int) -> Node? {
        guard let ladder = Self.ladders[branch], level >= 1, level <= ladder.count else { return nil }
        return ladder[level - 1]
    }

    /// The node the next pick in this branch would grant (nil if the ladder's maxed).
    func nextNode(for branch: Branch) -> Node? {
        node(branch, level: countInBranch(branch) + 1)
    }

    /// Whether a chosen fork resolves to option B (true) vs A (false/default).
    func forkChoiceIsB(_ branch: Branch, level: Int) -> Bool {
        forkChoices[forkKey(branch, level)] ?? false
    }

    /// Set (or change) a milestone fork choice. Free — respec-friendly.
    func setForkChoice(_ branch: Branch, level: Int, chooseB: Bool) {
        forkChoices[forkKey(branch, level)] = chooseB
        save()
    }

    /// Spend one available pick on a branch. If it lands on a fork with no stored
    /// choice, default to option A (the fork picker UI arrives in Unit 3).
    func choose(_ branch: Branch) {
        guard picksAvailable > 0, countInBranch(branch) < Self.ladderLength else { return }
        picks.append(branch)
        let level = countInBranch(branch)
        if let node = node(branch, level: level), node.fork != nil, forkChoices[forkKey(branch, level)] == nil {
            forkChoices[forkKey(branch, level)] = false   // default A
        }
        save()
    }

    /// v1.9 Unit 7: free, unlimited respec — clear all spent picks AND fork
    /// choices so every earned mastery point is available to re-spend.
    func respec() {
        picks = []
        forkChoices = [:]
        save()
    }

    // MARK: - Apply

    /// Walk each branch's spent count down its ladder, resolving forks via the
    /// stored choice, onto run stats.
    func applyPathBonuses(to stats: PlayerStats) {
        for branch in Branch.allCases {
            let count = countInBranch(branch)
            guard count > 0, let ladder = Self.ladders[branch] else { continue }
            for level in 1...min(count, ladder.count) {
                let node = ladder[level - 1]
                if let fork = node.fork {
                    (forkChoiceIsB(branch, level: level) ? fork.b : fork.a).apply(stats)
                } else {
                    node.apply(stats)
                }
            }
        }
    }

    // MARK: - Summary

    /// Branches with at least one pick, in canonical order, with counts.
    var summary: [(branch: Branch, count: Int)] {
        Branch.allCases.compactMap { branch in
            let count = countInBranch(branch)
            return count > 0 ? (branch, count) : nil
        }
    }

    // MARK: - Persistence

    private func save() {
        defaults.set(picks.map(\.rawValue), forKey: Keys.pathPicks)
        defaults.set(forkChoices, forKey: Keys.pathForks)
    }

    private func load() {
        let raw = defaults.stringArray(forKey: Keys.pathPicks) ?? []
        picks = raw.compactMap(Branch.init(rawValue:))
        forkChoices = (defaults.dictionary(forKey: Keys.pathForks) as? [String: Bool]) ?? [:]
    }

    // MARK: - Reset (testing)

    func resetAll() {
        picks = []
        forkChoices = [:]
        defaults.removeObject(forKey: Keys.pathPicks)
        defaults.removeObject(forKey: Keys.pathForks)
    }

    private init() {
        load()
    }
}
