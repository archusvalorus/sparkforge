// Run-owned ownership/command ledger. No spawning, movement, attacks or saves.
import Foundation

final class Arena8PacketCommands {
    enum SourceRole: Equatable { case carrier, signaler }
    struct Packet: Equatable {
        let id: UUID
        let owner: UUID
        let incarnation: UUID
        fileprivate(set) var members: Set<UUID>
        fileprivate(set) var revision: UUID
    }
    struct MembershipTicket: Equatable {
        let generation: UUID
        let packetID: UUID
        let incarnation: UUID
        let member: UUID
    }
    struct Ticket: Equatable {
        let generation: UUID
        let packetID: UUID
        let packetRevision: UUID
        let commandID: UUID
        let source: UUID
        let sourceRole: SourceRole
        let connectionID: Int
    }
    struct Navigation: Equatable {
        let ticket: Ticket
        let members: Set<UUID>
    }
    private struct Command {
        let ticket: Ticket
        var remaining: TimeInterval
        var committed: Bool
    }
    private(set) var generation = UUID()
    private(set) var packets: [UUID: Packet] = [:]
    private var membership: [UUID: UUID] = [:]
    private var commands: [UUID: Command] = [:]

    /// All identities must be new to this run; callers generate stable node UUIDs.
    @discardableResult func register(id: UUID, owner: UUID, escorts: [UUID]) -> Bool {
        let escortSet = Set(escorts)
        let members = escortSet.union([owner])
        guard packets[id] == nil, escortSet.count == escorts.count,
              !escortSet.contains(owner), members.allSatisfy({ membership[$0] == nil }) else { return false }
        let packet = Packet(id: id, owner: owner, incarnation: UUID(), members: members, revision: UUID())
        packets[id] = packet
        for member in members { membership[member] = id }
        return true
    }

    /// The Scene authorizes a same-room Signaler at prepare AND commit.
    /// Pending/committed commands share one slot: the first valid claim wins.
    func prepare(packetID: UUID, expectedRevision: UUID, source: UUID,
                 authorizedSignaler: UUID? = nil, connectionID: Int, telegraphDuration: TimeInterval,
                 live: Set<UUID>, destinationValid: () -> Bool) -> Ticket? {
        guard let packet = packets[packetID], packet.revision == expectedRevision,
              commands[packetID] == nil, live.contains(source),
              (packet.owner == source || (authorizedSignaler == source && !packet.members.contains(source))),
              telegraphDuration.isFinite, telegraphDuration >= 0,
              packet.members.isSubset(of: live), destinationValid() else { return nil }
        let ticket = Ticket(generation: generation, packetID: packetID,
                            packetRevision: packet.revision, commandID: UUID(),
                            source: source, sourceRole: packet.owner == source ? .carrier : .signaler,
                            connectionID: connectionID)
        commands[packetID] = Command(ticket: ticket, remaining: telegraphDuration, committed: false)
        return ticket
    }

    /// Only active game time supplied by the scene can advance a warning.
    @discardableResult func advance(_ ticket: Ticket, dt: TimeInterval, held: Bool) -> Bool {
        guard var command = current(ticket), !command.committed,
              dt.isFinite, dt >= 0 else { return false }
        if !held { command.remaining = max(0, command.remaining - dt) }
        commands[ticket.packetID] = command
        return true
    }

    func remaining(_ ticket: Ticket) -> TimeInterval? { current(ticket)?.remaining }

    /// No automatic commit. Recheck the live set and actual body-clear destination here.
    func commit(_ ticket: Ticket, held: Bool, live: Set<UUID>,
                authorizedSignaler: UUID? = nil, destinationValid: () -> Bool) -> Navigation? {
        guard !held, var command = current(ticket), !command.committed,
              command.remaining == 0, let packet = packets[ticket.packetID],
              packet.revision == ticket.packetRevision,
              live.contains(ticket.source),
              (ticket.sourceRole == .carrier ? packet.owner == ticket.source : authorizedSignaler == ticket.source && !packet.members.contains(ticket.source)),
              packet.members.isSubset(of: live),
              destinationValid() else { return nil }
        command.committed = true
        commands[ticket.packetID] = command
        return Navigation(ticket: ticket, members: packet.members)
    }

    /// A committed command can only address its current living members. Navigation does not
    /// overwrite an EnemyNode combat target or grant permission to interrupt an attack.
    func navigation(_ ticket: Ticket) -> Navigation? {
        guard let command = current(ticket), command.committed,
              let packet = packets[ticket.packetID] else { return nil }
        return Navigation(ticket: ticket, members: packet.members)
    }

    /// Cancelling/finishing only releases this intent, never removes or rewards an actor.
    @discardableResult func cancel(_ ticket: Ticket) -> Bool {
        guard current(ticket) != nil else { return false }
        commands.removeValue(forKey: ticket.packetID)
        return true
    }

    /// Capture this association when scheduling any death/removal work. Actor UUID alone
    /// is insufficient because a survivor may have joined a different packet meanwhile.
    func membershipTicket(for member: UUID) -> MembershipTicket? {
        guard let id = membership[member], let packet = packets[id] else { return nil }
        return MembershipTicket(generation: generation, packetID: id,
                                incarnation: packet.incarnation, member: member)
    }

    /// Remove one member exactly once. Owner loss dissolves ownership and returns only
    /// surviving escorts for the scene to release back to their ordinary behavior.
    @discardableResult func remove(_ ticket: MembershipTicket) -> Set<UUID> {
        guard ticket.generation == generation, let id = membership[ticket.member],
              id == ticket.packetID, var packet = packets[id],
              packet.incarnation == ticket.incarnation else { return [] }
        let member = ticket.member
        membership.removeValue(forKey: member)
        packet.members.remove(member)
        if packet.owner == member {
            commands.removeValue(forKey: id)
            packets.removeValue(forKey: id)
            for survivor in packet.members { membership.removeValue(forKey: survivor) }
            return packet.members
        }
        packet.revision = UUID()
        packets[id] = packet
        if commands[id]?.committed == false { commands.removeValue(forKey: id) }
        return []
    }

    func reset() {
        generation = UUID()
        packets.removeAll()
        membership.removeAll()
        commands.removeAll()
    }

    private func current(_ ticket: Ticket) -> Command? {
        guard ticket.generation == generation, let packet = packets[ticket.packetID],
              (ticket.sourceRole == .carrier ? packet.owner == ticket.source : !packet.members.contains(ticket.source)),
              let command = commands[ticket.packetID],
              command.ticket == ticket else { return nil }
        return command
    }
}
