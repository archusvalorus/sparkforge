import Foundation
var passed=0,failed=0
func check(_ id:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL \(id)")}}
func fixture(art:Bool=true)->(GameScene,PandaNode){
 let scene=GameScene(),node=PandaNode()
 if art {let sprite=SKNode();node.sprite=sprite;node.strikeFrames=[1,2,3];node.addChild(sprite)}
 else {let sword=SKNode();sword.name="sword";node.addChild(sword)}
 scene.attach(node);return(scene,node)
}
let holds:[GameScene.GameState]=[.paused,.levelUp,.removeAdsPrompt,.synergyReveal,.placingZone,.bossReveal]
for art in [true,false] {
 for hold in holds {
  for elapsed in [0.0,0.05,0.15,0.30] {
   let (scene,node)=fixture(art:art);var hits=0
   node.strike{hits+=1};scene.syncSamuraiStrike(node);scene.tick(elapsed)
   check("not-before-windup",hits==0)
   scene.gameState=hold;let texture=node.sprite?.texture,angle=node.childNode(withName:"sword")?.zRotation
   scene.tick(2);scene.syncSamuraiStrikes();scene.tick(2)
   check("hold-blocks-hit",hits==0 && node.hasPendingStrike)
   check("hold-freezes-visual",node.sprite?.texture==texture && node.childNode(withName:"sword")?.zRotation==angle)
   scene.gameState = .playing
   check("resume-not-synchronous",hits==0)
   let remaining=0.4-elapsed;scene.tick(remaining-0.001)
   check("remaining-time-not-restarted-or-skipped",hits==0)
   scene.tick(0.002);check("remaining-time-single-impact",hits==1 && !node.hasPendingStrike)
   scene.tick(5);check("no-repeat-impact",hits==1)
  }
 }
}
for art in [true,false] {
 let (scene,node)=fixture(art:art);var hits=0
 node.strike{hits+=1};scene.syncSamuraiStrike(node);scene.tick(0.1)
 scene.gameState = .levelUp;scene.appDidEnterBackground();scene.gameState = .playing
 scene.tick(2);check("background-independent-of-modal-dismissal",hits==0 && node.hasPendingStrike && node.isPaused)
 scene.appWillEnterForeground();scene.tick(0.29);check("overlap-retains-remaining",hits==0);scene.tick(0.02);check("overlap-resume-once",hits==1)
 // Repeated notifications preserve the original flag and remaining clock.
 let (s,n)=fixture(art:art);var count=0;n.strike{count+=1};s.tick(0.12)
 s.gameState = .paused;s.appDidEnterBackground();s.appDidEnterBackground();s.appWillEnterForeground();s.appWillEnterForeground();s.tick(1)
 check("foreground-does-not-clear-modal",count==0 && n.isPaused)
 s.gameState = .playing;s.tick(0.27);check("repeated-holds-remaining",count==0);s.tick(0.02);check("repeated-holds-one-hit",count==1)
}
for art in [true,false] {
 let (scene,node)=fixture(art:art);var hits=0
 node.strike{hits+=1};let due=node.action(forKey:"samuraiImpact")?.lastBlock
 scene.gameState = .paused;due?();check("due-held-retains-ready",hits==0 && node.hasPendingStrike && node.pendingStrikeReady)
 scene.gameState = .playing;check("due-resume-not-synchronous",hits==0)
 scene.tick(0);check("due-resume-actionphase-once",hits==1 && !node.hasPendingStrike);due?();scene.tick(1);check("due-old-clock-inert",hits==1)
}
for terminal in [GameScene.GameState.dead,.reviving] {
 for ready in [false,true] {
  let (scene,node)=fixture();var hits=0;node.strike{hits+=1};let old=node.action(forKey:"samuraiImpact")?.lastBlock
  scene.gameState = .paused;if ready{old?()};scene.gameState=terminal
  check("terminal-cancels-pending",!node.hasPendingStrike && !node.isPaused)
  scene.gameState = .playing;old?();scene.tick(2);check("terminal-no-post-revive-hit",hits==0)
 }
}
for cleanup in 0..<3 {
 let (scene,node)=fixture();var hits=0;node.strike{hits+=1};let old=node.action(forKey:"samuraiImpact")?.lastBlock;scene.gameState = .paused;old?()
 if cleanup==0{scene.cancelSamuraiStrikes()}else if cleanup==1{node.removeFromParent()}else{node.removeAllActions()}
 check("cleanup-clears-owned-pause-and-pending",!node.hasPendingStrike && !node.isPaused)
 scene.gameState = .playing;old?();node.tick(2);check("cleanup-old-callback-inert",hits==0)
}
// A fresh strike must survive an old queued token.
do {
 let (scene,node)=fixture();var oldHits=0,newHits=0
 node.strike{oldHits+=1};let old=node.action(forKey:"samuraiImpact")?.lastBlock
 scene.tick(0.1);node.strike{newHits+=1};scene.syncSamuraiStrike(node);old?()
 check("old-token-cannot-hit-new-strike",oldHits==0 && newHits==0 && node.hasPendingStrike)
 scene.tick(0.39);check("replacement-full-windup",newHits==0);scene.tick(0.02);check("replacement-one-hit",oldHits==0 && newHits==1)
}
// Reentrant external completion starts a fresh pending strike on the same node.
do {
 let (scene,node)=fixture();var hits=0
 node.strike{hits+=1;node.strike{hits+=1};scene.syncSamuraiStrike(node)}
 scene.tick(0.4);check("clear-before-callback-preserves-reentrant-strike",hits==1 && node.hasPendingStrike)
 scene.tick(0.39);check("reentrant-strike-not-early",hits==1);scene.tick(0.02);check("reentrant-strike-delivers",hits==2)
}
// A first ready visitor opens a new modal; the second must stay held.
for terminal in [false,true] {
 let (scene,first)=fixture();let second=PandaNode();scene.attach(second);var a=0,b=0
 first.strike{a+=1;scene.gameState = terminal ? .dead:.levelUp};second.strike{b+=1}
 let dueA=first.action(forKey:"samuraiImpact")?.lastBlock,dueB=second.action(forKey:"samuraiImpact")?.lastBlock
 scene.gameState = .paused;dueA?();dueB?();scene.gameState = .playing;scene.tick(0)
 check("ready-batch-rechecks-holds",a==1 && b==0)
 if terminal {check("ready-batch-terminal-cancels-second",!second.hasPendingStrike)}
 else {check("ready-batch-modal-keeps-second",second.hasPendingStrike);scene.gameState = .playing;scene.tick(0);check("second-resumes-once",b==1)}
}
// Prior own pause must not be overwritten, including cancellation.
for cancel in [false,true] {
 let (scene,node)=fixture();var hits=0;node.isPaused=true;node.strike{hits+=1};scene.gameState = .paused
 scene.gameState = .playing;check("prior-pause-restored",node.isPaused)
 if cancel {node.cancelPendingStrike();check("cancel-preserves-prior-pause",node.isPaused && !node.hasPendingStrike)}
 else {scene.tick(2);check("prior-pause-blocks",hits==0);node.isPaused=false;scene.syncSamuraiStrikes();scene.tick(0.4);check("owner-unpause-delivers",hits==1)}
}
// A non-Samurai action is never paused/canceled by Samurai policy.
do {
 let (scene,node)=fixture();let other=PandaNode();scene.attach(other,act:.other);var events=0;other.run(.sequence([.wait(forDuration:0.1),.run{events+=1}]),withKey:"ordinary")
 node.strike{};scene.gameState = .paused;scene.tick(0.2);check("other-Panda-actions-retained",events==1 && !other.isPaused)
}
print("\(passed) passed / \(failed) failed")
exit(failed==0 ? 0:1)
