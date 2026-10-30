// Run-owned encounter bookkeeping only; never spawns, kills, awards or saves.
import Foundation
import CoreGraphics

final class Arena9EncounterLedger {
    struct Ticket: Equatable {
        let generation: UUID
        let encounterID: String
    }
    private let definition: Arena9StageDefinition
    private(set) var generation = UUID()
    private(set) var activated = Set<String>()
    private(set) var live = Set<String>()

    init(definition: Arena9StageDefinition) { self.definition = definition }

    /// Planning query only. The caller must choose when/how to commit activation.
    /// No max-progress memory, irreversible camera frontier or completion default.
    func candidates(at point: CGPoint) -> [String] {
        guard Arena9StageDefinition.finite(point),
              Arena9StageDefinition.containsClosed(point, in: definition.world) else { return [] }
        return definition.encounters.filter { point.x >= $0.triggerX && !activated.contains($0.id) }.map(\.id)
    }

    /// Supports explicit encounter entry; duplicate/re-entered IDs never replay.
    func activate(_ id: String) -> Ticket? {
        guard definition.encounters.contains(where: { $0.id == id }), activated.insert(id).inserted else { return nil }
        live.insert(id)
        return Ticket(generation: generation, encounterID: id)
    }

    func accepts(_ ticket: Ticket) -> Bool {
        ticket.generation == generation && live.contains(ticket.encounterID)
    }

    /// Explicit ownership retirement, not an auto-despawn/XP retirement policy.
    @discardableResult func retire(_ ticket: Ticket) -> Bool {
        guard accepts(ticket) else { return false }
        live.remove(ticket.encounterID)
        return true
    }

    /// Caller invokes on replacement/death/Title as appropriate after integration.
    /// UUID renewal prevents callbacks from a prior run matching a reused ID.
    func reset() {
        generation = UUID()
        activated.removeAll()
        live.removeAll()
    }
}
