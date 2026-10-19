import SpriteKit
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes{passed+=1;print("PASS ST \(name)")}else{failed+=1;print("FAIL ST \(name)")}}
func allLabels(_ node:SKNode)->[String]{var out:[String]=[];if let t=(node as? SKLabelNode)?.text{out.append(t)};for c in node.children{out+=allLabels(c)};return out}
func snapshot(_ s:PlayerStats)->[Int]{[s.maxHP,s.currentHP,s.baseAttack,s.defense]}
check("real config exact shared awards",PlayerStats.StatKind.hp.bonus==5 && PlayerStats.StatKind.attack.bonus==3 && PlayerStats.StatKind.defense.bonus==1)
let start=PlayerStats();check("starting values unchanged",snapshot(start)==[100,100,10,0])
for kind in PlayerStats.StatKind.allCases {
 let s=PlayerStats();s.currentHP=37;s.applyStatBonus(kind)
 let expected=kind == .hp ? [105,42,10,0] : kind == .attack ? [100,37,13,0] : [100,37,10,1]
 check("real award \(kind.rawValue)",snapshot(s)==expected)
 let scene=AwardScene();scene.playerStats.currentHP=37;scene.levelNeedsStat=true;scene.levelStatPick=kind
 scene.tryCommitLevelUp();check("selected award waits for card \(kind.rawValue)",snapshot(scene.playerStats)==[100,37,10,0])
 scene.pendingLevelCard=UpgradeCardNode();scene.tryCommitLevelUp();check("selected award and commit once \(kind.rawValue)",snapshot(scene.playerStats)==expected && scene.commits==1 && scene.levelStatPick==nil && !scene.levelNeedsStat)
 scene.tryCommitLevelUp();check("duplicate commit inert \(kind.rawValue)",snapshot(scene.playerStats)==expected && scene.commits==1)
 scene.pendingLevelCard=UpgradeCardNode();scene.tryCommitLevelUp();check("extra card gets no duplicate stat \(kind.rawValue)",snapshot(scene.playerStats)==expected && scene.commits==2)
 check("selected HP HUD immediately refreshed \(kind.rawValue)",allLabels(scene.hpBar).contains("\(expected[1])/\(expected[0])"))
 let chip=AwardScene.statCard(for:kind);check("actual choice chip uses shipped number \(kind.rawValue)",allLabels(chip).contains("+\(kind.bonus)") && allLabels(chip).contains(kind.label))
}
let full=PlayerStats();full.applyStatBonus(.hp);check("full-health HP award grows and heals",snapshot(full)==[105,105,10,0])
let damaged=PlayerStats();damaged.maxHP=100;damaged.currentHP=150;damaged.applyStatBonus(.hp);check("HP heal clamps to new maximum",damaged.currentHP==105)
for level in [2,4,6] {let scene=AwardScene();scene.player.currentLevel=level;scene.triggerLevelUp();check("even cadence unchanged \(level)",scene.levelNeedsStat && snapshot(scene.playerStats)==[100,100,10,0] && allLabels(scene.levelUpOverlay).contains("CHOOSE A STAT"))}
var randomKinds=Set<String>()
for _ in 0..<120 {
 let scene=AwardScene();scene.player.currentLevel=3;scene.playerStats.currentHP=37;scene.triggerLevelUp()
 let values=snapshot(scene.playerStats)
 let kind:PlayerStats.StatKind? = values == [105,42,10,0] ? .hp : values == [100,37,13,0] ? .attack : values == [100,37,10,1] ? .defense : nil
 check("odd award is exactly one updated shared stat",kind != nil && !scene.levelNeedsStat)
 if let kind=kind {randomKinds.insert(kind.rawValue);check("actual random badge displays current award",allLabels(scene.levelUpOverlay).contains("\(kind.emoji)  +\(kind.bonus) \(kind.label) awarded"))}
}
check("random observations cover all shared lanes",randomKinds.count==3)
for count in [1,8] {
 let s=AwardScene();s.playerStats.currentHP=37;s.runRandomOpener(count)
 let hp=(s.playerStats.maxHP-100)/5,atk=(s.playerStats.baseAttack-10)/3,def=s.playerStats.defense
 check("actual BossMode opener gives one shared award per granted level \(count)",hp+atk+def==count && s.player.currentLevel==1+count && s.playerStats.currentHP==37+hp*5 && (s.playerStats.maxHP-100)%5==0 && (s.playerStats.baseAttack-10)%3==0)
 check("BossMode HP HUD refreshed \(count)",allLabels(s.hpBar).contains("\(s.playerStats.currentHP)/\(s.playerStats.maxHP)"))
}
let hud=AwardScene();hud.playerStats.applyStatBonus(.attack);hud.playerStats.applyStatBonus(.defense);hud.statHUD.update(from:hud.playerStats)
check("actual live ATK and DEF HUD shows new totals",allLabels(hud.statHUD).contains("13") && allLabels(hud.statHUD).contains("1"))
let mixed=PlayerStats();mixed.currentHP=50
for _ in 0..<3 {mixed.applyStatBonus(.hp)}
for _ in 0..<2 {mixed.applyStatBonus(.attack)}
for _ in 0..<4 {mixed.applyStatBonus(.defense)}
check("mixed repeated awards accumulate exact shared amounts",snapshot(mixed)==[115,65,16,4])
mixed.reset();check("real run reset restores untouched starting stats",snapshot(mixed)==[100,100,10,0])
let cardFirst=AwardScene();cardFirst.levelNeedsStat=true;cardFirst.pendingLevelCard=UpgradeCardNode();cardFirst.tryCommitLevelUp()
check("card-first selection waits for stat",cardFirst.commits==0 && cardFirst.playerStats.baseAttack==10)
cardFirst.levelStatPick = .attack;cardFirst.tryCommitLevelUp()
check("card-first then stat commits once",cardFirst.commits==1 && cardFirst.playerStats.baseAttack==13)
let multiplied=AwardScene();multiplied.playerStats.damageMultiplier=2;multiplied.playerStats.applyStatBonus(.attack);multiplied.playerStats.applyStatBonus(.defense);multiplied.playerStats.fortifyOwned=true;multiplied.playerStats.updateFortify(30,hasInput:false);multiplied.statHUD.update(from:multiplied.playerStats)
check("award adds base ATK before existing multiplier",multiplied.playerStats.baseAttack==13 && multiplied.playerStats.displayAttack==26)
check("actual HUD separates base and temporary DEF",allLabels(multiplied.statHUD).contains("26") && multiplied.playerStats.temporaryDEF>0 && allLabels(multiplied.statHUD).contains("1 +\(multiplied.playerStats.temporaryDEF)"))
print("Stat awards: \(passed) passed / \(failed) failed");exit(failed==0 ? 0 : 1)
