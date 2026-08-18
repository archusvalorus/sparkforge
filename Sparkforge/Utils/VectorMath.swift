// VectorMath.swift
// Sparkforge
//
// CGPoint and CGVector math utilities for movement, direction, and distance.

import CoreGraphics

// MARK: - CGPoint Arithmetic

extension CGPoint {
    
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func * (point: CGPoint, scalar: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scalar, y: point.y * scalar)
    }
    
    static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs + rhs
    }
    
    /// Distance from this point to another
    func distance(to other: CGPoint) -> CGFloat {
        let dx = other.x - x
        let dy = other.y - y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Length (magnitude) of this point treated as a vector from origin
    var length: CGFloat {
        sqrt(x * x + y * y)
    }
    
    /// Normalized unit vector (returns .zero if length is ~0)
    var normalized: CGPoint {
        let len = length
        guard len > 0.0001 else { return .zero }
        return CGPoint(x: x / len, y: y / len)
    }

    // MARK: v2.1 (Geometry 1A) — primitives the arena geometry contract needs

    /// Dot product, treating both points as vectors from the origin.
    func dot(_ other: CGPoint) -> CGFloat { x * other.x + y * other.y }

    /// Rotate about the origin by `angle` radians (counter-clockwise).
    func rotated(by angle: CGFloat) -> CGPoint {
        let c = cos(angle), s = sin(angle)
        return CGPoint(x: x * c - y * s, y: x * s + y * c)
    }

    /// Linear interpolation toward `other` by `t` in 0...1.
    func lerp(to other: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(x: x + (other.x - x) * t, y: y + (other.y - y) * t)
    }
}

// MARK: - CGVector Convenience

extension CGVector {
    
    init(point: CGPoint) {
        self.init(dx: point.x, dy: point.y)
    }
    
    var length: CGFloat {
        sqrt(dx * dx + dy * dy)
    }
    
    var normalized: CGVector {
        let len = length
        guard len > 0.0001 else { return .zero }
        return CGVector(dx: dx / len, dy: dy / len)
    }
    
    static func * (vector: CGVector, scalar: CGFloat) -> CGVector {
        CGVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
    }
}
