// GeometryDebug.swift
// Sparkforge
//
// v2.1 (Geometry 1A) — the §10.5 debug visibility for arena geometry:
// blocked footprints, route nodes/edges, spawn zones, safe anchors, and live
// counters for resolves (by actor + cause) and placement rejections.
//
// House rules honored:
//   • an active seam ANNOUNCES ITSELF (the Panda seam-banner idiom) — the
//     overlay paints a banner in the run HUD whenever it is on;
//   • DEBUG-gated: the flag and the drawing compile out of Release; the
//     counters stay (cheap ints) so telemetry can read them later;
//   • no physics body exists to visualize, so this draws by hand.

import SpriteKit

final class GeometryDebug {
    enum Cause: String { case movement, pull, knockback, teleport, scripted, sampler }

    #if DEBUG
    /// DEV SEAM — draw the geometry overlay in the run. Reinstall the sim
    /// after switching it back off. Announced by the HUD banner while on.
    static let showOverlay: Bool = false
    /// DEV SEAM — run whatever arena is selected AS the Splitworks shell
    /// (geometry + palette, existing enemies). Proof-of-foundation lens; the
    /// shell is not in ArenaConfig.all so nothing unlocks or persists.
    static let forceSplitworksShell: Bool = false
    #endif

    // MARK: Counters (always compiled — cheap, telemetry-readable)

    private(set) var resolvesByActor: [String: Int] = [:]
    private(set) var resolvesByCause: [Cause: Int] = [:]

    // v2.1 (1B): route-guidance diagnostics — decisions, recoveries after
    // displacement, fallbacks (no node visible), direct-pursuit resumes.
    var routeDecisions = 0
    var routeRecoveries = 0
    var routeFallbacks = 0
    var routeDirectResumes = 0

    // v2.1 (Unit 2): travel/vision policy diagnostics.
    var projectileBlocksPlayer = 0
    var projectileBlocksEnemy = 0
    var losSuppressedTargets = 0
    var rangedHeldFire = 0

    // v2.1 (2b): Spurhound outcomes — lunges committed, and how they ended.
    var spurhoundLunges = 0
    var spurhoundHits = 0
    var spurhoundMisses = 0
    var spurhoundClangs = 0

    // v2.1 (2c): Linekeeper — anchors taken, shots fired, relocations.
    var linekeeperAnchors = 0
    var linekeeperShots = 0
    var linekeeperRelocates = 0

    // v2.1 (2d): Ramplate — braces, charges, shoves landed, wall/Carrier stops.
    var ramplateBraces = 0
    var ramplateShoves = 0
    var ramplateMisses = 0
    var ramplateWalls = 0

    // v2.1 (Unit 3): Marchwarden verbs — declared charges, standards landed,
    // musters answered, escalations.
    var wardenCharges = 0
    var wardenStandards = 0
    var wardenMusters = 0

    func recordResolve(actor: String, cause: Cause) {
        resolvesByActor[actor, default: 0] += 1
        resolvesByCause[cause, default: 0] += 1
    }

    var summary: String {
        let byCause = resolvesByCause.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: " ")
        let byActor = resolvesByActor.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
        return "resolves[\(byActor)] causes[\(byCause)] rejects=\(PlacementSampler.rejectionCount) "
             + "routes[decide=\(routeDecisions) recover=\(routeRecoveries) fallback=\(routeFallbacks) resume=\(routeDirectResumes)] "
             + "shots[blockP=\(projectileBlocksPlayer) blockE=\(projectileBlocksEnemy) losSkip=\(losSuppressedTargets) heldFire=\(rangedHeldFire)] "
             + "hound[lunge=\(spurhoundLunges) hit=\(spurhoundHits) miss=\(spurhoundMisses) clang=\(spurhoundClangs)] "
             + "keeper[anchor=\(linekeeperAnchors) shot=\(linekeeperShots) relocate=\(linekeeperRelocates)] "
             + "plate[brace=\(ramplateBraces) shove=\(ramplateShoves) miss=\(ramplateMisses) wall=\(ramplateWalls)] "
             + "warden[charge=\(wardenCharges) fall=\(wardenStandards) muster=\(wardenMusters)]"
    }

    // MARK: Overlay (DEBUG only)

    #if DEBUG
    /// Build the world-space overlay for `geometry`. Parent it to the world
    /// node ABOVE the floor and BELOW actors so it never hides a body.
    static func makeOverlay(for geometry: ArenaGeometry, arenaRadius: CGFloat) -> SKNode {
        let root = SKNode()
        root.name = "geometryDebugOverlay"
        root.zPosition = 2

        for f in geometry.blockedFootprints {
            let w = (f.halfExtents.width + f.cornerRadius) * 2
            let h = (f.halfExtents.height + f.cornerRadius) * 2
            let shape = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: f.cornerRadius)
            shape.fillColor = SKColor(hex: 0xFF3355, alpha: 0.18)
            shape.strokeColor = SKColor(hex: 0xFF3355, alpha: 0.9)
            shape.lineWidth = 2
            shape.position = f.center
            shape.zRotation = f.rotation
            root.addChild(shape)
            // Margin band: where a 16pt actor's centre may not stand.
            let m = SKShapeNode(rectOf: CGSize(width: w + 32, height: h + 32), cornerRadius: f.cornerRadius + 16)
            m.strokeColor = SKColor(hex: 0xFF3355, alpha: 0.35)
            m.lineWidth = 1
            m.glowWidth = 0
            m.position = f.center; m.zRotation = f.rotation
            root.addChild(m)
            let lbl = SKLabelNode(fontNamed: "Menlo-Bold")
            lbl.text = f.label; lbl.fontSize = 10; lbl.fontColor = SKColor(hex: 0xFF3355)
            lbl.position = f.center; lbl.verticalAlignmentMode = .center
            root.addChild(lbl)
        }

        for e in geometry.routeEdges {
            guard let a = geometry.routeNodes.first(where: { $0.id == e.from }),
                  let b = geometry.routeNodes.first(where: { $0.id == e.to }) else { continue }
            let path = CGMutablePath()
            path.move(to: a.position); path.addLine(to: b.position)
            let line = SKShapeNode(path: path)
            line.strokeColor = SKColor(hex: 0x3F8F8A, alpha: 0.7)
            line.lineWidth = 1.5
            root.addChild(line)
        }
        for n in geometry.routeNodes {
            let dot = SKShapeNode(circleOfRadius: 6)
            dot.fillColor = SKColor(hex: 0x3F8F8A); dot.strokeColor = .clear
            dot.position = n.position
            root.addChild(dot)
            let lbl = SKLabelNode(fontNamed: "Menlo")
            lbl.text = n.label; lbl.fontSize = 9; lbl.fontColor = SKColor(hex: 0x9FE0DB)
            lbl.position = n.position + CGPoint(x: 0, y: 10)
            root.addChild(lbl)
        }

        for z in geometry.spawnZones {
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: arenaRadius + 12,
                        startAngle: z.startAngle, endAngle: z.endAngle, clockwise: false)
            let arc = SKShapeNode(path: path)
            arc.strokeColor = SKColor(hex: 0xFFB84D, alpha: 0.9); arc.lineWidth = 4
            root.addChild(arc)
            let mid = (z.startAngle + z.endAngle) / 2
            let lbl = SKLabelNode(fontNamed: "Menlo")
            lbl.text = z.label; lbl.fontSize = 9; lbl.fontColor = SKColor(hex: 0xFFB84D)
            lbl.position = CGPoint(x: cos(mid), y: sin(mid)) * (arenaRadius + 28)
            root.addChild(lbl)
        }

        for a in geometry.safeAnchors {
            let ring = SKShapeNode(circleOfRadius: 10)
            ring.strokeColor = SKColor(hex: 0x8FE08F); ring.lineWidth = 2; ring.fillColor = .clear
            ring.position = a.position
            root.addChild(ring)
            let lbl = SKLabelNode(fontNamed: "Menlo")
            lbl.text = a.label; lbl.fontSize = 9; lbl.fontColor = SKColor(hex: 0x8FE08F)
            lbl.position = a.position + CGPoint(x: 0, y: -20)
            root.addChild(lbl)
        }
        return root
    }
    #endif
}

#if DEBUG
/// v2.1 — RUNTIME dev seams, set from the Settings panel's dev rows. Session
/// only (statics, never persisted); the run HUD announces whichever are
/// active. Built because a wiped save must still be able to reach any arena
/// for a device pass — WITHOUT the silent force-unlock that once masked a
/// prod bug. Progression, persistence, and the title card never see these.
enum DevSeams {
    /// nil = off. 0..<ArenaConfig.all.count = that arena; `shellIndex` = the
    /// Splitworks shell (geometry + palette, existing enemies).
    static var arenaOverrideIndex: Int? = nil
    static let shellIndex = ArenaConfig.all.count
    static var overlayEnabled = false

    static func cycleArena() {
        switch arenaOverrideIndex {
        case nil: arenaOverrideIndex = 0
        case let i? where i < shellIndex: arenaOverrideIndex = i + 1
        default: arenaOverrideIndex = nil
        }
    }

    static var anyActive: Bool { arenaOverrideIndex != nil || overlayEnabled || GeometryDebug.showOverlay || GeometryDebug.forceSplitworksShell }

    static var bannerText: String {
        var parts: [String] = []
        if let i = arenaOverrideIndex {
            parts.append(i == shellIndex ? "splitworks shell" : "arena \(i + 1)")
        } else if GeometryDebug.forceSplitworksShell { parts.append("splitworks shell (flag)") }
        if overlayEnabled || GeometryDebug.showOverlay { parts.append("geometry overlay") }
        return "⚠︎ DEV — " + parts.joined(separator: " · ")
    }
}
#endif
