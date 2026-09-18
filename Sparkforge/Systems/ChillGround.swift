// ChillGround.swift
// Sparkforge
//
// v2.1 Abilities A2 (Chill): the ground Glacial Drift freezes — pure data on
// game time, proven by tools/chill-harness; GameScene owns one and draws it.
//
// CL-11 (Brandon, Sep 17): T1–T3 durations are PER TRAIL SEGMENT, measured
// from creation; T4's permanent coverage lasts for the current arena with
// overlapping ground MERGED; T5 replaces the trails with the arena-wide rink.
//
// Segments live in a bucket grid so "is this enemy on chilled ground?" is a
// 3×3 bucket lookup, not a scan of every segment — a permanent battlefield
// holds hundreds. Merging bounds it: a new segment that lands on top of an
// existing one refreshes/upgrades that one instead of stacking another.

import CoreGraphics
import Foundation

struct ChillGround {

    struct Segment {
        let id: Int
        let position: CGPoint
        var radius: CGFloat
        /// Game-clock time this segment melts; nil = permanent (T4).
        var expiry: TimeInterval?
    }

    enum DropResult: Equatable {
        /// A new segment (draw it).
        case created(id: Int)
        /// Landed on an existing segment: refreshed / grown / made permanent.
        case merged(id: Int)
    }

    /// Bucket edge — at least the largest segment radius, so a point's
    /// neighbours are always within the 3×3 block around its bucket.
    private let bucketSize: CGFloat
    /// A drop within this fraction of an existing segment's radius merges.
    private let mergeFraction: CGFloat
    private var buckets: [Int: [Segment]] = [:]
    private var nextID = 0
    private(set) var count = 0
    /// T5: the whole arena is chilled ground; segments are gone.
    private(set) var isRink = false

    init(bucketSize: CGFloat, mergeFraction: CGFloat) {
        self.bucketSize = max(1, bucketSize)
        self.mergeFraction = mergeFraction
    }

    private func key(_ p: CGPoint) -> (Int, Int) {
        (Int((p.x / bucketSize).rounded(.down)), Int((p.y / bucketSize).rounded(.down)))
    }
    private func hash(_ x: Int, _ y: Int) -> Int { x &* 73_856_093 ^ y &* 19_349_663 }
    /// (Self-contained so the host harness needs no VectorMath.)
    private static func gap(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    /// Freeze the ground at `p`. `lifetime` nil = permanent. Does nothing once
    /// the rink is up.
    @discardableResult
    mutating func drop(at p: CGPoint, radius: CGFloat, now: TimeInterval, lifetime: TimeInterval?) -> DropResult? {
        guard !isRink else { return nil }
        let (kx, ky) = key(p)
        for dx in -1...1 {
            for dy in -1...1 {
                let h = hash(kx + dx, ky + dy)
                guard let list = buckets[h] else { continue }
                for i in list.indices where Self.gap(list[i].position, p) < list[i].radius * mergeFraction {
                    var seg = list[i]
                    seg.radius = max(seg.radius, radius)
                    if let life = lifetime {
                        if let old = seg.expiry { seg.expiry = max(old, now + life) }   // permanent stays permanent
                    } else {
                        seg.expiry = nil
                    }
                    buckets[h]?[i] = seg
                    return .merged(id: seg.id)
                }
            }
        }
        let seg = Segment(id: nextID, position: p, radius: radius, expiry: lifetime.map { now + $0 })
        nextID += 1
        buckets[hash(kx, ky), default: []].append(seg)
        count += 1
        return .created(id: seg.id)
    }

    /// Melt everything whose time is up. Returns the melted segment ids.
    mutating func prune(now: TimeInterval) -> [Int] {
        var melted: [Int] = []
        for (h, list) in buckets {
            let keep = list.filter { seg in
                if let e = seg.expiry, e <= now { melted.append(seg.id); return false }
                return true
            }
            if keep.count != list.count { buckets[h] = keep.isEmpty ? nil : keep }
        }
        count -= melted.count
        return melted
    }

    func isChilled(_ p: CGPoint) -> Bool {
        if isRink { return true }
        guard count > 0 else { return false }
        let (kx, ky) = key(p)
        for dx in -1...1 {
            for dy in -1...1 {
                guard let list = buckets[hash(kx + dx, ky + dy)] else { continue }
                for seg in list where Self.gap(seg.position, p) < seg.radius { return true }
            }
        }
        return false
    }

    /// T5 Ice Rink: the trails are replaced by the arena. Returns every
    /// segment id so the scene can clear their visuals.
    mutating func becomeRink() -> [Int] {
        let ids = buckets.values.flatMap { $0.map(\.id) }
        buckets.removeAll()
        count = 0
        isRink = true
        return ids
    }

    /// New arena (Boss Mode swap) or new run: the ground thaws. The rink is a
    /// property of the build, so `keepRink` carries it to the next arena.
    mutating func clear(keepRink: Bool) -> [Int] {
        let ids = buckets.values.flatMap { $0.map(\.id) }
        buckets.removeAll()
        count = 0
        if !keepRink { isRink = false }
        return ids
    }
}
