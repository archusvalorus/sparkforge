// AbilityCatalogSource.swift
// Sparkforge
//
// v2.2 catalog migration (CL-113), Unit J2: where the app reads the authored
// ability catalog from. This is the ONLY file that knows about the bundle; the
// harnesses compile their own `AbilityCatalogSource` (tools/signature-draw-
// harness/Stubs.swift) that reads a path instead, so `AbilityCatalog.swift`
// and `UpgradeManager.swift` stay Foundation-only and host-compilable.

import Foundation

// `nonisolated`: `AbilityCatalog.installed` is a nonisolated static and the
// harnesses run without an actor; reading a bundled file needs no actor.
nonisolated enum AbilityCatalogSource {

    static let resourceName = "ability-catalog"

    struct Unavailable: Error, CustomStringConvertible {
        let description: String
    }

    /// The catalog's bytes. The file is a bundled resource and therefore part
    /// of the app's code signature; it cannot be absent or altered in a build
    /// that passed the catalog harness, so failing here is a build defect.
    static func data() throws -> Data {
        #if DEBUG
        // Development seam: `-SparkforgeCatalogPath <file>` as a launch
        // argument reads that file instead, to exercise the failure screen.
        // Announced on that screen and in the log; never compiled into Release.
        if let override = GameRunPreferences.shared.string(forKey: "SparkforgeCatalogPath"), !override.isEmpty {
            NSLog("[CATALOG] DEBUG override: reading the ability catalog from %@", override)
            do { return try Data(contentsOf: URL(fileURLWithPath: override)) }
            catch { throw Unavailable(description: "the DEBUG override file \(override) could not be read: \(error.localizedDescription)") }
        }
        #endif
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw Unavailable(description: "\(resourceName).json is not in the app bundle")
        }
        do { return try Data(contentsOf: url) }
        catch { throw Unavailable(description: "\(resourceName).json could not be read: \(error.localizedDescription)") }
    }
}
