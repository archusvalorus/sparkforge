import Foundation
var passed = 0, failed = 0
func check(_ name: String, _ value: @autoclosure () -> Bool) {
    if value() { passed += 1; print("PASS \(name)") } else { failed += 1; print("FAIL \(name)") }
}
let core = Arena8PacketCommands()
let packetID = UUID(), owner = UUID(), first = UUID(), second = UUID()
let living: Set<UUID> = [owner, first, second]
check("register explicit packet", core.register(id: packetID, owner: owner, escorts: [first, second]))
check("duplicate packet rejected", !core.register(id: packetID, owner: UUID(), escorts: []))
check("member cannot have second owner", !core.register(id: UUID(), owner: UUID(), escorts: [first]))
let freshDuplicate = UUID(), duplicateOwner = UUID(), duplicatePacket = UUID()
let countBeforeDuplicate = core.packets.count
check("duplicate escorts rejected atomically", !core.register(id: duplicatePacket, owner: duplicateOwner, escorts: [freshDuplicate, freshDuplicate]) && core.packets.count == countBeforeDuplicate)
check("rejected registration leaked no ownership", core.register(id: duplicatePacket, owner: duplicateOwner, escorts: [freshDuplicate]))
guard let duplicateOwnerTicket = core.membershipTicket(for: duplicateOwner) else { fatalError("duplicate cleanup fixture absent") }
check("isolated duplicate fixture cleans up", core.remove(duplicateOwnerTicket) == [freshDuplicate] && core.packets.count == countBeforeDuplicate)
let freshOwnerOverlap = UUID()
check("owner cannot duplicate escort", !core.register(id: UUID(), owner: freshOwnerOverlap, escorts: [freshOwnerOverlap]) && core.membershipTicket(for: freshOwnerOverlap) == nil && core.packets.count == countBeforeDuplicate)
guard let packet = core.packets[packetID] else { fatalError("registered fixture absent") }
check("all explicit identities retained", packet.members == living)
guard let ownerMembership = core.membershipTicket(for: owner),
      let firstMembership = core.membershipTicket(for: first),
      let secondMembership = core.membershipTicket(for: second) else { fatalError("membership fixtures absent") }
for duration in [-1.0, Double.nan, Double.infinity] {
    check("invalid duration refuses preparation", core.prepare(packetID: packetID, expectedRevision: packet.revision, source: owner, connectionID: 2, telegraphDuration: duration, live: living, destinationValid: {true}) == nil)
}
check("foreign source refused", core.prepare(packetID: packetID, expectedRevision: packet.revision, source: first, connectionID: 2, telegraphDuration: 1, live: living, destinationValid: {true}) == nil)
check("stale revision refused", core.prepare(packetID: packetID, expectedRevision: UUID(), source: owner, connectionID: 2, telegraphDuration: 1, live: living, destinationValid: {true}) == nil)
check("dead member refuses prepare", core.prepare(packetID: packetID, expectedRevision: packet.revision, source: owner, connectionID: 2, telegraphDuration: 1, live: [owner, first], destinationValid: {true}) == nil)
check("invalid destination refuses prepare", core.prepare(packetID: packetID, expectedRevision: packet.revision, source: owner, connectionID: 2, telegraphDuration: 1, live: living, destinationValid: {false}) == nil)
guard let ticket = core.prepare(packetID: packetID, expectedRevision: packet.revision, source: owner, connectionID: 2, telegraphDuration: 1.5, live: living, destinationValid: {true}) else { fatalError("valid preparation absent") }
check("captured destination unchanged", ticket.connectionID == 2 && ticket.source == owner)
check("no competing preparation silently replaces tell", core.prepare(packetID: packetID, expectedRevision: packet.revision, source: owner, connectionID: 3, telegraphDuration: 1, live: living, destinationValid: {true}) == nil)
check("prepared is not navigation", core.navigation(ticket) == nil)
check("not early commit", core.commit(ticket, held: false, live: living, destinationValid: {true}) == nil)
check("active step accepted", core.advance(ticket, dt: 0.25, held: false))
check("active remaining exact", core.remaining(ticket) == 1.25)
for _ in 0..<30 { check("hold step accepted without progress", core.advance(ticket, dt: 10, held: true)) }
check("held time does not progress", core.remaining(ticket) == 1.25)
for dt in [-1.0, Double.nan, Double.infinity] { check("invalid delta refuses advance", !core.advance(ticket, dt: dt, held: false)) }
check("invalid delta does not mutate", core.remaining(ticket) == 1.25)
check("advance to exact boundary", core.advance(ticket, dt: 1.25, held: false))
check("warning ready never auto commits", core.remaining(ticket) == 0 && core.navigation(ticket) == nil)
check("held ready cannot commit", core.commit(ticket, held: true, live: living, destinationValid: {true}) == nil)
check("live source required again", core.commit(ticket, held: false, live: [first, second], destinationValid: {true}) == nil)
check("geometry required again", core.commit(ticket, held: false, live: living, destinationValid: {false}) == nil)
let navigation = core.commit(ticket, held: false, live: living, destinationValid: {true})
check("commit captures current living packet", navigation?.members == living && navigation?.ticket == ticket)
check("commit only once", core.commit(ticket, held: false, live: living, destinationValid: {true}) == nil)
check("committed timer cannot advance", !core.advance(ticket, dt: 1, held: false))
check("member death has no surviving-release effect", core.remove(firstMembership).isEmpty)
check("committed intent retains only survivors", core.navigation(ticket)?.members == [owner, second])
check("duplicate member death no effect", core.remove(firstMembership).isEmpty && core.navigation(ticket)?.members == [owner, second])
check("owner death releases surviving escort", core.remove(ownerMembership) == [second])
check("owner death cancels navigation", core.navigation(ticket) == nil && core.remaining(ticket) == nil)
check("owner death removes packet", core.packets[packetID] == nil)
check("owner duplicate release empty", core.remove(ownerMembership).isEmpty)
check("released escort can be registered anew", core.register(id: packetID, owner: owner, escorts: [second]))
guard let again = core.packets[packetID], let warning = core.prepare(packetID: packetID, expectedRevision: again.revision, source: owner, connectionID: 1, telegraphDuration: 4, live: [owner, second], destinationValid: {true}) else { fatalError("second fixture absent") }
guard let newSecondMembership = core.membershipTicket(for: second) else { fatalError("new membership fixture absent") }
check("regrouped escort rejects old association callback", core.remove(secondMembership).isEmpty && core.packets[packetID]?.members.contains(second) == true)
check("reused packet rejects old owner callback", core.remove(ownerMembership).isEmpty && core.packets[packetID]?.members.contains(owner) == true)
core.remove(newSecondMembership)
check("membership change invalidates uncommitted tell", core.remaining(warning) == nil && !core.advance(warning, dt: 10, held: false))
check("stale warning cannot commit", core.commit(warning, held: false, live: [owner], destinationValid: {true}) == nil)
guard let latest = core.packets[packetID], let zero = core.prepare(packetID: packetID, expectedRevision: latest.revision, source: owner, connectionID: 1, telegraphDuration: 0, live: [owner], destinationValid: {true}) else { fatalError("zero-duration test absent") }
check("zero duration still requires explicit commit", core.navigation(zero) == nil)
check("cancel intent exactly once", core.cancel(zero) && !core.cancel(zero))
guard let resetTicket = core.prepare(packetID: packetID, expectedRevision: latest.revision, source: owner, connectionID: 1, telegraphDuration: 0, live: [owner], destinationValid: {true}) else { fatalError("reset fixture absent") }
guard let preResetOwner = core.membershipTicket(for: owner) else { fatalError("reset membership fixture absent") }
let generation = core.generation; core.reset()
check("reset rotates epoch", core.generation != generation)
check("reset removes all packets", core.packets.isEmpty)
check("reset rejects timer callback", !core.advance(resetTicket, dt: 1, held: false))
check("reset rejects commit callback", core.commit(resetTicket, held: false, live: [owner], destinationValid: {true}) == nil)
check("reset rejects stale cancellation", !core.cancel(resetTicket))
check("same external identities may belong to new run", core.register(id: packetID, owner: owner, escorts: [first, second]))
check("stale old-run ticket cannot touch reused identities", !core.cancel(resetTicket) && core.navigation(ticket) == nil)
check("stale old-run removal cannot touch reused identities", core.remove(preResetOwner).isEmpty && core.packets[packetID]?.members == living)
print("RESULT \(passed) passed \(failed) failed")
exit(failed == 0 ? 0 : 1)
