import Foundation
import CoreGraphics

/// Run ownership only. Retreat never retires members; ordinary death does.
/// A packet cannot clear before every expected spawn is registered and sealed.
final class Arena9TraversalRun {
    private let ledger: Arena9EncounterLedger
    private let finalID: String
    private let goal: CGRect
    private var members: [String: Set<UUID>] = [:]
    private var sealed = Set<String>()
    private var registeredCounts: [String: Int] = [:]
    private var seenMembers = Set<UUID>()
    private var owners: [UUID: Arena9EncounterLedger.Ticket] = [:]
    private(set) var reachedGoal = false
    private(set) var awardedSuccess = false
    private(set) var active = true

    init(definition: Arena9StageDefinition, finalID: String, goal: CGRect) {
        ledger = Arena9EncounterLedger(definition: definition)
        self.finalID = finalID
        self.goal = goal
    }
    func enter(at point: CGPoint) -> [Arena9EncounterLedger.Ticket] {
        guard active else { return [] }
        return ledger.candidates(at: point).compactMap { ledger.activate($0) }
    }
    @discardableResult func register(_ id: UUID, ticket: Arena9EncounterLedger.Ticket) -> Bool {
        guard active, ledger.accepts(ticket), !sealed.contains(ticket.encounterID), !seenMembers.contains(id) else { return false }
        members[ticket.encounterID, default: []].insert(id)
        seenMembers.insert(id)
        registeredCounts[ticket.encounterID, default: 0] += 1
        owners[id] = ticket
        return true
    }
    @discardableResult func seal(_ ticket: Arena9EncounterLedger.Ticket, expectedCount: Int) -> Bool {
        guard active, ledger.accepts(ticket), expectedCount > 0,
              registeredCounts[ticket.encounterID] == expectedCount,
              sealed.insert(ticket.encounterID).inserted else { return false }
        return true
    }
    @discardableResult func retire(_ id: UUID) -> Bool {
        guard active, let ticket = owners.removeValue(forKey: id), ledger.accepts(ticket) else { return false }
        members[ticket.encounterID]?.remove(id)
        return true
    }
    func observeGoal(at point: CGPoint) {
        guard active, Arena9StageDefinition.finite(point) else { return }
        if Arena9StageDefinition.containsClosed(point, in: goal) { reachedGoal = true }
    }
    @discardableResult func claimSuccess() -> Bool {
        guard active, !awardedSuccess, reachedGoal, sealed.contains(finalID), members[finalID]?.isEmpty == true else { return false }
        awardedSuccess = true
        return true
    }
    func cancel() {
        active = false
        ledger.reset()
        owners.removeAll(); members.removeAll(); sealed.removeAll()
        registeredCounts.removeAll(); seenMembers.removeAll()
    }
}
