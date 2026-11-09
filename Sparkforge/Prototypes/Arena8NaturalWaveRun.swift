#if DEBUG
import Foundation

extension GameConfig {
    /// Provisional first encounter only; not production balance.
    enum Arena8NaturalWaveFixture {
        static let packetIntroduction: TimeInterval = 30
        static let signalerIntroduction: TimeInterval = 34
        static let packetCost = 3
    }
}

enum Arena8NaturalWaveMode {
    static func enabled(arguments: [String], sixRoom: Bool, isolated: Bool, arena9: Bool) -> Bool {
        let args = Set(arguments)
        return sixRoom && isolated && !arena9 && args.contains("--arena8-natural-waves")
            && args.isDisjoint(with: ["--arena8-lockmarshal", "--arena8-mixed-pressure", "--arena8-pressure-trial",
                "--arena8-carrier-fixture", "--arena8-signaler-fixture", "--arena8-six-traversal",
                "--arena8-pressure-kiting", "--arena8-pressure-late"])
    }
}

/// A run-owned accounting ledger, not a second clock or an enemy factory.
/// The caller supplies only unsuppressed emissions of the accepted trial clock.
struct Arena8NaturalWaveRun {
    enum Action: String { case ordinary, reservePacket, packet, signaler }
    struct Ticket: Equatable {
        fileprivate let generation: UUID
        fileprivate let sequence: Int
        let action: Action
    }
    private(set) var generation = UUID()
    private(set) var emissions = 0
    private(set) var ordinarySlots = 0
    private(set) var reservedSlots = 0
    private(set) var packetSlots = 0
    private(set) var signalerSlots = 0
    private(set) var packetAttempts = 0
    private(set) var signalerAttempts = 0
    private(set) var packetIntroduced = false
    private(set) var signalerIntroduced = false
    private(set) var signalerSkipped = false
    private(set) var commandPrepared = false
    private(set) var pending: Ticket?
    private var lastEmissionTime: TimeInterval?

    /// Reserving the first two due slots avoids borrowing future spawns for
    /// an atomic three-body packet. Once funded, blocked attempts fall back to
    /// one ordinary slot; the two reservations remain visible, never duplicated.
    mutating func begin(elapsed: TimeInterval, carrierAlive: Bool, held: Bool = false) -> Ticket? {
        guard !held, pending == nil, elapsed.isFinite, elapsed >= 0,
              lastEmissionTime.map({ elapsed > $0 }) ?? true else { return nil }
        let action: Action
        if !packetIntroduced, elapsed >= GameConfig.Arena8NaturalWaveFixture.packetIntroduction {
            action = reservedSlots < GameConfig.Arena8NaturalWaveFixture.packetCost - 1 ? .reservePacket : .packet
        } else if packetIntroduced, !signalerIntroduced, !signalerSkipped,
                  elapsed >= GameConfig.Arena8NaturalWaveFixture.signalerIntroduction {
            if carrierAlive { action = .signaler }
            else { signalerSkipped = true; action = .ordinary }
        } else { action = .ordinary }
        emissions += 1; lastEmissionTime = elapsed
        let ticket = Ticket(generation: generation, sequence: emissions, action: action)
        pending = ticket
        return ticket
    }

    /// Returns whether this emission is an ordinary spawn attempt. Success is
    /// supplied only after actual atomic Scene placement, never before it.
    @discardableResult mutating func finish(_ ticket: Ticket, placed: Bool) -> Bool? {
        guard pending == ticket, ticket.generation == generation else { return nil }
        pending = nil
        switch ticket.action {
        case .reservePacket:
            reservedSlots += 1
            return false
        case .packet:
            packetAttempts += 1
            if placed {
                packetIntroduced = true
                packetSlots = reservedSlots + 1; reservedSlots = 0
                return false
            }
        case .signaler:
            signalerAttempts += 1
            if placed { signalerIntroduced = true; signalerSlots = 1; return false }
        case .ordinary: break
        }
        ordinarySlots += 1
        return true
    }

    /// One accepted preparation per run, even if it is subsequently cancelled.
    @discardableResult mutating func recordPreparedCommand() -> Bool {
        guard signalerIntroduced, !commandPrepared else { return false }
        commandPrepared = true
        return true
    }
    var accountedSlots: Int { ordinarySlots + reservedSlots + packetSlots + signalerSlots }
}
#endif
