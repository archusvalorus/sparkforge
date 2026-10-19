import SpriteKit
struct Insets {var top:CGFloat=0,bottom:CGFloat=0,left:CGFloat=0,right:CGFloat=0;static let zero=Insets()}
final class ProbeView {var safeAreaInsets=Insets()}
enum DeviceScale {static var isIPad=false}
final class MenuProbe:SKNode {
    // SCENE_MEMBERS
 var size=CGSize(width:375,height:812)
 var view:ProbeView?=ProbeView()
 var layoutY:CGFloat=0
 var titleLabel=SKLabelNode(fontNamed:"Menlo-Bold"),subtitleLabel=SKLabelNode(fontNamed:"Menlo"),tapPrompt=SKLabelNode(fontNamed:"Menlo")
 var menuScrollNodes:[(node:SKNode,baseY:CGFloat)]=[]
 var menuContentTopY:CGFloat=0,menuContentBottomY:CGFloat=0,menuScrollOffset:CGFloat=0
 var startCalls=0
 func startGame(){startCalls+=1}
 func buildTop(){layoutY=min(size.height*0.30,280);setupTitle();setupTapPrompt()}
}
extension CGPoint {var length:CGFloat{hypot(x,y)}}
