from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
def function(marker):
 a=s.index(marker);b=s.index('{',a);level=1;i=b+1
 while level:level+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[a:i]
f=function('    private func constrainedKaijuMove(').replace('private func','func',1)
a=s.index('        #if DEBUG\n        let lunge: SKAction',s.index('    func kaijuStrike('));b=s.index('        run(lunge, withKey: "kaijuLunge")',a)+len('        run(lunge, withKey: "kaijuLunge")')
selection=s[a:b]
out='''import Foundation
import CoreGraphics
// Host substitutes animation scheduling and Float-backed node storage only.
// Runtime action function and action selection below are extracted verbatim.
class SKNode {
 private var stored:CGPoint = .zero
 var position:CGPoint { get {stored} set {stored=CGPoint(x:CGFloat(Float(newValue.x)),y:CGFloat(Float(newValue.y)))}}
}
final class Stats {var effectiveCollisionRadius:CGFloat=10}
final class SKAction {
 let duration:TimeInterval
 var callback:((SKNode,CGFloat)->Void)?
 var children:[SKAction]=[]
 init(_ duration:TimeInterval){self.duration=duration}
 static func customAction(withDuration d:TimeInterval,actionBlock:@escaping(SKNode,CGFloat)->Void)->SKAction {let a=SKAction(d);a.callback=actionBlock;return a}
 static func sequence(_ children:[SKAction])->SKAction {let a=SKAction(children.reduce(0){$0+$1.duration});a.children=children;return a}
 static func move(by v:CGVector,duration d:TimeInterval)->SKAction {var previous:CGFloat=0;return customAction(withDuration:d){n,e in let f=min(1,max(0,e/CGFloat(d)));n.position=n.position+CGPoint(x:v.dx,y:v.dy)*(f-previous);previous=f}}
 func sample(_ node:SKNode,at elapsed:TimeInterval){
  if children.isEmpty {callback?(node,CGFloat(min(duration,max(0,elapsed))));return}
  var start:TimeInterval=0
  for child in children {if elapsed>=start {child.sample(node,at:elapsed-start)};start+=child.duration}
 }
}
final class PlayerNode:SKNode {
 var stats:Stats?=Stats()
 var debugKaijuLungeConstraint:((CGPoint,CGPoint,CGFloat)->CGPoint)?
 var active:SKAction?
 func run(_ action:SKAction,withKey key:String){precondition(key=="kaijuLunge");active=action}
'''+f+'''
 func strike(_ heading:CGPoint){let R=GameConfig.Player.visualRadius
'''+selection+'''
 }
}
'''
Path(sys.argv[2]).write_text(out)
