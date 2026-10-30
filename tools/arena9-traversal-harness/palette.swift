import Foundation
var passed=0,failed=0
func check(_ id:String,_ yes:@autoclosure()->Bool){if yes(){passed+=1;print("PASS \(id)")}else{failed+=1;print("FAIL \(id)")}}
if case .failure(let error)=AbilityCatalog.installed {print("FAIL catalog \(error.summary)");exit(1)}
ProgressionManager.shared.arenasUnlocked=8
let colors=Set(UpgradeManager.Tag.allCases).subtracting([.neutral,.growth])
for ban:UpgradeManager.Tag? in [nil,.growth,.fire,.shock,.bleed,.guardT,.voidT,.chill] {
    let otherBan = ban != nil && ban != .growth
    SettingsManager.shared.bannedFamily=ban
    var palettes=Set<String>()
    for seed:UInt64 in 0..<200 {
        let m=UpgradeManager(seed:seed,excludedFamilies:[.growth])
        let actual=m.activeFamilies.subtracting([.neutral])
        check("Growth omitted before palette",!actual.contains(.growth) && actual.isSubset(of:colors))
        check("sticky ban remains recorded",m.bannedFamily==ban && SettingsManager.shared.bannedFamily==ban)
        check("ban and leave-one-out preserved",actual.count==(otherBan ? 4:5) && (otherBan ? !actual.contains(ban ?? .neutral):true))
        check("Neutral remains",m.activeFamilies.contains(.neutral))
        palettes.insert(actual.map(\.rawValue).sorted().joined(separator:","))
        let snapshot=RainbowPolicy.Snapshot(manager:m)
        check("Rainbow reads actual frozen palette",snapshot.palette==actual && !snapshot.palette.contains(.growth))
        for bridge in m.allCards where bridge.secondaryTag != nil {
            guard let secondary=bridge.secondaryTag else{continue}
            if !actual.contains(bridge.tag) || !actual.contains(secondary) {
                check("bridge cannot bypass either omitted endpoint",!m.isSelectable(bridge,atLevel:20))
            }
        }
        for level in 1...20 {
            let cards=m.drawCards(count:3,level:level)
            check("all spread paths obey active families",cards.allSatisfy { card in
                card.isSecret || (m.activeFamilies.contains(card.tag) && (card.secondaryTag.map(m.activeFamilies.contains) ?? true))
            })
        }
        let stats=PlayerStats()
        for (i,signature) in m.allCards.filter({$0.isSignature && actual.contains($0.tag)}).enumerated() {
            check("active signatures still acquire",m.acquire(signature,stats:stats,level:30+i))
        }
        let p=RainbowPolicy(snapshot:.init(manager:m))
        check("coverage qualifies without omitted Growth",p.requiredColors==actual && p.qualified)
        m.reset()
        check("reset retains Arena9 omission and stored ban",!m.activeFamilies.contains(.growth) && m.bannedFamily==ban)
    }
    check("palette remains random rather than fixed four",palettes.count>1)
}
SettingsManager.shared.bannedFamily=nil
var ordinarySawGrowth=false
for seed:UInt64 in 0..<100 {if UpgradeManager(seed:seed).activeFamilies.contains(.growth){ordinarySawGrowth=true}}
check("ordinary default palette can still include Growth",ordinarySawGrowth)
print("RESULT \(passed) passed \(failed) failed");exit(failed==0 ? 0:1)
