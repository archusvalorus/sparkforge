// ParityCatalog.swift — v2.2 catalog migration (J1). Test support only;
// compiled by tools/catalog-harness/run.sh, never part of the app target.
//
// The JSON catalog as an effect source (J2: the game's only source), and the
// loader's rejection cases.

import CryptoKit
import Foundation

extension EffectSource {
    /// What the game runs on: the installed catalog (J2).
    static func runtime() -> EffectSource { catalog(AbilityCatalog.current) }

    /// A catalog, loaded and bound to `AbilityBehaviors`.
    static func catalog(_ catalog: AbilityCatalog) -> EffectSource {
        let byID = Dictionary(uniqueKeysWithValues: catalog.cards.map { ($0.id, $0) })
        return EffectSource(
            label: "json catalog",
            cardIDs: catalog.cards.map { $0.id },
            tierCount: byID.mapValues { $0.maxTier },
            trees: byID.mapValues { [$0.tag.rawValue] + ($0.secondaryTag.map { [$0.rawValue] } ?? []) },
            applyTier: { id, tier, stats in
                guard let card = byID[id], tier >= 1, tier <= card.maxTier else { return false }
                if tier == 1 { card.apply(stats) } else { card.higherTiers[tier - 2](stats) }
                return true
            },
            applySynergy: { key, stats in
                guard let effect = catalog.synergyEffects[key] else { return false }
                effect(stats)
                return true
            })
    }
}

enum ParityDigest {
    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Rejection cases

/// One way to break the catalog, and the diagnostic the loader must answer with.
struct CatalogRejectionCase {
    let name: String
    let expected: CatalogDiagnostic.Code
    let data: Data
    let registry: AbilityBehaviors.Registry
    /// When set, the case goes through `load(source:)` instead of `load(_:)`.
    var source: (() throws -> Data)? = nil
}

enum CatalogRejections {

    private static func edited(_ valid: Data, _ edit: (NSMutableDictionary) -> Void) -> Data {
        guard let doc = try? JSONSerialization.jsonObject(with: valid, options: [.mutableContainers]) as? NSMutableDictionary else {
            fatalError("the valid catalog must parse before it can be broken")
        }
        edit(doc)
        guard let out = try? JSONSerialization.data(withJSONObject: doc) else { fatalError("an edited catalog must serialise") }
        return out
    }

    private static func list(_ doc: NSMutableDictionary, _ key: String) -> NSMutableArray {
        guard let found = doc[key] as? NSMutableArray else { fatalError("the valid catalog has no `\(key)` list") }
        return found
    }

    private static func card(_ doc: NSMutableDictionary, _ id: String) -> NSMutableDictionary {
        for case let entry as NSMutableDictionary in list(doc, "cards") where entry["id"] as? String == id { return entry }
        fatalError("the valid catalog has no card `\(id)`")
    }

    private static func tiers(_ doc: NSMutableDictionary, _ id: String) -> NSMutableArray {
        guard let found = card(doc, id)["tiers"] as? NSMutableArray else { fatalError("card `\(id)` has no tiers") }
        return found
    }

    private static func tier(_ doc: NSMutableDictionary, _ id: String, _ index: Int) -> NSMutableDictionary {
        guard let found = tiers(doc, id)[index] as? NSMutableDictionary else { fatalError("card `\(id)` has no tier \(index)") }
        return found
    }

    private static func synergy(_ doc: NSMutableDictionary, _ behavior: String) -> NSMutableDictionary {
        for case let entry as NSMutableDictionary in list(doc, "synergies") where entry["behavior"] as? String == behavior { return entry }
        fatalError("the valid catalog has no synergy `\(behavior)`")
    }

    /// Every rejection case. Each breaks ONE thing in the valid file (or in a
    /// copy of the native registry).
    static func all(valid: Data, registry: AbilityBehaviors.Registry) -> [CatalogRejectionCase] {
        var out: [CatalogRejectionCase] = []
        func file(_ name: String, _ code: CatalogDiagnostic.Code, _ edit: @escaping (NSMutableDictionary) -> Void) {
            out.append(CatalogRejectionCase(name: name, expected: code, data: edited(valid, edit), registry: registry))
        }
        func raw(_ name: String, _ code: CatalogDiagnostic.Code, _ text: String) {
            out.append(CatalogRejectionCase(name: name, expected: code, data: Data(text.utf8), registry: registry))
        }
        func native(_ name: String, _ code: CatalogDiagnostic.Code, _ edit: (inout AbilityBehaviors.Registry) -> Void) {
            var altered = registry
            edit(&altered)
            out.append(CatalogRejectionCase(name: name, expected: code, data: valid, registry: altered))
        }

        // The document itself
        out.append(CatalogRejectionCase(name: "the source cannot be read", expected: .resourceUnavailable, data: Data(), registry: registry,
                                        source: { throw AbilityCatalogSource.Unavailable(description: "injected: no such file") }))
        raw("not JSON", .malformedJSON, "{ \"schema\": ")
        raw("empty file", .malformedJSON, "")
        raw("a list at the top", .wrongType, "[]")
        file("schema name missing", .missingField) { $0.removeObject(forKey: "schema") }
        file("another schema", .unsupportedSchema) { $0["schema"] = "someone.elses-catalog" }
        file("a newer schema version", .unsupportedSchemaVersion) { $0["schemaVersion"] = 2 }
        file("schema version 0", .unsupportedSchemaVersion) { $0["schemaVersion"] = 0 }
        file("schema version as text", .wrongType) { $0["schemaVersion"] = "1" }
        file("schema version 1.5", .wrongType) { $0["schemaVersion"] = 1.5 }
        file("schema version true", .wrongType) { $0["schemaVersion"] = true }
        file("unknown top-level key", .unknownField) { $0["remoteURL"] = "https://example.com" }
        file("cards list missing", .missingField) { $0.removeObject(forKey: "cards") }
        file("cards is an object", .wrongType) { $0["cards"] = NSMutableDictionary() }
        file("synergies list missing", .missingField) { $0.removeObject(forKey: "synergies") }
        file("retired list missing", .missingField) { $0.removeObject(forKey: "retired") }
        file("trees list missing", .missingField) { $0.removeObject(forKey: "trees") }
        file("capabilities list missing", .missingField) { $0.removeObject(forKey: "capabilities") }

        // Vocabulary
        file("a tree renamed", .treesMismatch) { (list($0, "trees")[0] as? NSMutableDictionary)?["name"] = "Flame" }
        file("a tree key changed", .treesMismatch) { (list($0, "trees")[3] as? NSMutableDictionary)?["key"] = "guardT" }
        file("two trees swapped", .treesMismatch) { list($0, "trees").exchangeObject(at: 0, withObjectAt: 1) }
        file("a tree removed", .treesMismatch) { list($0, "trees").removeLastObject() }
        file("a tree added", .treesMismatch) { list($0, "trees").add(NSMutableDictionary(dictionary: ["key": "rainbow", "name": "Rainbow"])) }
        file("card in an unknown tree", .unknownTree) { card($0, "neutral_1")["tree"] = "arcane" }
        file("card uses a Swift case name for its tree", .unknownTree) { card($0, "guard_1")["tree"] = "guardT" }
        file("unknown secondary tree", .unknownTree) { card($0, "v18_red_smile")["secondaryTree"] = "voidT" }
        file("secondary tree repeats the primary", .sameSecondaryTree) { card($0, "v18_red_smile")["secondaryTree"] = "bleed" }
        file("unknown capability on a card", .unknownCapability) { card($0, "bleed_2")["requires"] = ["bleedUnlocked", "critSorce"] }
        file("unknown capability declared", .unknownCapability) { list($0, "capabilities").add("rainbowUnlocked") }
        file("capability declared twice", .duplicateCapability) { list($0, "capabilities").add("fireUnlocked") }
        file("capability listed twice on a card", .duplicateCapability) { card($0, "void_2")["provides"] = ["voidWell", "pelletEffect", "voidWell"] }
        file("capability used but not declared", .undeclaredCapability) { list($0, "capabilities").remove("critSource") }
        file("capability is a number", .wrongType) { card($0, "fire_2")["requires"] = [7] }
        file("requires is text, not a list", .wrongType) { card($0, "fire_2")["requires"] = "fireUnlocked" }

        // Cards
        file("no cards", .noCards) { list($0, "cards").removeAllObjects() }
        file("a card is text", .wrongType) { list($0, "cards")[4] = "shock_1" }
        file("card id missing", .missingField) { card($0, "neutral_1").removeObject(forKey: "id") }
        file("card name missing", .missingField) { card($0, "neutral_1").removeObject(forKey: "name") }
        file("card tree missing", .missingField) { card($0, "neutral_1").removeObject(forKey: "tree") }
        file("card face missing", .missingField) { card($0, "neutral_1").removeObject(forKey: "face") }
        file("card behavior missing", .missingField) { card($0, "neutral_1").removeObject(forKey: "behavior") }
        file("card face empty", .emptyText) { card($0, "neutral_1")["face"] = "" }
        file("card detail empty", .emptyText) { card($0, "fire_1")["detail"] = "" }
        file("card name is a number", .wrongType) { card($0, "neutral_1")["name"] = 12 }
        file("misspelt optional key on a card", .unknownField) { card($0, "fire_1")["isSignature"] = true }
        file("signature flag is 1", .wrongType) { card($0, "fire_1")["signature"] = 1 }
        file("capstone flag is text", .wrongType) { card($0, "cap_fire_everglow")["capstone"] = "true" }
        file("duplicate card id", .duplicateID) { card($0, "neutral_4")["id"] = "neutral_1" }
        file("a retired id is live", .retiredIDIsLive) { card($0, "neutral_4")["id"] = "v16_mass_tax" }
        file("an id retired twice", .duplicateRetiredID) { list($0, "retired").add(NSMutableDictionary(dictionary: ["id": "v16_mass_tax", "note": "again"])) }
        file("retired entry without a note", .missingField) { (list($0, "retired")[0] as? NSMutableDictionary)?.removeObject(forKey: "note") }
        file("unknown key on a retired entry", .unknownField) { (list($0, "retired")[0] as? NSMutableDictionary)?["retiredIn"] = "A2" }

        // Tiers
        file("a one-entry tier list", .tierListTooShort) { tiers($0, "bleed_1").removeLastObject() }
        file("tier face missing", .missingField) { tier($0, "neutral_6", 1).removeObject(forKey: "face") }
        file("tier face empty", .emptyText) { tier($0, "neutral_6", 2)["face"] = "" }
        file("a tier is text", .wrongType) { tiers($0, "neutral_6")[1] = "+1 more projectile" }
        file("unknown key on a tier", .unknownField) { tier($0, "neutral_6", 1)["description"] = "x" }
        file("gate on tier 1", .tierOneGate) { tier($0, "chill_1", 0)["requires"] = ["chillUnlocked"] }
        file("tier names on some tiers only", .tierNamesIncomplete) { tier($0, "v20_panda", 2).removeObject(forKey: "name") }
        file("unknown capability on a tier", .unknownCapability) { tier($0, "chill_1", 2)["requires"] = ["polarVortx"] }

        // The join with native behaviour
        file("behaviour key with no native effect", .missingBehavior) { card($0, "neutral_1")["behavior"] = "neutral_swift" }
        file("a tier line too few", .tierCountMismatch) { tiers($0, "bleed_4").removeLastObject() }
        file("a tier line too many", .tierCountMismatch) { tiers($0, "neutral_6").add(NSMutableDictionary(dictionary: ["face": "+1 more projectile (a wall of shots)"])) }
        file("a ladder flattened to one tier", .tierCountMismatch) { card($0, "neutral_6").removeObject(forKey: "tiers") }
        file("a card removed, its effect left behind", .unboundBehavior) { list($0, "cards").remove(card($0, "neutral_5")) }
        native("a card whose native effect was deleted", .missingBehavior) { $0.cards.removeValue(forKey: "neutral_5") }
        native("a native effect no card binds", .unboundBehavior) { $0.cards["neutral_orphan"] = CardBehavior(tiers: [{ _ in }]) }
        native("native ladder gains a tier", .tierCountMismatch) { $0.cards["bleed_4"] = CardBehavior(tiers: Array(repeating: { _ in }, count: 5)) }
        native("native effect with no tiers", .tierCountMismatch) { $0.cards["neutral_1"] = CardBehavior(tiers: []) }
        native("a behaviour key registered twice", .duplicateBehaviorKey) { $0.duplicateKeys.append("fire_1") }
        file("the scheduled secret card is not secret", .secretScheduleMismatch) { card($0, "v20_panda").removeObject(forKey: "secret") }
        native("the scheduler names a card the file lacks", .secretScheduleMismatch) { $0.scheduledSecretCardID = "v20_red_panda" }
        file("a card native code names is gone", .nativeIDMissing) { doc in
            list(doc, "cards").remove(card(doc, "v20_wildbloom"))
        }
        native("native code names a card the file lacks", .nativeIDMissing) { $0.nativeCardIDs.append("v99_not_here") }

        // Synergies
        file("a synergy on Neutral", .synergyTreeNotColoured) { doc in
            list(doc, "synergies").add(NSMutableDictionary(dictionary: ["tree": "neutral", "threshold": 3, "title": "Plain", "effect": "Nothing", "behavior": "fire.3"]))
        }
        file("a synergy tier removed", .synergyLadderMismatch) { list($0, "synergies").remove(synergy($0, "chill.7")) }
        file("a synergy threshold changed", .synergyLadderMismatch) { synergy($0, "fire.5")["threshold"] = 4 }
        file("a synergy tier listed twice", .synergyLadderMismatch) { doc in
            list(doc, "synergies").add(NSMutableDictionary(dictionary: synergy(doc, "void.3") as? [String: Any] ?? [:]))
        }
        file("a tree's synergy tiers out of order", .synergyLadderMismatch) { doc in
            let all = list(doc, "synergies")
            all.exchangeObject(at: all.index(of: synergy(doc, "bleed.3")), withObjectAt: all.index(of: synergy(doc, "bleed.5")))
        }
        file("a synergy in an unknown tree", .unknownTree) { synergy($0, "fire.3")["tree"] = "flame" }
        file("a synergy threshold as text", .wrongType) { synergy($0, "fire.3")["threshold"] = "3" }
        file("a synergy title missing", .missingField) { synergy($0, "fire.3").removeObject(forKey: "title") }
        file("a synergy effect line empty", .emptyText) { synergy($0, "fire.3")["effect"] = "" }
        file("unknown key on a synergy", .unknownField) { synergy($0, "fire.3")["tier"] = 3 }
        file("a synergy key with no native effect", .missingSynergyBehavior) { synergy($0, "guard.7")["behavior"] = "guard.9" }
        native("a native synergy effect nothing binds", .unboundSynergyBehavior) { $0.synergies["rainbow.9"] = { _ in } }
        native("a synergy whose native effect was deleted", .missingSynergyBehavior) { $0.synergies.removeValue(forKey: "growth.5") }
        return out
    }

    /// Three independent problems in one file: the loader must report all three.
    static func threeProblems(valid: Data) -> Data {
        edited(valid) { doc in
            card(doc, "neutral_1")["face"] = ""
            card(doc, "neutral_4")["id"] = "neutral_3"
            synergy(doc, "fire.5")["threshold"] = 4
        }
    }
}
