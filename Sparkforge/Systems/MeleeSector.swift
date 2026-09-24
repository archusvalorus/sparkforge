// MeleeSector.swift
// Sparkforge
//
// v2.1 Abilities A4c (CL-41): does a circular body overlap a melee sweep?
//
// The sweep is a circular SECTOR: apex at Spark, a reach, and a half-angle
// either side of the facing direction (Red Smile: 80pt, 110° total). The test
// is exact circle–sector overlap, so reach is measured against the target's
// occupied body rather than its centre, and a wide body (the Unmade Star)
// counts the moment any of it genuinely falls inside the swing. There are no
// per-boss special cases and no global angle padding — a body is hit only
// when its footprint overlaps the sector.
//
// Pure, CoreGraphics only; proven by tools/redsmile-harness.

import CoreGraphics

enum MeleeSector {
    /// True when the circle (`center`, `radius`) overlaps the sector with apex
    /// `origin`, axis `facing` (need not be normalized; zero falls back to
    /// straight up), half-angle `halfAngle` (radians, ≤ π) and radius `reach`.
    static func overlaps(origin: CGPoint, facing: CGPoint, halfAngle: CGFloat, reach: CGFloat,
                         center: CGPoint, radius: CGFloat) -> Bool {
        let r = max(0, radius)
        let vx = center.x - origin.x
        let vy = center.y - origin.y
        let d = (vx * vx + vy * vy).squareRoot()

        // The body swallows the apex: overlapping by definition.
        if d <= r { return true }
        // Every point of the body is beyond reach.
        if d - r > reach { return false }

        let axis = unit(facing)
        // Centre direction inside the wedge (and near surface within reach):
        // the body's nearest point to the apex lies inside the sector.
        let cosTheta = max(-1, min(1, (vx * axis.x + vy * axis.y) / d))
        if acos(cosTheta) <= halfAngle { return true }

        // Centre outside the wedge: the nearest point of the sector is on one
        // of its two straight edges (apex → reach), so test those segments.
        let c = cos(halfAngle), s = sin(halfAngle)
        let left = CGPoint(x: axis.x * c - axis.y * s, y: axis.x * s + axis.y * c)
        let right = CGPoint(x: axis.x * c + axis.y * s, y: -axis.x * s + axis.y * c)
        for edge in [left, right] {
            let end = CGPoint(x: origin.x + edge.x * reach, y: origin.y + edge.y * reach)
            if distance(from: center, toSegment: origin, end) <= r { return true }
        }
        return false
    }

    /// CL-38: does the segment a→b pass within `margin` of a rounded box
    /// (`center`, `halfExtents`, `cornerRadius`, `rotation` — the arena
    /// geometry's footprint shape)? EXACT: the distance between the segment
    /// and the box's core rectangle, against corner radius + margin — the same
    /// boundary `Footprint.contains` uses.
    ///
    /// Why not `ArenaGeometry.segmentBlocked`: that marches at a step as long
    /// as the footprint's half-thickness (tunneling-safe for per-frame motion),
    /// so on any segment SHORTER than that it only tests the two endpoints —
    /// and a sweep's endpoints are always outside the Carrier. An 80pt sweep
    /// past a rounded end would never be blocked.
    static func segmentCrossesRoundedBox(_ a: CGPoint, _ b: CGPoint, center: CGPoint,
                                         halfExtents: CGSize, cornerRadius: CGFloat,
                                         rotation: CGFloat, margin: CGFloat) -> Bool {
        // Into the box's own frame (undo its rotation).
        let c = cos(-rotation), s = sin(-rotation)
        func local(_ p: CGPoint) -> CGPoint {
            let x = p.x - center.x, y = p.y - center.y
            return CGPoint(x: x * c - y * s, y: x * s + y * c)
        }
        let p = local(a), q = local(b)
        let w = halfExtents.width, h = halfExtents.height
        if segmentIntersectsRect(p, q, halfWidth: w, halfHeight: h) { return true }
        // Disjoint: the closest pair involves a segment endpoint or a corner.
        func toRect(_ v: CGPoint) -> CGFloat {
            let dx = max(abs(v.x) - w, 0), dy = max(abs(v.y) - h, 0)
            return (dx * dx + dy * dy).squareRoot()
        }
        var gap = min(toRect(p), toRect(q))
        for corner in [CGPoint(x: w, y: h), CGPoint(x: w, y: -h), CGPoint(x: -w, y: h), CGPoint(x: -w, y: -h)] {
            gap = min(gap, distance(from: corner, toSegment: p, q))
        }
        return gap < cornerRadius + margin
    }

    /// Liang–Barsky: does segment p→q touch the rectangle [−w, w] × [−h, h]?
    private static func segmentIntersectsRect(_ p: CGPoint, _ q: CGPoint,
                                              halfWidth w: CGFloat, halfHeight h: CGFloat) -> Bool {
        var t0: CGFloat = 0, t1: CGFloat = 1
        let dx = q.x - p.x, dy = q.y - p.y
        for (pk, qk) in [(-dx, p.x + w), (dx, w - p.x), (-dy, p.y + h), (dy, h - p.y)] {
            if pk == 0 {
                if qk < 0 { return false }           // parallel and outside this edge
            } else {
                let r = qk / pk
                if pk < 0 {
                    if r > t1 { return false }
                    t0 = max(t0, r)
                } else {
                    if r < t0 { return false }
                    t1 = min(t1, r)
                }
            }
        }
        return true
    }

    /// Unit vector for `v`; straight up for a zero vector.
    static func unit(_ v: CGPoint) -> CGPoint {
        let len = (v.x * v.x + v.y * v.y).squareRoot()
        guard len > 1e-9 else { return CGPoint(x: 0, y: 1) }
        return CGPoint(x: v.x / len, y: v.y / len)
    }

    private static func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let abx = b.x - a.x, aby = b.y - a.y
        let len2 = abx * abx + aby * aby
        var t: CGFloat = 0
        if len2 > 0 {
            t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2
            t = max(0, min(1, t))
        }
        let qx = a.x + abx * t - p.x, qy = a.y + aby * t - p.y
        return (qx * qx + qy * qy).squareRoot()
    }
}
