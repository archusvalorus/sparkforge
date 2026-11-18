// Runtime clock and captured-contact geometry, derived from accepted P1.
// No SpriteKit, delayed actions, rewards or DEBUG-only prototype dependency.
import Foundation
import CoreGraphics

struct RainbowSweep {
    typealias C = GameConfig.RainbowRuntime
    nonisolated enum Hold: Hashable { case pause, levelUp, placement, reveal, background, death }
    struct Attacker {
        var ordinaryBasis: CGFloat
        var critChance: CGFloat
        var critMultiplier: CGFloat
        var luckyBreak: Bool
        var longShotT4: Bool
        var forgeBaseBonus: CGFloat = 0
        var headsmanBonus: CGFloat = 0
        var openingBonus: CGFloat = 0
        var opportunistBonus: CGFloat = 0
        var relentlessID: String? = nil
        var relentlessBonus: CGFloat = 0
        var executionThreshold: CGFloat = 0
        var executionMultiplier: CGFloat = 1
        var protocolThreshold: CGFloat = 0
        var protocolMultiplier: CGFloat = 1
        var permafrostBonus: CGFloat = 0
        var brittleCold = false
        var brittleColdFactor: CGFloat = 1
        var openWoundsBonus: CGFloat = 0
    }
    struct Target {
        let id: String
        let previous: CGPoint
        let position: CGPoint
        let radius: CGFloat
    }
    struct Sweep {
        let cycle: Int
        let footprint: CGRect
        let origin: CGPoint
        let attacker: Attacker
        var age: TimeInterval = 0
        var frontX: CGFloat { footprint.minX + footprint.width * CGFloat(min(1,age/C.crossing)) }
    }
    struct Contact {
        let id: String
        let position: CGPoint
        let cycle: Int
        let generation: Int
        let origin: CGPoint
        let attacker: Attacker
    }
    private(set) var owned = false
    private(set) var holds: Set<Hold> = []
    private(set) var elapsed: TimeInterval = 0
    private(set) var sweep: Sweep?
    private(set) var launches = 0
    private(set) var generation = 0
    private var hitIDs: Set<String> = []
    var remaining: TimeInterval { max(0,C.cadence-elapsed) }
    var warning: Bool { owned && remaining<=C.warning }
    mutating func select() { guard !owned else {return};owned=true;elapsed=0;cancelSweep() }
    mutating func setHold(_ hold:Hold,_ enabled:Bool) { if enabled {holds.insert(hold)} else {holds.remove(hold)} }
    mutating func cancelSweep() { generation += 1;sweep=nil;hitIDs.removeAll() }
    mutating func boardHandoff() { cancelSweep();elapsed=0 }
    mutating func newRun() { let next=generation+1;self=RainbowSweep();generation=next }
    func accepts(_ contact:Contact)->Bool { owned && contact.generation==generation && contact.cycle==launches && !hitIDs.contains(contact.id) }
    mutating func recordHit(_ contact:Contact) { guard accepts(contact) else{return};hitIDs.insert(contact.id) }
    static func laneFootprint(viewport:CGRect,origin:CGPoint,board:CGRect)->CGRect {
        let visible=viewport.intersection(board)
        guard !visible.isNull && !visible.isEmpty else{return .null}
        let h=visible.height*C.laneHeightFraction
        return CGRect(x:visible.minX,y:origin.y-h/2,width:visible.width,height:h).intersection(visible)
    }
    mutating func advance(_ raw:TimeInterval,fromViewport:CGRect,toViewport:CGRect,
                          fromOrigin:CGPoint,toOrigin:CGPoint,board:CGRect,
                          attacker:Attacker,targets:[Target],geometry:ArenaGeometry)->[Contact] {
        guard owned,holds.isEmpty,raw.isFinite else{return []}
        let dt=min(max(0,raw),C.maximumActiveStep)
        guard dt>0 else{return []}
        let before=elapsed;elapsed += dt
        var startFraction:CGFloat=0,sweepDT=dt
        if elapsed>=C.cadence {
            let delay=max(0,C.cadence-before),t=CGFloat(min(1,delay/dt))
            let view=CGRect(x:fromViewport.minX+(toViewport.minX-fromViewport.minX)*t,
                            y:fromViewport.minY+(toViewport.minY-fromViewport.minY)*t,
                            width:fromViewport.width+(toViewport.width-fromViewport.width)*t,
                            height:fromViewport.height+(toViewport.height-fromViewport.height)*t)
            elapsed -= C.cadence;launches += 1;hitIDs.removeAll()
            let origin=fromOrigin.lerp(to:toOrigin,t:t)
            let area=Self.laneFootprint(viewport:view,origin:origin,board:board)
            sweep = area.isNull || area.isEmpty ? nil : Sweep(cycle:launches,footprint:area,origin:origin,attacker:attacker)
            startFraction=t;sweepDT=dt-delay
        }
        guard var current=sweep else{return []}
        let actual=min(max(0,sweepDT),C.crossing-current.age)
        let endFraction:CGFloat=sweepDT>0 ? startFraction+(1-startFraction)*CGFloat(actual/sweepDT):startFraction
        let fromX=current.frontX;current.age += actual;let toX=current.frontX
        var candidates:[(Target,CGFloat,CGPoint)]=[]
        var seen:Set<String>=[]
        for target in targets where !hitIDs.contains(target.id) && seen.insert(target.id).inserted {
            let a=target.previous.lerp(to:target.position,t:startFraction)
            let b=target.previous.lerp(to:target.position,t:endFraction)
            let ra=a-CGPoint(x:fromX,y:current.footprint.midY),rb=b-CGPoint(x:toX,y:current.footprint.midY)
            guard let entry=Self.firstContact(ra,rb,halfHeight:current.footprint.height/2,radius:target.radius),
                  let reverse=Self.firstContact(rb,ra,halfHeight:current.footprint.height/2,radius:target.radius) else{continue}
            let exit=1-reverse
            guard let t=current.attacker.longShotT4 ? entry : Self.firstVisibleContact(entry:entry,exit:exit,from:a,to:b,origin:current.origin,geometry:geometry) else{continue}
            candidates.append((target,t,a.lerp(to:b,t:t)))
        }
        candidates.sort{$0.1 == $1.1 ? $0.0.id < $1.0.id : $0.1 < $1.1}
        let contacts=candidates.map{Contact(id:$0.0.id,position:$0.2,cycle:current.cycle,generation:generation,origin:current.origin,attacker:current.attacker)}
        sweep=current.age>=C.crossing ? nil:current
        return contacts
    }
    /// Continuous target-circle vs moving vertical segment, in relative space.
    /// Find the earliest intersecting prefix, not just endpoint overlap. The
    /// leading contact line always lies inside the captured Spark-aimed lane.
    private static func firstContact(_ a: CGPoint, _ b: CGPoint,
                                      halfHeight: CGFloat, radius: CGFloat) -> CGFloat? {
        func crosses(_ end: CGPoint) -> Bool {
            MeleeSector.segmentCrossesRoundedBox(a, end, center: .zero,
                                                 halfExtents: CGSize(width: 0, height: halfHeight),
                                                 cornerRadius: 0, rotation: 0, margin: max(0, radius))
        }
        guard crosses(b) else { return nil }
        if crosses(a) { return 0 }
        var low: CGFloat = 0, high: CGFloat = 1
        for _ in 0..<C.contactSearchSteps {
            let mid = (low + high) / 2
            if crosses(a.lerp(to: b, t: mid)) { high = mid } else { low = mid }
        }
        return high
    }

    /// Each authored footprint is convex, so its shadow from a fixed origin
    /// intersects a straight target trajectory in one interval. Walk past the
    /// shadows currently covering contact, rather than sampling a doorway or
    /// rejecting the whole frame at an occluded first body touch. A shadow
    /// already exited cannot re-enter along this segment; iterations are thus
    /// bounded by footprint count, not an arbitrary gameplay/substep cap.
    private static func firstVisibleContact(entry: CGFloat, exit: CGFloat,
                                            from a: CGPoint, to b: CGPoint, origin: CGPoint,
                                            geometry: ArenaGeometry) -> CGFloat? {
        var candidate = entry
        for _ in 0...geometry.blockedFootprints.count {
            var next = candidate
            var blocked = false
            for footprint in geometry.blockedFootprints {
                func occluded(_ t: CGFloat) -> Bool {
                    MeleeSector.segmentCrossesRoundedBox(origin, a.lerp(to: b, t: t),
                        center: footprint.center, halfExtents: footprint.halfExtents,
                        cornerRadius: footprint.cornerRadius, rotation: footprint.rotation, margin: 0)
                }
                guard occluded(candidate) else { continue }
                blocked = true
                if occluded(exit) { return nil }
                var low = candidate, high = exit
                for _ in 0..<C.contactSearchSteps {
                    let mid = (low + high) / 2
                    if occluded(mid) { low = mid } else { high = mid }
                }
                next = max(next, high)
            }
            if !blocked { return candidate }
            guard next > candidate, next <= exit else { return nil }
            candidate = next
        }
        return nil
    }
}

/// Ordinary runs use the approved earned-offer policy. Isolated diagnostics
/// still require their explicit flag and never activate the traversal fixture.
enum RainbowRuntimeGate {
    static let enabled: Bool = {
        if !GameRunPreferences.isIsolated { return true }
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--rainbow-runtime")
            && !ProcessInfo.processInfo.arguments.contains("--arena9-traversal")
        #else
        return false
        #endif
    }()
}
