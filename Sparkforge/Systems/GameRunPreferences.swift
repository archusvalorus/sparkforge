import Foundation

/// The internal room test never reads or writes the player's profile. The
/// backend is chosen before any singleton initializes and lasts through title.
/// Normal Debug and every Release use the original standard defaults directly.
// Explicitly outside the project's default MainActor: catalog loading is
// nonisolated. Backing selection is immutable; UserDefaults is thread-safe,
// and locked memory uses only value-type property-list payloads (no shared mutable reference payloads).
nonisolated final class GameRunPreferences: @unchecked Sendable {
    static var isIsolated: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--arena9-traversal") || ProcessInfo.processInfo.arguments.contains("--arena8-game") || ProcessInfo.processInfo.arguments.contains("--arena8-six")
        #else
        return false
        #endif
    }
    static let shared = GameRunPreferences(backing: isIsolated ? nil : .standard)
    private let backing: UserDefaults?
    private let lock = NSRecursiveLock()
    private var values: [String: Any] = [:]
    private var registered: [String: Any] = [:]

    // nil is deliberately memory only; no named defaults domain is created.
    init(backing: UserDefaults?) { self.backing = backing }
    func object(forKey key: String) -> Any? {
        if let backing { return backing.object(forKey: key) }
        lock.lock(); defer { lock.unlock() }
        return values[key] ?? registered[key]
    }
    func set(_ value: Any?, forKey key: String) {
        if let backing { backing.set(value, forKey: key); return }
        lock.lock(); defer { lock.unlock() }; values[key] = value
    }
    func removeObject(forKey key: String) {
        if let backing { backing.removeObject(forKey: key); return }
        lock.lock(); defer { lock.unlock() }; values.removeValue(forKey: key)
    }
    func register(defaults: [String: Any]) {
        if let backing { backing.register(defaults: defaults); return }
        lock.lock(); defer { lock.unlock() }
        registered.merge(defaults) { _, new in new }
    }
    func dictionaryRepresentation() -> [String: Any] {
        if let backing { return backing.dictionaryRepresentation() }
        lock.lock(); defer { lock.unlock() }; return registered.merging(values) { _, new in new }
    }
    func bool(forKey key: String) -> Bool {
        if let backing { return backing.bool(forKey: key) }
        return (object(forKey: key) as? NSNumber)?.boolValue ?? false
    }
    func integer(forKey key: String) -> Int {
        if let backing { return backing.integer(forKey: key) }
        return (object(forKey: key) as? NSNumber)?.intValue ?? 0
    }
    func double(forKey key: String) -> Double {
        if let backing { return backing.double(forKey: key) }
        return (object(forKey: key) as? NSNumber)?.doubleValue ?? 0
    }
    func string(forKey key: String) -> String? {
        if let backing { return backing.string(forKey: key) }
        return object(forKey: key) as? String
    }
    func stringArray(forKey key: String) -> [String]? {
        if let backing { return backing.stringArray(forKey: key) }
        return object(forKey: key) as? [String]
    }
    func data(forKey key: String) -> Data? {
        if let backing { return backing.data(forKey: key) }
        return object(forKey: key) as? Data
    }
    func dictionary(forKey key: String) -> [String: Any]? {
        if let backing { return backing.dictionary(forKey: key) }
        return object(forKey: key) as? [String: Any]
    }
}
