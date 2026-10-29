import Foundation
import CoreGraphics
var passed=0,failed=0
func check(_ id:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL \(id)")}}
func clock(_ s:GameScene,_ n:PandaNode)->SKAction?{guard let e=s.avalancheEntrances[ObjectIdentifier(n)] else{return nil};return n.action(forKey:e.clockKey)}
func fixture(_ delay:Double=0.3)->(GameScene,PandaNode){let s=GameScene();s.spawnAvalanchePanda(at:CGPoint(x:20,y:30),heading:CGPoint(x:1,y:0),delay:delay);return(s,s.pandas[0].node)}
let holds:[GameScene.GameState]=[.paused,.levelUp,.removeAdsPrompt,.synergyReveal,.placingZone,.bossReveal]
for elapsed in [0.0,0.1,0.31,0.4] {
 for state in holds {
  let (s,n)=fixture();let pos=n.position;let timer=s.pandas[0].timer
  s.tick(elapsed);s.hostGuardTick(0.1)
  check("pending-blocks-combat-and-timer",s.hostCombatSteps==0 && s.pandas[0].timer==timer && n.position==pos && n.rollStarts==0)
  s.gameState=state;let alpha=n.alpha;s.tick(2);s.hostGuardTick(0.1)
  check("hold-freezes-entrance",n.alpha==alpha && n.rollStarts==0 && s.pandas[0].avalancheWaiting)
  s.gameState = .playing;check("hold-resume-not-synchronous",n.rollStarts==0)
  s.tick(0.45-elapsed-0.001);check("remaining-delay-and-fade-retained",n.rollStarts==0 && s.pandas[0].avalancheWaiting)
  s.tick(0.002);check("full-alpha-activates-once",n.alpha==1 && n.rollStarts==1 && !s.pandas[0].avalancheWaiting && s.avalancheEntrances.isEmpty)
  check("activation-full-combat-timer",s.pandas[0].timer==timer)
  s.hostGuardTick(0.1);check("active-can-enter-combat",s.hostCombatSteps==1 && abs(s.pandas[0].timer-(timer-0.1))<0.00001)
  s.tick(3);check("one-roll-start-only",n.rollStarts==1)
 }
}
// Actual wait -> partial fade -> full opacity with no premature active seat.
do {
 let (s,n)=fixture();s.tick(0.3);check("delay-keeps-alpha-zero",n.alpha==0 && n.rollStarts==0)
 s.tick(0.075);check("partial-fade-not-active",n.alpha>0 && n.alpha<1 && s.pandas[0].avalancheWaiting && n.rollStarts==0)
 s.hostGuardTick(0.2);check("partial-fade-no-combat",s.hostCombatSteps==0)
 s.tick(0.075);check("fade-end-activates",n.alpha==1 && n.rollStarts==1)
}
// Ready event forced during hold must retain ready state and await action phase.
for state in holds {
 let (s,n)=fixture();let due=clock(s,n)?.lastBlock
 s.gameState=state;n.alpha=1;due?()
 check("ready-held-keeps-waiting",n.rollStarts==0 && s.pandas[0].avalancheWaiting && s.avalancheEntrances[ObjectIdentifier(n)]?.ready==true)
 s.gameState = .playing;check("ready-not-in-state-setter",n.rollStarts==0)
 s.tick(0);check("ready-actionphase-once",n.rollStarts==1 && !s.pandas[0].avalancheWaiting)
 due?();s.tick(1);check("old-delivery-after-active-inert",n.rollStarts==1)
}
// Independent background hold survives modal dismissal and repeated state changes.
do {
 let (s,n)=fixture();s.tick(0.1);s.gameState = .levelUp;s.avalancheBackgroundHold=true;s.syncAvalancheEntrances();s.gameState = .playing;s.tick(2)
 check("background-retained-after-modal-dismissal",n.isPaused && n.alpha==0 && n.rollStarts==0)
 s.avalancheBackgroundHold=false;s.syncAvalancheEntrances();s.tick(0.349);check("background-resume-keeps-remaining",n.rollStarts==0);s.tick(0.002);check("background-resume-activates",n.rollStarts==1)
 let (a,b)=fixture();a.gameState = .paused;a.avalancheBackgroundHold=true;a.syncAvalancheEntrances();a.avalancheBackgroundHold=false;a.syncAvalancheEntrances();a.syncAvalancheEntrances();a.tick(1)
 check("foreground-does-not-clear-modal",b.isPaused && b.rollStarts==0)
}
// Existing own and ancestor pauses remain their owners' decisions.
for cancel in [false,true] {
 let (s,n)=fixture();n.isPaused=true;s.gameState = .paused;s.gameState = .playing
 check("prior-pause-preserved",n.isPaused)
 if cancel{s.cancelAvalancheEntrances();check("cancel-restores-prior-pause",n.isPaused && s.pandas.isEmpty)}
 else {s.tick(2);check("prior-pause-blocks-entrance",n.rollStarts==0);n.isPaused=false;s.syncAvalancheEntrances();s.tick(0.45);check("owner-unpause-allows-activation",n.rollStarts==1)}
}
do {let (s,n)=fixture();s.worldNode.isPaused=true;s.gameState = .paused;s.gameState = .playing;s.tick(2);check("ancestor-pause-preserved",s.worldNode.isPaused && !n.isPaused && n.rollStarts==0);s.worldNode.isPaused=false;s.tick(0.45);check("ancestor-unpause-allows-activation",n.rollStarts==1)}
// Dead/revive, reset/Title cancellation seam, explicit action removal and detach.
for terminal in 0..<7 {
 for ready in [false,true] {
  let (s,n)=fixture();let due=clock(s,n)?.lastBlock
  s.gameState = .paused;if ready{n.alpha=1;due?()}
  switch terminal {
  case 0:s.gameState = .dead
  case 1:s.gameState = .reviving
  case 2:s.cancelAvalancheEntrances()
  case 3:n.removeAllActions();s.syncAvalancheEntrances()
  case 4:n.removeFromParent();s.syncAvalancheEntrances()
  case 5:s.view?.scene=nil;s.syncAvalancheEntrances()
  default:s.pandas.removeAll();s.syncAvalancheEntrances()
  }
  check("terminal-clears-entry-actions-pause-\(terminal)-\(ready)",s.avalancheEntrances.isEmpty && n.actions.isEmpty && (terminal==4 || terminal==6 || !n.isPaused))
  if terminal==6{check("removed-membership-node-not-orphaned",n.parent==nil)}
  check("terminal-frees-population-seat-\(terminal)-\(ready)",s.pandas.isEmpty || terminal==4)
  s.gameState = .playing;due?();s.tick(2);check("terminal-stale-callback-inert-\(terminal)-\(ready)",n.rollStarts==0)
 }
}
// Old token cannot start a replacement entrance on the same node.
do {
 let (s,n)=fixture();let old=clock(s,n)?.lastBlock
 s.scheduleAvalancheEntrance(n,delay:0.6);n.alpha=1;old?();check("stale-token-does-not-ready-replacement",s.avalancheEntrances[ObjectIdentifier(n)]?.ready==false && n.rollStarts==0)
 n.alpha=0;s.tick(0.45);check("replacement-keeps-new-delay",n.rollStarts==0);s.tick(0.3);check("replacement-completes-once",n.rollStarts==1)
}
// Ready but partial alpha cannot become combat-active.
do {let (s,n)=fixture();let due=clock(s,n)?.lastBlock;n.alpha=0.5;due?();check("ready-cannot-activate-before-full-opacity",n.rollStarts==0 && s.pandas.isEmpty);n.removeAllActions();s.syncAvalancheEntrances();check("ready-partial-alpha-cleanup",s.avalancheEntrances.isEmpty && s.pandas.isEmpty)}
// Population cap includes seats waiting for entrance and existing actors.
for occupied in 0...6 {
 let s=GameScene()
 for _ in 0..<occupied {let n=PandaNode();s.worldNode.addChild(n);s.pandas.append(GameScene.Panda(node:n,act:.other,phase:.acting,timer:3,destination:.zero))}
 for _ in 0..<3{s.spawnAvalanchePanda(at:.zero,heading:CGPoint(x:1,y:0),delay:0.3)}
 check("cap-counts-waiting-seats",s.pandas.count==min(6,occupied+3) && s.worldNode.children.count==s.pandas.count)
 s.cancelAvalancheEntrances();check("cancel-only-waiting-seats",s.pandas.count==occupied && s.worldNode.children.count==occupied)
}
// Removing a prior Scene's entry must not erase a new Scene's node ownership.
do {
 let (old,n)=fixture();old.gameState = .paused;let stale=clock(old,n)?.lastBlock
 let fresh=GameScene();fresh.worldNode.addChild(n);fresh.pandas.append(GameScene.Panda(node:n,act:.roll,phase:.acting,timer:3.5,destination:.zero,avalancheWaiting:true));fresh.scheduleAvalancheEntrance(n,delay:0.5)
 let action=clock(fresh,n);let paused=n.isPaused
 old.syncAvalancheEntrances();check("old-scene-cannot-remove-new-entrance",clock(fresh,n) === action && n.isPaused==paused)
 stale?();check("old-scene-callback-does-not-activate-new-seat",n.rollStarts==0 && fresh.pandas[0].avalancheWaiting)
}
// Removing a visitor's registration/reusing it must not remove non-waiting actor.
do {let (s,n)=fixture();s.gameState = .paused;s.pandas[0].avalancheWaiting=false;s.pandas[0].act = .other;s.syncAvalancheEntrances();check("reused-active-visitor-not-removed",n.parent === s.worldNode && s.pandas.count==1 && s.avalancheEntrances.isEmpty && !n.isPaused)}
// Replacing an entrance on the same held node must transfer its original pause.
do {let (s,n)=fixture();s.gameState = .paused;s.scheduleAvalancheEntrance(n,delay:0.4);s.gameState = .playing;check("held-replacement-keeps-original-pause",!n.isPaused);s.tick(0.55);check("held-replacement-can-complete",n.rollStarts==1)}
print("\(passed) passed / \(failed) failed")
exit(failed==0 ? 0:1)
