// CombatLedger.swift
// Sparkforge
//
// v2.1 Abilities A0: DEBUG-only proof counters for the shared damage and kill
// events. Quiet by default — one `[A0]` line per lethal rescue and per rejected
// duplicate kill credit, plus a run summary when the run ends. Release builds
// compile none of it.

#if DEBUG
import Foundation

struct CombatLedger {
    private(set) var hits = 0
    private(set) var ceilingClamps = 0
    private(set) var barrierOnlyHits = 0
    private(set) var barrierAbsorbed = 0
    private(set) var braceRescues = 0
    private(set) var unbrokenRescues = 0
    private(set) var duplicateCredits = 0
    private(set) var kills: [KillSource: Int] = [:]

    mutating func record(_ outcome: PlayerDamagePipeline.Outcome) {
        hits += 1
        if outcome.ceilingApplied { ceilingClamps += 1 }
        if outcome.barrierOnly { barrierOnlyHits += 1 }
        barrierAbsorbed += outcome.absorbed
        switch outcome.rescue {
        case .brace:
            braceRescues += 1
            NSLog("[A0] lethal hit → Brace (hp %d)  %@", outcome.hpAfter, summary)
        case .unbrokenCore:
            unbrokenRescues += 1
            NSLog("[A0] lethal hit → Unbroken Core (hp %d)  %@", outcome.hpAfter, summary)
        case .none:
            break
        }
    }

    mutating func recordKill(_ source: KillSource) {
        kills[source, default: 0] += 1
    }

    mutating func recordDuplicate(_ source: KillSource) {
        duplicateCredits += 1
        NSLog("[A0] duplicate kill credit rejected (%@)  %@", source.rawValue, summary)
    }

    var summary: String {
        let bySource = KillSource.allCases
            .compactMap { s in kills[s].map { "\(s.rawValue)=\($0)" } }
            .joined(separator: " ")
        return "hits=\(hits) clamp=\(ceilingClamps) barrierOnly=\(barrierOnlyHits) "
            + "absorbed=\(barrierAbsorbed) brace=\(braceRescues) unbroken=\(unbrokenRescues) "
            + "dupes=\(duplicateCredits) kills[\(bySource)]"
    }
}
#endif
