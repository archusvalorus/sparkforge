import Foundation
var passed = 0, failed = 0
func check(_ name: String, _ value: Bool) { if value { passed += 1; print("PASS " + name) } else { failed += 1; print("FAIL " + name) } }
struct Fixture {
    let core = Arena8PacketCommands()
    let packet = UUID(), owner = UUID(), first = UUID(), second = UUID(), signaler = UUID()
    var live: Set<UUID> { [owner, first, second, signaler] }
    init() { precondition(core.register(id: packet, owner: owner, escorts: [first, second])) }
    func prepare(_ source: UUID, authorized: UUID? = nil, duration: TimeInterval = 1) -> Arena8PacketCommands.Ticket? {
        guard let p = core.packets[packet] else { return nil }
        return core.prepare(packetID: packet, expectedRevision: p.revision, source: source, authorizedSignaler: authorized, connectionID: 0, telegraphDuration: duration, live: live, destinationValid: { true })
    }
    func signal() -> Arena8PacketCommands.Ticket? { prepare(signaler, authorized: signaler) }
}
let f = Fixture()
check("foreign source still needs authorization", f.prepare(f.signaler) == nil)
check("wrong authorization refused", f.prepare(f.signaler, authorized: UUID()) == nil)
check("member cannot impersonate signaler", f.prepare(f.first, authorized: f.first) == nil)
if let p = f.core.packets[f.packet] {
    check("dead signaler refuses prepare", f.core.prepare(packetID: f.packet, expectedRevision: p.revision, source: f.signaler, authorizedSignaler: f.signaler, connectionID: 0, telegraphDuration: 1, live: [f.owner,f.first,f.second], destinationValid: { true }) == nil)
    for duration in [-1,Double.infinity,Double.nan] {
        check("invalid signal duration refused", f.prepare(f.signaler, authorized: f.signaler, duration: duration) == nil)
    }
}
for sourceFirst in [false,true] {
    let x = Fixture()
    guard let t = sourceFirst ? x.signal() : x.prepare(x.owner) else { fatalError("positive first-claim setup") }
    check("ticket records actual role", t.sourceRole == (sourceFirst ? .signaler : .carrier))
    var losingGeometryQueries = 0
    guard let p = x.core.packets[x.packet] else { fatalError("packet setup") }
    let loser = x.core.prepare(packetID: x.packet, expectedRevision: p.revision, source: sourceFirst ? x.owner : x.signaler, authorizedSignaler: sourceFirst ? nil : x.signaler, connectionID: 1, telegraphDuration: 0, live: x.live, destinationValid: { losingGeometryQueries += 1; return true })
    check("first valid pending claim wins", loser == nil && x.core.remaining(t) == 1 && losingGeometryQueries == 0)
    _ = x.core.advance(t, dt: 100, held: true)
    check("game hold freezes source warning", x.core.remaining(t) == 1)
    _ = x.core.advance(t, dt: 0.999, held: false)
    check("no early source commit", x.core.commit(t, held: false, live: x.live, authorizedSignaler: x.signaler, destinationValid: { true }) == nil)
    _ = x.core.advance(t, dt: 0.01, held: false)
    check("held ready command cannot commit", x.core.commit(t, held: true, live: x.live, authorizedSignaler: x.signaler, destinationValid: { true }) == nil)
    if sourceFirst {
        check("source authorization rechecked at commit", x.core.commit(t, held: false, live: x.live, destinationValid: { true }) == nil)
        check("changed authorization rejected", x.core.commit(t, held: false, live: x.live, authorizedSignaler: UUID(), destinationValid: { true }) == nil)
        check("source liveness rechecked at commit", x.core.commit(t, held: false, live: [x.owner,x.first,x.second], authorizedSignaler: x.signaler, destinationValid: { true }) == nil)
    }
    check("destination rechecked at commit", x.core.commit(t, held: false, live: x.live, authorizedSignaler: x.signaler, destinationValid: { false }) == nil)
    let nav = x.core.commit(t, held: false, live: x.live, authorizedSignaler: x.signaler, destinationValid: { true })
    check("live authorized source commits members once", nav?.members == Set([x.owner,x.first,x.second]))
    check("source never becomes escort or owner", x.core.membershipTicket(for: x.signaler) == nil && x.core.packets[x.packet]?.owner == x.owner)
    check("commit cannot repeat", x.core.commit(t, held: false, live: x.live, authorizedSignaler: x.signaler, destinationValid: { true }) == nil)
    check("active navigation cannot be preempted", x.prepare(sourceFirst ? x.owner : x.signaler, authorized: x.signaler) == nil && x.core.navigation(t) == nav)
    check("source cancel releases intent only", x.core.cancel(t) && x.core.packets[x.packet]?.members == Set([x.owner,x.first,x.second]))
    check("source cancellation exact once", !x.core.cancel(t) && x.core.navigation(t) == nil)
    guard let next = x.signal() else { fatalError("new claim after cancellation") }
    check("new valid claim after cancellation", next != t && next.sourceRole == .signaler)
    check("stale command cannot cancel replacement", !x.core.cancel(t) && !x.core.advance(t, dt: 10, held: false) && x.core.remaining(next) == 1)
}
for committed in [false,true] {
    let x = Fixture()
    guard let t = x.signal(), let member = x.core.membershipTicket(for: x.first) else { fatalError("member loss setup") }
    if committed { _ = x.core.advance(t,dt:1,held:false); _ = x.core.commit(t,held:false,live:x.live,authorizedSignaler:x.signaler,destinationValid:{true}) }
    _ = x.core.remove(member)
    check("member loss preserves carrier ownership", x.core.packets[x.packet]?.owner == x.owner && x.core.packets[x.packet]?.members == Set([x.owner,x.second]))
    check("member removal callback is idempotent", x.core.remove(member).isEmpty)
    if committed { check("committed signal keeps only living members", x.core.navigation(t)?.members == Set([x.owner,x.second])) }
    else { check("member loss cancels pending signal", x.core.remaining(t) == nil && x.core.navigation(t) == nil) }
}
let ownerLoss = Fixture()
guard let old = ownerLoss.signal(), let membership = ownerLoss.core.membershipTicket(for: ownerLoss.owner) else { fatalError("owner loss setup") }
check("owner death releases only surviving escorts", ownerLoss.core.remove(membership) == Set([ownerLoss.first,ownerLoss.second]))
check("owner loss cancels signal and removes packet", ownerLoss.core.remaining(old) == nil && ownerLoss.core.packets.isEmpty)
check("old source cannot resurrect removed owner", ownerLoss.core.commit(old,held:false,live:ownerLoss.live,authorizedSignaler:ownerLoss.signaler,destinationValid:{true}) == nil)
let epoch = Fixture()
guard let oldEpoch = epoch.signal(), let oldMember = epoch.core.membershipTicket(for: epoch.owner) else { fatalError("epoch setup") }
epoch.core.reset();check("new epoch setup with deliberately reused IDs", epoch.core.register(id:epoch.packet,owner:epoch.owner,escorts:[epoch.first,epoch.second]))
guard let replacement = epoch.signal() else { fatalError("replacement setup") }
check("old run cannot alter replacement", !epoch.core.cancel(oldEpoch) && !epoch.core.advance(oldEpoch,dt:10,held:false) && epoch.core.commit(oldEpoch,held:false,live:epoch.live,authorizedSignaler:epoch.signaler,destinationValid:{true}) == nil && epoch.core.remaining(replacement) == 1)
check("old membership cannot remove reused source packet", epoch.core.remove(oldMember).isEmpty && epoch.core.packets.count == 1)
let forged = Arena8PacketCommands.Ticket(generation:replacement.generation,packetID:replacement.packetID,packetRevision:replacement.packetRevision,commandID:replacement.commandID,source:replacement.source,sourceRole:.carrier,connectionID:replacement.connectionID)
check("forged source role cannot acquire or cancel", !epoch.core.cancel(forged) && epoch.core.remaining(replacement) == 1)
print("RESULT \(passed) passed \(failed) failed")
exit(failed == 0 ? 0 : 1)
