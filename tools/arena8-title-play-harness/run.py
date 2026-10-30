#!/usr/bin/env python3
"""Execute actual Title transition and actual isolation predicate; no app/device."""
from pathlib import Path
import subprocess,tempfile,os
root=Path(__file__).resolve().parents[2]
def member(source,marker):
 assert source.count(marker)==1
 start=source.index(marker);brace=source.index('{',start);end=brace+1;depth=1
 while depth:depth+=(source[end]=='{')-(source[end]=='}');end+=1
 return source[start:end]
scene=Path(os.environ.get('SPARKFORGE_A8_TITLE_SCENE_PATH',str(root/'Sparkforge/Scenes/TitleScene.swift'))).read_text()
prefs=(root/'Sparkforge/Systems/GameRunPreferences.swift').read_text()
transition=member(scene,'    private func transitionToGame()').replace('private func','func',1).replace('ProcessInfo.processInfo.arguments','TestArgs.values')
bootstrap=Path(os.environ.get('SPARKFORGE_A8_TITLE_CONTROLLER_PATH',str(root/'Sparkforge/GameViewController.swift'))).read_text()
start=bootstrap.index('            #if DEBUG\n            if ProcessInfo.processInfo.arguments.contains("--rainbow-p1")')
end=bootstrap.index('        case .failure',start)
startup=bootstrap[start:end].replace('ProcessInfo.processInfo.arguments','TestArgs.values')
isolated=member(prefs,'    static var isIsolated: Bool').replace('ProcessInfo.processInfo.arguments','TestArgs.values')
shell='''import Foundation
import CoreGraphics
enum TestArgs {static var values:[String]=[]}
enum Floor:Equatable {case sixRoom,twoRoom,arena9}
enum GameConfig {enum Arena9TraversalLab {static let map:Floor? = .arena9}}
enum Scale:Equatable {case resizeFill}
class SKScene {
 let size:CGSize;var scaleMode:Scale = .resizeFill;var anchorPoint=CGPoint.zero
 init(size:CGSize){self.size=size}
}
final class GameScene:SKScene {var debugRoomIntegration:Floor?;var debugRoomEntryFromTitle=false;var debugArena9Traversal=false}
final class RainbowP1Scene:SKScene{}
final class Arena8P0Scene:SKScene{}
final class Arena8CombatScene:SKScene{}
final class SKTransition {let duration:Double;init(_ d:Double){duration=d};static func fade(with:Color,duration:Double)->SKTransition{SKTransition(duration)}}
enum Color {case black}
final class View {let bounds=CGRect(x:0,y:0,width:393,height:852);var presented:GameScene?;var duration:Double=0
 func presentScene(_ s:GameScene,transition:SKTransition){presented=s;duration=transition.duration}}
enum GameRunPreferences {
PREFS
}
final class TitleScene:SKScene {
 var view:View?
TRANSITION
}
func launchScene()->SKScene {
 let skView=View()
 let scene:SKScene
STARTUP
 return scene
}
var passed=0,failed=0
func check(_ name:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL \\(name)")}}
let flags=["--arena9-traversal","--arena8-six","--arena8-game","--arena8-title","--arena8-title-input","--arena8-title-autoplay","--rainbow-p1","--arena8-p0","--arena8-combat"]
for mask in 0..<(1<<flags.count) {
 TestArgs.values=flags.enumerated().filter{mask & (1<<$0.offset) != 0}.map(\\.element)
 let title=TitleScene(size:CGSize(width:393,height:852)),view=View();title.view=view;title.transitionToGame()
 guard let game=view.presented else{check("actual-transition-presented",false);continue}
 #if DEBUG
 let expected:Floor?=TestArgs.values.contains("--arena9-traversal") ? .arena9 : (TestArgs.values.contains("--arena8-six") ? .sixRoom : (TestArgs.values.contains("--arena8-game") ? .twoRoom : nil))
 #else
 let expected:Floor?=nil
 #endif
 check("actual-transition-room-selection",game.debugRoomIntegration==expected)
 check("origin-marker-only-isolated-campaign",game.debugRoomEntryFromTitle==(expected != nil))
 check("normal-view-size-scale-anchor-transition",game.size==view.bounds.size && game.scaleMode == .resizeFill && game.anchorPoint==CGPoint(x:0.5,y:0.5) && view.duration==0.3)
 let previous=game;title.transitionToGame();check("ordinary-play-creates-fresh-scene",view.presented !== previous && view.presented?.debugRoomIntegration==expected)
 let detached=TitleScene(size:view.bounds.size);detached.transitionToGame();check("detached-title-does-not-present",detached.view==nil)
 let startup=launchScene()
 #if DEBUG
 if TestArgs.values.contains("--rainbow-p1"){check("preserve-Rainbow-startup-priority",startup is RainbowP1Scene)}
 else if TestArgs.values.contains("--arena8-p0"){check("preserve-P0-startup-priority",startup is Arena8P0Scene)}
 else if TestArgs.values.contains("--arena8-combat"){check("preserve-combat-startup-priority",startup is Arena8CombatScene)}
 else if expected != nil && !TestArgs.values.contains("--arena8-title"){check("existing-room-starts-direct",(startup as? GameScene)?.debugRoomIntegration==expected)}
 else{check("only-isolated-title-option-or-normal-title",startup is TitleScene)}
 #else
 check("Release-always-starts-normal-title",startup is TitleScene)
 #endif
}
print("Title routing checks: \\(passed) passed / \\(failed) failed")
exit(failed==0 ? 0 : 1)
'''.replace('PREFS',isolated).replace('TRANSITION',transition).replace('STARTUP',startup)
with tempfile.TemporaryDirectory(prefix='sf-arena8-title-') as temp:
 out=Path(temp);source=out/'main.swift';source.write_text(shell)
 for config in ['Debug','Release']:
  binary=out/config;cmd=['swiftc','-module-cache-path',str(out/'cache'),'-O']
  if config=='Debug':cmd+=['-DDEBUG']
  subprocess.run(cmd+['-o',str(binary),str(source)],check=True)
  print(config,flush=True);subprocess.run([str(binary)],check=True)
