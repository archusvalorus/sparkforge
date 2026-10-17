// A7-3: one committed special at a time. Requests are collected for the next
// active frame so enemy iteration order cannot choose the winner.
import Foundation

final class ChannelAttackSchedule {
    enum Role: Equatable { case tollkeeper, railspike, switchwarden }
    private(set) var owner: Role?
    private(set) var next: Role = .tollkeeper
    private(set) var gap: TimeInterval = 0
    private var tollRequested = false
    private var railRequested = false
    private var bossRequested = false
    private var grant: Role?
    private var finished = false
    private var liveBolts = 0

    func beginFrame(_ dt: TimeInterval, railBolts: Int, hostileBolts: Int = 0) {
        guard dt.isFinite, dt >= 0 else { return }
        liveBolts = max(0, railBolts)
        if finished && (owner != .railspike || liveBolts == 0) {
            next = owner == .tollkeeper ? .railspike : .tollkeeper
            owner = nil; finished = false; gap = 0.35
        } else { gap = max(0, gap - dt) }
        grant = nil
        if owner == nil && gap <= 0 {
            if bossRequested && hostileBolts == 0 { grant = .switchwarden }
            else if tollRequested && railRequested { grant = next }
            else if tollRequested { grant = .tollkeeper }
            else if railRequested { grant = .railspike }
        }
        tollRequested = false; railRequested = false; bossRequested = false
    }

    func request(_ role: Role) -> Bool {
        switch role { case .tollkeeper: tollRequested=true; case .railspike: railRequested=true; case .switchwarden: bossRequested=true }
        guard owner == nil, grant == role, gap <= 0 else { return false }
        owner = role; grant = nil; finished = false
        return true
    }

    func finish(_ role: Role) {
        if owner == role { finished = true }
    }

    func reset() {
        owner = nil; grant = nil; finished = false; liveBolts = 0
        tollRequested = false; railRequested = false; bossRequested = false; next = .tollkeeper; gap = 0
    }
}
