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
    // v2.1 A1: Crucible — stacks added by Kindle hits, and the tallest pile seen.
    private(set) var burnStacksAdded = 0
    private(set) var burnMaxStacks = 0
    // v2.1 A2: Chill — snowmen made, Glacial Spikes landed.
    var snowmen = 0
    var spikes = 0
    // v2.1 A3: Shock — Overload stuns, coil shocks, longest chain seen.
    var overloadStuns = 0
    var coilShocks = 0
    private(set) var chains = 0
    private(set) var longestChain = 0
    mutating func recordChain(jumps: Int) {
        guard jumps > 0 else { return }
        chains += 1
        if jumps > longestChain { longestChain = jumps; NSLog("[A3] chain reached %d jumps", jumps) }
    }

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

    // v2.1 A4a: Bleed (applications that started a fresh Bleed, ticks landed,
    // kills by channel) and DoTs on the arena boss.
    var bleedsStarted = 0
    var bleedTicks = 0
    private(set) var dotKills: [StatusDoTs.Channel: Int] = [:]
    private(set) var bossBurnDamage = 0
    private(set) var bossBleedDamage = 0
    private(set) var bossBurnMaxStacks = 0
    private(set) var bossDotKill: StatusDoTs.Channel?
    mutating func recordDotKill(_ channel: StatusDoTs.Channel) {
        dotKills[channel, default: 0] += 1
    }
    mutating func recordBossDoT(_ channel: StatusDoTs.Channel, damage: Int, stacks: Int) {
        switch channel {
        case .burn:
            if bossBurnDamage == 0 { NSLog("[A4] boss took its first Burn tick (%d, %d stacks)", damage, stacks) }
            bossBurnDamage += damage
        case .bleed:
            if bossBleedDamage == 0 { NSLog("[A4] boss took its first Bleed tick (%d)", damage) }
            bossBleedDamage += damage
        }
        if stacks > bossBurnMaxStacks { bossBurnMaxStacks = stacks }
    }
    mutating func recordBossDotKill(_ channel: StatusDoTs.Channel) {
        bossDotKill = channel
        NSLog("[A4] boss killed by %@  %@", channel.rawValue, summary)
    }

    mutating func recordKill(_ source: KillSource) {
        kills[source, default: 0] += 1
    }

    mutating func recordBurnStack(_ stacks: Int) {
        burnStacksAdded += 1
        if stacks > burnMaxStacks {
            burnMaxStacks = stacks
            NSLog("[A1] Burn reached %d stacks", stacks)
        }
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
            + "dupes=\(duplicateCredits) kills[\(bySource)] "
            + "burn[stacks+=\(burnStacksAdded) max=\(burnMaxStacks)] "
            + "chill[snowmen=\(snowmen) spikes=\(spikes)] "
            + "shock[chains=\(chains) longest=\(longestChain) stuns=\(overloadStuns) coils=\(coilShocks)] "
            + "bleed[started=\(bleedsStarted) ticks=\(bleedTicks) "
            + "dotKills=burn:\(dotKills[.burn] ?? 0)/bleed:\(dotKills[.bleed] ?? 0)] "
            + "boss[burn=\(bossBurnDamage) bleed=\(bossBleedDamage) stacks=\(bossBurnMaxStacks) "
            + "dotKill=\(bossDotKill?.rawValue ?? "-")]"
    }
}
#endif
