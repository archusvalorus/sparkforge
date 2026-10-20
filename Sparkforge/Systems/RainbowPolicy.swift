// RainbowPolicy.swift
// v2.3 R0: isolated proof only. No production caller or live catalog entry.
// This plans a special reward; it never applies effects, changes a real spread,
// grants a level, or mutates UpgradeManager. See the R0 kickoff/return packet.

import Foundation

struct RainbowPolicy {
    typealias Tag = UpgradeManager.Tag
    typealias Capability = UpgradeManager.Capability

    struct Snapshot {
        let palette: Set<Tag>
        let covered: Set<Tag>
        let capabilities: Set<Capability>

        /// Read actual first acquisitions, not picks/tiers or speculative offers.
        init(manager: UpgradeManager) {
            palette = manager.activeFamilies.subtracting([.neutral])
            var colors: Set<Tag> = []
            for card in manager.pickedCards where !card.isSecret {
                colors.insert(card.tag)
                if let second = card.secondaryTag { colors.insert(second) }
            }
            covered = colors.intersection(palette)
            capabilities = manager.capabilities
        }
    }

    /// R1 must provide real effects and catalog/UI representation before this
    /// special descriptor is ever turned into a selectable production entry.
    struct Reward: Equatable {
        enum Category { case breadthReward }
        let id = "special_variegated_rainbow"
        let category = Category.breadthReward
        let ranks = 1
    }
    static let reward = Reward()

    enum Source { case ordinaryLevelUp, randomOpener, bonus }
    nonisolated enum Protection: Hashable { case gateway, capstone, secret, signatureOpening }
    struct Seat {
        let cardID: String
        let protections: Set<Protection>
        init(_ cardID: String, protectedBy protections: Set<Protection> = []) {
            self.cardID = cardID
            self.protections = protections
        }
    }
    struct Offer: Equatable {
        let level: Int
        let seat: Int
        let reward: Reward
    }
    struct Commitment: Equatable {
        let level: Int
        let picksConsumed: Int
        let picksRemaining: Int
    }
    enum Phase: Equatable {
        case unqualified, pendingOffer, offered(level: Int), deferred
        case selected(level: Int), conflictClosed, paletteMismatch
    }

    private(set) var requiredColors: Set<Tag>
    private(set) var coveredColors: Set<Tag> = []
    private(set) var phase: Phase = .unqualified
    private(set) var selectedLevel: Int?
    private var paletteMatches = true
    private var conflict = false
    private var latestOrdinaryLevel: Int?
    private var offeredLevel: Int?
    private var nextOfferLevel: Int?

    init(snapshot: Snapshot) {
        requiredColors = snapshot.palette
        refresh(snapshot)
    }

    var qualified: Bool {
        paletteMatches && !requiredColors.isEmpty && requiredColors.isSubset(of: coveredColors)
    }

    /// This additional policy must not replace existing prerequisites/focus.
    /// It blocks only actual next-tier grants of the approved conflicting forms.
    func permitsNextTier(_ card: UpgradeManager.UpgradeCard, manager: UpgradeManager) -> Bool {
        guard paletteMatches else { return false }
        guard selectedLevel != nil else { return true }
        let current = manager.tier(of: card.id)
        let grants = (current == 0 ? card.provides : []).union(card.tierProvides[current + 1] ?? [])
        return grants.isDisjoint(with: [.chaosBeam, .glacialCondensation])
    }

    /// Revalidate stale Extra Pick, bonus, opener and granted acquisitions at
    /// the same authoritative seam. The caller still owns the real apply.
    mutating func permitsAcquisition(_ card: UpgradeManager.UpgradeCard,
                                    manager: UpgradeManager, level: Int) -> Bool {
        refresh(Snapshot(manager: manager))
        return manager.isSelectable(card, atLevel: level, additionalTierGate: {
            permitsNextTier($0, manager: manager)
        })
    }

    mutating func reset(snapshot: Snapshot) {
        self = RainbowPolicy(snapshot: snapshot)
    }

    mutating func refresh(_ snapshot: Snapshot) {
        // Fail closed once a palette changes; explicit run reset is required.
        paletteMatches = paletteMatches && snapshot.palette == requiredColors
        coveredColors = snapshot.covered.intersection(requiredColors)
        conflict = !snapshot.capabilities.isDisjoint(with: [.chaosBeam, .glacialCondensation])
        updatePhase()
    }

    /// `seats` are the final spread after pre-existing guarantees. Nothing is
    /// appended, and a reroll can retain a prior entitlement but cannot create
    /// one after a protected first draw or a mid-level acquisition.
    mutating func plan(level: Int, source: Source, owedPicks: Int,
                       seats: [Seat], snapshot: Snapshot) -> Offer? {
        refresh(snapshot)
        guard source == .ordinaryLevelUp, owedPicks > 0, level >= 0 else { return nil }
        if let latest = latestOrdinaryLevel, level < latest { return nil }
        let fresh = latestOrdinaryLevel != level
        if fresh {
            latestOrdinaryLevel = level
            offeredLevel = nil
        }
        guard qualified, selectedLevel == nil, !conflict else { return nil }
        if !fresh && offeredLevel != level { return nil }
        if let next = nextOfferLevel, level < next { updatePhase(); return nil }
        guard let seat = seats.firstIndex(where: { $0.protections.isEmpty }) else {
            // No Rainbow is displayed in this latest spread. A prior reroll's
            // receipt must not remain selectable after guarantees fill it.
            offeredLevel = nil
            phase = .deferred
            return nil
        }
        offeredLevel = level
        phase = .offered(level: level)
        return Offer(level: level, seat: seat, reward: Self.reward)
    }

    /// Declining means a successful different pick closes the ordinary choice.
    /// Do not call this merely because the UI rerolled or took an Extra Pick's
    /// first option while another choice is still owed.
    mutating func decline(level: Int) {
        guard offeredLevel == level, selectedLevel == nil else { return }
        nextOfferLevel = level + 2
        offeredLevel = nil
        phase = .deferred
    }

    /// Receipts are proof outputs, not effects. An offer from a past spread or
    /// form-invalidated Extra Pick is rejected without consuming a pick.
    mutating func commit(_ offer: Offer, source: Source, owedPicks: Int,
                         snapshot: Snapshot) -> Commitment? {
        refresh(snapshot)
        guard source == .ordinaryLevelUp, owedPicks > 0,
              offer.reward == Self.reward, offer.level == latestOrdinaryLevel,
              offer.level == offeredLevel, qualified, !conflict,
              selectedLevel == nil else { return nil }
        selectedLevel = offer.level
        offeredLevel = nil
        nextOfferLevel = nil
        phase = .selected(level: offer.level)
        return Commitment(level: offer.level, picksConsumed: 1, picksRemaining: owedPicks - 1)
    }

    private mutating func updatePhase() {
        if !paletteMatches { phase = .paletteMismatch }
        else if let selected = selectedLevel { phase = .selected(level: selected) }
        else if conflict { phase = .conflictClosed }
        else if !qualified { phase = .unqualified }
        else if let offered = offeredLevel { phase = .offered(level: offered) }
        else if nextOfferLevel != nil { phase = .deferred }
        else { phase = .pendingOffer }
    }
}
