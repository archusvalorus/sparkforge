import Foundation
// This is an explicit host scheduler, not an implementation of the lifecycle.
// Actual SpriteKit engine behavior/visuals require separate Scene/native proof.
class SKAction {
 enum Kind:Equatable {case wait,run,sequence,texture,rotate}
 let kind:Kind
 let duration:Double
 var remaining:Double
 var block:(()->Void)?
 var children:[SKAction]=[]
 var index=0
 var texture:Int=0
 var angle:Double=0
 init(_ kind:Kind,_ d:Double=0){self.kind=kind;duration=d;remaining=d}
 static func wait(forDuration d:Double)->SKAction{SKAction(.wait,d)}
 static func run(_ b:@escaping()->Void)->SKAction{let a=SKAction(.run);a.block=b;return a}
 static func sequence(_ c:[SKAction])->SKAction{let a=SKAction(.sequence,c.reduce(0){$0+$1.duration});a.children=c;return a}
 static func setTexture(_ t:Int,resize:Bool)->SKAction{let a=SKAction(.texture);a.texture=t;return a}
 static func rotate(toAngle a:Double,duration d:Double)->SKAction{let s=SKAction(.rotate,d);s.angle=a;return s}
 var lastBlock:(()->Void)? {if kind == .run{return block};return children.reversed().compactMap{$0.lastBlock}.first}
 func advance(_ n:SKNode,_ dt:Double)->(Double,Bool){
  switch kind {
  case .wait,.rotate:
   let used=min(remaining,dt);remaining-=used
   if remaining<=1e-10 {if kind == .rotate{n.zRotation=angle};return(dt-used,true)}
   return(0,false)
  case .run:let b=block;block=nil;b?();return(dt,true)
  case .texture:n.texture=texture;return(dt,true)
  case .sequence:
   var rest=dt
   while index<children.count {
    let (unused,done)=children[index].advance(n,rest)
    if !done{return(0,false)}
    index+=1;rest=unused
   }
   return(rest,true)
  }
 }
}
class SKNode {
 var isPaused=false
 var actions:[String:SKAction]=[:]
 var children:[SKNode]=[]
 weak var parent:SKNode?
 var name:String?
 var texture=0
 var zRotation:Double=0
 func addChild(_ n:SKNode){n.parent=self;children.append(n)}
 func childNode(withName name:String)->SKNode?{children.first{$0.name==name}}
 func run(_ a:SKAction,withKey key:String=UUID().uuidString){actions[key]=a}
 func action(forKey key:String)->SKAction?{actions[key]}
 func removeAction(forKey key:String){actions.removeValue(forKey:key)}
 func removeAllActions(){actions.removeAll()}
 func removeFromParent(){parent?.children.removeAll{$0 === self};parent=nil}
 func tick(_ dt:Double){
  guard !isPaused else{return}
  let snapshot=actions
  for (key,action) in snapshot.sorted(by:{$0.key<$1.key}) {
   guard !isPaused,actions[key] === action else{continue}
   let (_,done)=action.advance(self,dt)
   if done && actions[key] === action {actions.removeValue(forKey:key)}
  }
  for child in children {child.tick(dt)}
 }
}
