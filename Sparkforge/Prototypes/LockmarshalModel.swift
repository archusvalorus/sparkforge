// Isolated first Lockmarshal unit. No registry, progression or group commands.
#if DEBUG
import Foundation
import CoreGraphics

extension GameConfig {
    /// Provisional readable fixture tuning; not final encounter balance.
    enum LockmarshalFixture {
        static let bodyRadius: CGFloat = 26
        static let health = 180
        static let damage = 18
        static let pursuitSpeed: CGFloat = 70
        static let advanceSpeed: CGFloat = 360
        static let advanceDistance: CGFloat = 220
        static let pursuitDuration: TimeInterval = 2.4
        static let warningDuration: TimeInterval = 1.0
        static let recoveryDuration: TimeInterval = 1.1
        static let stampHalfSide: CGFloat = 82
        static let maximumStep: TimeInterval = 0.1
        static let stampImpactFlash: TimeInterval = 0.15
    }
}

struct LockmarshalModel {
    typealias C = GameConfig.LockmarshalFixture
    enum Phase: String { case pursuit, thresholdWarning, advance, stampWarning, recovery, cancelled }
    enum Verb { case threshold, stamp }
    struct Frame { var damage = false; var committed = false }
    private(set) var phase: Phase = .pursuit
    private(set) var remaining: TimeInterval = C.pursuitDuration
    private(set) var position: CGPoint
    private(set) var start: CGPoint
    private(set) var goal: CGPoint
    private(set) var stamp: [CGPoint] = []
    private(set) var nextVerb: Verb = .threshold
    private(set) var advanceHit = false
    private(set) var stampFlash: TimeInterval = 0
    private var lastPlayer: CGPoint?
    let map: Arena8GameMap
    init(map: Arena8GameMap, position: CGPoint) {
        self.map = map; self.position = position; start = position; goal = position
    }
    mutating func interrupt(){phase = .pursuit;remaining = C.pursuitDuration;stamp = [];stampFlash = 0;lastPlayer = nil}
    mutating func cancel() { phase = .cancelled; remaining = 0; stamp = []; stampFlash = 0; lastPlayer = nil }
    // Explicit scene-driven active delta only. No SKAction or wall-clock callback.
    mutating func update(_ raw: TimeInterval, player: CGPoint, playerRadius: CGFloat, held: Bool = false) -> Frame {
        guard raw.isFinite, raw > 0, !held, phase != .cancelled,
              player.x.isFinite, player.y.isFinite, playerRadius.isFinite, playerRadius >= 0 else { return Frame() }
        let dt = min(raw, C.maximumStep)
        stampFlash = max(0, stampFlash-dt)
        let oldPlayer = lastPlayer ?? player
        defer { lastPlayer = player }
        var result = Frame()
        switch phase {
        case .pursuit:
            let fitted = map.approach(player, radius: C.bodyRadius) ?? position
            let blocked = map.geometry.segmentBlockedExact(position, fitted, travelRadius: C.bodyRadius)
            let waypoint = blocked ? (map.geometry.graphWaypoint(from: position, toward: fitted,
                travelRadius: C.bodyRadius, arriveRadius: GameConfig.Arena8Prototype.arrival)?.position ?? position) : fitted
            let delta = waypoint - position
            let travel = min(delta.length, C.pursuitSpeed * CGFloat(dt))
            position = Arena8KaijuLunge(map: map).step(from: position,
                toward: position + delta.normalized * travel, radius: C.bodyRadius)
            remaining = max(0, remaining - dt)
            if remaining <= 0 { prepare(player: player) }
        case .thresholdWarning, .stampWarning:
            remaining = max(0, remaining - dt)
            if remaining <= 0 {
                result.committed = true
                if phase == .thresholdWarning {
                    phase = .advance; advanceHit = false
                } else {
                    result.damage = Self.circle(player,radius:playerRadius,touches:stamp)
                    recover();stampFlash = C.stampImpactFlash
                }
            }
        case .advance:
            let before = position
            let delta = goal - before
            let travel = min(delta.length, C.advanceSpeed * CGFloat(dt))
            position = Arena8KaijuLunge(map: map).step(from: before,
                toward: before + delta.normalized * travel, radius: C.bodyRadius)
            // Relative movement captures a moving Spark as well as fast boss steps.
            if !advanceHit && Self.advanceContact(map:map,bossFrom:before,bossTo:position,
                playerFrom:oldPlayer,playerTo:player,playerRadius:playerRadius) {
                advanceHit = true; result.damage = true
            }
            if position.distance(to: goal) < 0.01 || position.distance(to: before) < 0.0001 { recover() }
        case .recovery:
            remaining = max(0, remaining - dt)
            if remaining <= 0 { phase = .pursuit; remaining = C.pursuitDuration; stamp = [] }
        case .cancelled: break
        }
        return result
    }
    private mutating func prepare(player: CGPoint) {
        start = position
        remaining = C.warningDuration
        if nextVerb == .threshold {
            let difference = player - position
            let direction = difference.length > 0 ? difference.normalized : CGPoint(x: 1, y: 0)
            goal = Arena8KaijuLunge(map: map).step(from: position,
                toward: position + direction * C.advanceDistance, radius: C.bodyRadius)
            phase = .thresholdWarning; nextVerb = .stamp; stamp = []
        } else {
            // Reuse the established root-visible ground boundary, then clip
            // to this attack's square. No Growth radius/cap is used.
            stamp = Self.stampPolygon(map:map,root:position)
            phase = .stampWarning; nextVerb = .threshold
        }
    }
    private mutating func recover() { phase = .recovery; remaining = C.recoveryDuration }
    /// Linear relative-motion sample, not reconstruction of every X/Y slide.
    /// Reject a closest interpolated player body that would lie in solid floor.
    static func advanceContact(map:Arena8GameMap,bossFrom:CGPoint,bossTo:CGPoint,
                               playerFrom:CGPoint,playerTo:CGPoint,playerRadius:CGFloat)->Bool {
        let a=bossFrom-playerFrom,b=bossTo-playerTo
        let relative=b-a,squared=relative.x*relative.x+relative.y*relative.y
        let t:CGFloat=squared>0 ? min(1,max(0,-(a.x*relative.x+a.y*relative.y)/squared)):0
        let playerAtContact=playerFrom+(playerTo-playerFrom)*t
        return segmentDistance(.zero,a,b)<=C.bodyRadius+playerRadius
            && map.valid(playerAtContact,radius:playerRadius)
    }
    static func rectangleVertices(_ r:CGRect)->[CGPoint] {
        [CGPoint(x:r.minX,y:r.minY),CGPoint(x:r.maxX,y:r.minY),
         CGPoint(x:r.maxX,y:r.maxY),CGPoint(x:r.minX,y:r.maxY)]
    }
    static func stampPolygon(map:Arena8GameMap,root:CGPoint)->[CGPoint] {
        guard let footprint=Arena8GardenFootprint(map:map,root:root,startingRadius:C.stampHalfSide) else{return []}
        let square=CGRect(x:root.x-C.stampHalfSide,y:root.y-C.stampHalfSide,
                          width:2*C.stampHalfSide,height:2*C.stampHalfSide)
        let visible=footprint.visibilityPolygon
        var polygon=visible
        // Four convex halfplanes containing the root preserve this star-shaped
        // visibility polygon as one connected footprint. Exact edge crossings,
        // not a ray-count approximation or a damage-only line-of-sight filter.
        for side in 0..<4 {
            let bound=[square.minX,square.maxX,square.minY,square.maxY][side]
            func coordinate(_ p:CGPoint)->CGFloat{side<2 ? p.x:p.y}
            func inside(_ p:CGPoint)->Bool{side%2==0 ? coordinate(p)>=bound:coordinate(p)<=bound}
            var clipped:[CGPoint]=[]
            guard var previous=polygon.last else{return []}
            for point in polygon {
                let a=inside(previous),b=inside(point)
                if a != b {
                    let denominator=coordinate(point)-coordinate(previous)
                    guard denominator != 0 else{return []}
                    let t=(bound-coordinate(previous))/denominator
                    var crossing=previous+(point-previous)*t
                    if side<2 {crossing.x=bound}else{crossing.y=bound}
                    clipped.append(crossing)
                }
                if b {clipped.append(point)}
                previous=point
            }
            polygon=clipped
        }
        return polygon.count>=3 && polygon.allSatisfy{$0.x.isFinite && $0.y.isFinite} ? polygon:[]
    }
    static func stampPath(_ polygon:[CGPoint])->CGPath {
        let p=CGMutablePath()
        if polygon.count>=3 {p.addLines(between:polygon);p.closeSubpath()}
        return p
    }
    static func circle(_ point:CGPoint,radius:CGFloat,touches polygon:[CGPoint])->Bool {
        guard polygon.count>=3,radius.isFinite,radius>=0,point.x.isFinite,point.y.isFinite else{return false}
        if stampPath(polygon).contains(point){return true}
        return polygon.indices.contains { segmentDistance(point,polygon[$0],polygon[($0+1)%polygon.count]) <= radius }
    }
    static func segmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let d = b-a, length = d.x*d.x+d.y*d.y
        guard length > 0 else { return p.distance(to: a) }
        let t = min(1, max(0, ((p.x-a.x)*d.x+(p.y-a.y)*d.y)/length))
        return p.distance(to: a+d*t)
    }
}
#endif
