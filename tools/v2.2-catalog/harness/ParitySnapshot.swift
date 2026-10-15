// ParitySnapshot.swift — v2.2 catalog migration (J1). Test support only;
// compiled by tools/catalog-harness/run.sh, never part of the app target.
//
// A deterministic, complete snapshot of a `PlayerStats` (or any value built
// from the same kinds of parts), as a flat map of field path → canonical text:
//
//     "maxHP"                    → "int:100"
//     "bloodBarrier.amount"      → "int:0"
//     "fireRateMultiplier"       → "num:0.5"
//
// Rules (J1 parity requirement: deterministic, covers nested state, fails
// explicitly on anything unsupported):
//   • Every stored property is visited, nested value types included. Nothing
//     is skipped: a value this file has no rule for THROWS, naming its path
//     and type. There is no fallback to `String(describing:)`.
//   • Leaves are written by an explicit rule per type. Floating-point values
//     use Swift's shortest round-trip text, so two values print alike only if
//     they are the same Double; non-finite values are written by name.
//   • Sets and dictionaries are written in sorted order.

import CoreGraphics
import Foundation

enum ParitySnapshot {

    struct Unsupported: Error, CustomStringConvertible {
        let path: String
        let type: String
        var description: String { "unsupported value at `\(path)`: \(type)" }
    }

    typealias Fields = [String: String]

    /// The whole value, flattened. Throws on the first unsupported part.
    static func take(_ value: Any) throws -> Fields {
        var out: Fields = [:]
        try walk(value, path: "", into: &out, isRoot: true)
        return out
    }

    /// Fields that differ between two snapshots: path → [before, after]. A
    /// field present on one side only is written with "<absent>" on the other.
    static func diff(_ before: Fields, _ after: Fields) -> [String: [String]] {
        var out: [String: [String]] = [:]
        for key in Set(before.keys).union(after.keys) {
            let b = before[key] ?? "<absent>", a = after[key] ?? "<absent>"
            if a != b { out[key] = [b, a] }
        }
        return out
    }

    // MARK: - Leaves

    private static func number(_ d: Double) -> String {
        if d.isNaN { return "num:nan" }
        if d.isInfinite { return d < 0 ? "num:-inf" : "num:inf" }
        // -0.0 and 0.0 are different bit patterns that compare equal; keep them apart.
        if d == 0 { return d.sign == .minus ? "num:-0.0" : "num:0.0" }
        return "num:\(d)"       // Swift prints the shortest text that round-trips
    }

    private static func leaf(_ value: Any) -> String? {
        switch value {
        case let v as Bool:    return v ? "bool:true" : "bool:false"
        case let v as Int:     return "int:\(v)"
        case let v as UInt64:  return "uint:\(v)"
        case let v as CGFloat: return number(Double(v))
        case let v as Double:  return number(v)
        case let v as Float:   return number(Double(v))
        case let v as String:  return "str:" + v
        default:               return nil
        }
    }

    // MARK: - Walk

    private static func join(_ path: String, _ part: String) -> String {
        path.isEmpty ? part : path + "." + part
    }

    private static func walk(_ value: Any, path: String, into out: inout Fields, isRoot: Bool = false) throws {
        if let text = leaf(value) { out[path] = text; return }

        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {

        case .optional:
            if let child = mirror.children.first { try walk(child.value, path: path, into: &out) }
            else { out[path] = "nil" }

        case .struct:
            guard !mirror.children.isEmpty else { out[path] = "struct:empty"; return }
            for child in mirror.children {
                guard let label = child.label else { throw Unsupported(path: path, type: "unlabelled member of \(type(of: value))") }
                try walk(child.value, path: join(path, label), into: &out)
            }

        case .class:
            // Only the value being snapshotted may be a class: a nested object
            // could be shared or cyclic, and there is no rule for that.
            guard isRoot else { throw Unsupported(path: path, type: "nested object \(type(of: value))") }
            guard mirror.superclassMirror == nil else { throw Unsupported(path: path, type: "\(type(of: value)) has a superclass") }
            for child in mirror.children {
                guard let label = child.label else { throw Unsupported(path: path, type: "unlabelled member of \(type(of: value))") }
                try walk(child.value, path: join(path, label), into: &out)
            }

        case .tuple:
            for (i, child) in mirror.children.enumerated() {
                try walk(child.value, path: join(path, child.label ?? "\(i)"), into: &out)
            }

        case .collection:
            out[join(path, "count")] = "int:\(mirror.children.count)"
            for (i, child) in mirror.children.enumerated() {
                try walk(child.value, path: "\(path)[\(i)]", into: &out)
            }

        case .set:
            var items: [String] = []
            for child in mirror.children {
                guard let text = leaf(child.value) ?? rawValueText(child.value) else {
                    throw Unsupported(path: path, type: "set element \(type(of: child.value))")
                }
                items.append(text)
            }
            out[path] = "set:[" + items.sorted().joined(separator: ",") + "]"

        case .dictionary:
            var entries: [(String, Any)] = []
            for child in mirror.children {
                let pair = Mirror(reflecting: child.value).children.map { $0.value }
                guard pair.count == 2, let key = leaf(pair[0]) ?? rawValueText(pair[0]) else {
                    throw Unsupported(path: path, type: "dictionary key in \(type(of: value))")
                }
                entries.append((key, pair[1]))
            }
            out[join(path, "count")] = "int:\(entries.count)"
            for (key, element) in entries.sorted(by: { $0.0 < $1.0 }) {
                try walk(element, path: "\(path)[\(key)]", into: &out)
            }

        case .enum:
            // An enum is written through its raw value only. One with payloads,
            // or without a raw value, has no rule here.
            guard let text = rawValueText(value) else { throw Unsupported(path: path, type: "enum \(type(of: value)) without a raw value") }
            out[path] = text

        default:
            // Closures, metatypes, opaque and foreign values.
            throw Unsupported(path: path, type: "\(type(of: value))")
        }
    }

    /// `enum:<raw>` for a String- or Int-backed enum; nil for anything else.
    private static func rawValueText(_ value: Any) -> String? {
        if let v = value as? any RawRepresentable {
            if let s = v.rawValue as? String { return "enum:" + s }
            if let i = v.rawValue as? Int { return "enum:\(i)" }
        }
        return nil
    }
}

// MARK: - Canonical JSON

enum ParityJSON {
    /// Sorted keys, stable formatting: the same object always writes the same bytes.
    /// `compact` drops the indentation (the run transcripts are large).
    static func data(_ object: Any, compact: Bool = false) throws -> Data {
        let style: JSONSerialization.WritingOptions = compact ? [] : [.prettyPrinted]
        return try JSONSerialization.data(withJSONObject: object, options: style.union([.sortedKeys, .withoutEscapingSlashes]))
    }
}
