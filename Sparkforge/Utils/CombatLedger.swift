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

    // v2.1 A4b: boss kills credited at the killing blow (+ rejected repeats),
    // bleeding kills (Frenzy / Bloodlust), Blood Barrier, Glass Blood.
    private(set) var bossKills = 0
    private(set) var bossDupes = 0
    var bleedingKills = 0
    private(set) var barrierFromSanguinarian = 0
    private(set) var barrierFromSiphon = 0
    private(set) var barrierRequested = 0
    /// Glass Blood (Lyra's correction 3): every Bleed-tick death while owned,
    /// split into ELIGIBLE (generation 0/1 — must burst) and CAPPED (generation
    /// 2 — must not). The check is `glassBursts == glassEligible`.
    private(set) var glassBleedDeaths = 0
    private(set) var glassEligible = 0
    private(set) var glassCapped = 0
    private(set) var glassMaxGeneration = 0
    var glassBursts = 0
    mutating func recordBossKill(_ ctx: KillContext) {
        bossKills += 1
        NSLog("[A4] boss kill credited at the killing blow (bleeding=%@ byBleed=%@ gen=%d finish=%d)  %@",
              ctx.diedBleeding ? "yes" : "no", ctx.killedByBleed ? "yes" : "no",
              ctx.bleedGeneration, ctx.finishingDamage, summary)
    }
    mutating func recordBossDuplicate() {
        bossDupes += 1
        NSLog("[A4] ⚠ duplicate boss credit rejected  %@", summary)
    }
    mutating func recordBarrier(requested: Int, added: Int, fromSiphon: Bool) {
        barrierRequested += requested
        if fromSiphon { barrierFromSiphon += added } else { barrierFromSanguinarian += added }
    }
    /// Counted where the Bleed death happens — independent of the burst code.
    mutating func recordGlassBloodDeath(generation: Int) {
        glassBleedDeaths += 1
        if generation < GameConfig.Bleed.glassBloodMaxGeneration { glassEligible += 1 } else { glassCapped += 1 }
        glassMaxGeneration = max(glassMaxGeneration, generation)
    }

    mutating func recordKill(_ source: KillSource) {
        kills[source, default: 0] += 1
    }

    // v2.1 A4c: Red Smile — per-form proof (swings, primary hits, the gun's
    // volleys while the form holds, which must be 0) plus run totals.
    var gunVolleys = 0                 // auto-attack volleys fired, whole run
    private(set) var redSmileForms = 0
    private(set) var redSmileInterrupts = 0
    private(set) var redSmileSwings = 0
    private(set) var redSmileEmptySwings = 0
    private(set) var redSmileHits = 0
    private(set) var redSmileBossHits = 0
    private(set) var redSmileChains = 0
    var redSmileVoidBypasses = 0       // Braceguard shields the sweep ignored (CL-37)
    var redSmileIntangibleSkips = 0    // phased / vanished bodies in the arc (CL-40)
    var redSmileTerrainBlocks = 0      // bodies in the arc behind the Carrier (CL-38)
    private var formSwings = 0
    private var formHits = 0
    private var formVolleysAtStart = 0
    mutating func redSmileFormBegan(interval: TimeInterval) {
        redSmileForms += 1
        formSwings = 0
        formHits = 0
        formVolleysAtStart = gunVolleys
        NSLog("[A4c] form #%d begins (swing interval %.3fs)", redSmileForms, interval)
    }
    mutating func redSmileSwing(enemyHits: Int, bossHit: Bool, chained: Bool) {
        // Corrective F1/F2 cross-checks against this swing's meter contacts.
        let shatters = swingContacts[.shatter] ?? 0, ordinary = swingContacts[.enemy] ?? 0
        if ordinary + shatters != enemyHits || (swingContacts[.boss] ?? 0) != (bossHit ? 1 : 0) {
            meterViolations += 1
            NSLog("[A4c] ⚠ meter contacts %d/%d/%d ≠ swing hits %d + boss %@", ordinary, shatters,
                  swingContacts[.boss] ?? 0, enemyHits, bossHit ? "yes" : "no")
        }
        if chained && ordinary == 0 { chainWithoutSeed += 1 }
        if shatters == 1 && ordinary == 0 && !bossHit {
            soloShatterSwings += 1
            soloShatterMeterGains += swingGains
        }
        redSmileSwings += 1
        formSwings += 1
        let struck = enemyHits + (bossHit ? 1 : 0)
        if struck == 0 { redSmileEmptySwings += 1 }
        redSmileHits += struck
        formHits += struck
        if bossHit { redSmileBossHits += 1 }
        if chained { redSmileChains += 1 }
    }
    /// `reason`: "expired", "kaiju" (an interrupt) or "death".
    mutating func redSmileFormEnded(reason: String) {
        if reason == "kaiju" { redSmileInterrupts += 1 }
        NSLog("[A4c] form #%d ends (%@) swings=%d hits=%d gunVolleysDuringForm=%d  %@",
              redSmileForms, reason, formSwings, formHits,
              gunVolleys - formVolleysAtStart, redSmileSummary)
    }
    // v2.1 A4c corrective (F1/F2): hit-meter registrations by contact kind.
    // Proof, from the REAL contact paths: every landed contact asks each meter
    // once (contacts by kind must match the swing tallies), a charge sticks
    // exactly when the meter's own rules allowed it (never twice), and a swing
    // never chains without an ordinary (non-Shatter) enemy contact.
    private(set) var meterContacts: [RedSmileContact: Int] = [:]
    private(set) var apexGains: [RedSmileContact: Int] = [:]
    private(set) var erasureGains: [RedSmileContact: Int] = [:]
    private(set) var meterRejections = 0          // eligible = false → no gain (cooldown / capacity / off)
    private(set) var meterViolations = 0          // gain ≠ eligibility, or a double gain
    private(set) var soloShatterSwings = 0        // swings whose ONLY contact was a Shatter…
    private(set) var soloShatterMeterGains = 0    // …and the meter gains those swings made
    private(set) var chainWithoutSeed = 0         // a chain with no ordinary enemy contact: must stay 0
    private var swingContacts: [RedSmileContact: Int] = [:]
    private var swingGains = 0
    mutating func redSmileSwingBegan() {
        swingContacts = [:]
        swingGains = 0
    }
    mutating func redSmileMeterCharge(_ contact: RedSmileContact, apexEligible: Bool, apexGained: Int,
                                      erasureEligible: Bool, erasureGained: Int) {
        meterContacts[contact, default: 0] += 1
        swingContacts[contact, default: 0] += 1
        apexGains[contact, default: 0] += apexGained
        erasureGains[contact, default: 0] += erasureGained
        swingGains += apexGained + erasureGained
        for (eligible, gained, name) in [(apexEligible, apexGained, "apex"), (erasureEligible, erasureGained, "erasure")] {
            if !eligible && gained == 0 { meterRejections += 1 }
            if gained != (eligible ? 1 : 0) {
                meterViolations += 1
                NSLog("[A4c] ⚠ %@ meter: %@ contact eligible=%@ gained=%d", name, contact.rawValue,
                      eligible ? "yes" : "no", gained)
            }
        }
    }
    var redSmileSummary: String {
        "redSmile[forms=\(redSmileForms) interrupts=\(redSmileInterrupts) swings=\(redSmileSwings) "
            + "empty=\(redSmileEmptySwings) hits=\(redSmileHits) boss=\(redSmileBossHits) "
            + "chains=\(redSmileChains) meleeKills=\(kills[.melee] ?? 0) voidBypass=\(redSmileVoidBypasses) "
            + "intangibleSkips=\(redSmileIntangibleSkips) terrainBlocks=\(redSmileTerrainBlocks)] "
            + "meters[contacts e/s/b=\(meterContacts[.enemy] ?? 0)/\(meterContacts[.shatter] ?? 0)/\(meterContacts[.boss] ?? 0) "
            + "apex+=\(apexGains[.enemy] ?? 0)/\(apexGains[.shatter] ?? 0)/\(apexGains[.boss] ?? 0) "
            + "erasure+=\(erasureGains[.enemy] ?? 0)/\(erasureGains[.shatter] ?? 0)/\(erasureGains[.boss] ?? 0) "
            + "rejected=\(meterRejections) soloShatter=\(soloShatterSwings)/+\(soloShatterMeterGains) "
            + "chainNoSeed=\(chainWithoutSeed) VIOLATIONS=\(meterViolations)]"
    }

    mutating func recordBurnStack(_ stacks: Int) {
        burnStacksAdded += 1
        if stacks > burnMaxStacks {
            burnMaxStacks = stacks
            NSLog("[A1] Burn reached %d stacks", stacks)
        }
    }

    // v2.1 A5: Guard (closure table §B4) — Ironhide contributors, Fortify and
    // Grounded Core gains, Unbroken windows and shield blocks, Iron Bloom,
    // bounces and spikes, Repulse launches and impacts, self-damage rescues.
    private(set) var ironhideMax = 0
    private(set) var fortifyMax = 0
    private(set) var groundedPoints = 0
    private(set) var unbrokenWindows = 0
    private(set) var unbrokenLastBonus: CGFloat = 0
    private(set) var shieldBlocks = 0
    private(set) var ironBloomPulses = 0
    private(set) var ironBloomHits = 0
    private(set) var selfDamageRescues = 0
    var bounces = 0
    var aegisSpikes = 0
    var launches = 0
    /// Launches that actually left the ground (the shot didn't kill the body).
    var launchesFlown = 0
    var launchWallStops = 0
    var launchCarrierStops = 0
    var ironBloomTerrainBlocks = 0
    var impacts = 0

    mutating func recordIronhide(contributors: Int) {
        guard contributors > ironhideMax else { return }
        ironhideMax = contributors
        NSLog("[A5] Ironhide reached %d contributors (%.0f%%)", contributors,
              Double(min(contributors, 10)) * 9)
    }
    mutating func recordFortify(_ temporaryDEF: Int) {
        guard temporaryDEF > fortifyMax else { return }
        fortifyMax = temporaryDEF
        if temporaryDEF % 10 == 0 { NSLog("[A5] Fortify reached +%d DEF", temporaryDEF) }
    }
    mutating func recordGroundedPoint(total: Int) {
        groundedPoints = total
        NSLog("[A5] Grounded Core banked a point (total +%d)", total)
    }
    mutating func recordUnbrokenWindow(def: Int, atk: CGFloat, bonus: CGFloat) {
        unbrokenWindows += 1
        unbrokenLastBonus = bonus
        NSLog("[A5] Unbroken window opened: DEF %d / ATK %.1f → +%.2f multiplier for 10s", def, Double(atk), Double(bonus))
    }
    mutating func recordShieldBlock() {
        shieldBlocks += 1
        NSLog("[A5] projectile shield blocked #%d", shieldBlocks)
    }
    mutating func recordIronBloom(hits: Int, damage: Int) {
        ironBloomPulses += 1
        ironBloomHits += hits
        if ironBloomPulses <= 3 { NSLog("[A5] Iron Bloom pulse %d: %d hit for %d", ironBloomPulses, hits, damage) }
    }
    mutating func recordSelfDamageRescue(_ rescue: PlayerDamagePipeline.Rescue) {
        selfDamageRescues += 1
        switch rescue {
        case .brace: braceRescues += 1
        case .unbrokenCore: unbrokenRescues += 1
        case .none: break
        }
        NSLog("[A5] Unstable Core self-damage was lethal → %@", rescue == .brace ? "Brace" : "Unbroken Core")
    }

    var guardSummary: String {
        "guard[ironhideMax=\(ironhideMax) fortifyMax=\(fortifyMax) grounded=\(groundedPoints) "
            + "windows=\(unbrokenWindows) bonus=\(String(format: "%.2f", Double(unbrokenLastBonus))) "
            + "shieldBlocks=\(shieldBlocks) bloom=\(ironBloomPulses)/\(ironBloomHits) "
            + "bounces=\(bounces) spikes=\(aegisSpikes) launches=\(launches)/flown=\(launchesFlown) "
            + "stops[wall=\(launchWallStops) carrier=\(launchCarrierStops)] impacts=\(impacts) "
            + "bloomTerrain=\(ironBloomTerrainBlocks) "
            + "selfRescues=\(selfDamageRescues) impactKills=\(kills[.impact] ?? 0)]"
    }

    // v2.1 A6: Void (closure table §B5) — the volley counter and what it
    // fired, black holes by preset, the cap, absorbs and returns, traps and
    // decomposition, fear, Anomaly triggers, Dead Circuit matter and collapses.
    private(set) var qualifyingVolleys = 0
    private(set) var emptyVolleys = 0
    private(set) var blackholesSeeded = 0
    private(set) var blades = 0
    private(set) var convergences = 0
    private(set) var wellsByPreset: [String: Int] = [:]
    private(set) var wellsLiveMax = 0
    var wellEvictions = 0
    var absorbed = 0
    var returnsFired = 0
    var returnsFizzled = 0
    var traps = 0
    var fears = 0
    var decomposeDamage = 0
    var bossDecomposeDamage = 0
    var anomalyErases = 0
    var anomalyChunks = 0
    var bossAnomalyChunks = 0
    var matter = 0
    var collapses = 0
    var bladeHits = 0
    var returnedHits = 0

    mutating func recordVolley(emitted: Bool, blackhole: Bool, blade: Bool, count: Int) {
        guard emitted else { emptyVolleys += 1; return }
        qualifyingVolleys += 1
        if blackhole { blackholesSeeded += 1 }
        if blade { blades += 1 }
        if blackhole && blade {
            convergences += 1
            NSLog("[A6] volley %d: Blackhole + Shadow Edge together", count)
        }
    }
    mutating func recordVoidWell(_ preset: VoidWellPreset, live: Int) {
        wellsByPreset["\(preset)", default: 0] += 1
        if live > wellsLiveMax {
            wellsLiveMax = live
            NSLog("[A6] live black holes reached %d", live)
        }
    }

    var voidSummary: String {
        let presets = wellsByPreset.keys.sorted().map { "\($0)=\(wellsByPreset[$0] ?? 0)" }.joined(separator: " ")
        return "void[volleys=\(qualifyingVolleys) empty=\(emptyVolleys) seeds=\(blackholesSeeded) "
            + "blades=\(blades) both=\(convergences) wells[\(presets)] liveMax=\(wellsLiveMax) "
            + "evicted=\(wellEvictions) absorbed=\(absorbed) returned=\(returnsFired) fizzled=\(returnsFizzled) "
            + "traps=\(traps) decompose=\(decomposeDamage) bossDecompose=\(bossDecomposeDamage) "
            + "fears=\(fears) anomaly[erase=\(anomalyErases) chunk=\(anomalyChunks) boss=\(bossAnomalyChunks)] "
            + "matter=\(matter) collapses=\(collapses) hits[blade=\(bladeHits) returned=\(returnedHits)] "
            + "kills[returned=\(kills[.returned] ?? 0) blade=\(kills[.shadowEdge] ?? 0)]]"
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
            + "dotKill=\(bossDotKill?.rawValue ?? "-") credited=\(bossKills) dupes=\(bossDupes)] "
            + "a4b[bleedingKills=\(bleedingKills) barrier[sang=\(barrierFromSanguinarian) siphon=\(barrierFromSiphon) asked=\(barrierRequested)] "
            + "glass[deaths=\(glassBleedDeaths) eligible=\(glassEligible) bursts=\(glassBursts) capped=\(glassCapped) maxGen=\(glassMaxGeneration)]] "
            + redSmileSummary
    }
}
#endif
