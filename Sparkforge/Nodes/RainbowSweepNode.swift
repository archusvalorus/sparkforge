import SpriteKit

/// Fixed reusable artwork. Only the leading edge represents contact;
/// bands and SUPER! are trailing decoration and create no hit callbacks.
final class RainbowSweepNode: SKNode {
    private let guide=SKShapeNode()
    private let edge=SKShapeNode()
    private let text=SKLabelNode(fontNamed:"AvenirNext-Heavy")
    private var bands:[SKShapeNode]=[]
    override init() {
        super.init();zPosition=18
        for color in GameConfig.RainbowRuntime.colors {
            let band=SKShapeNode();band.fillColor=SKColor(hex:color,alpha:0.66)
            band.strokeColor = .clear;addChild(band);bands.append(band)
        }
        guide.strokeColor=SKColor(hex:0xFFE99B,alpha:0.6)
        guide.fillColor=SKColor(hex:0xA837EE,alpha:0.08);guide.lineWidth=2;addChild(guide)
        edge.strokeColor = .white;edge.lineWidth=2;edge.glowWidth=3;edge.zPosition=2;addChild(edge)
        text.text="SUPER!";text.fontSize=44;text.fontColor = .white
        text.verticalAlignmentMode = .center;text.zPosition=3;addChild(text)
        clear()
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    func clear() { guide.isHidden=true;edge.isHidden=true;text.isHidden=true;bands.forEach{$0.isHidden=true} }
    func render(_ model:RainbowSweep,viewport:CGRect,origin:CGPoint,board:CGRect,geometry:ArenaGeometry) {
        guard model.owned else{clear();return}
        guide.isHidden = !model.warning || !model.holds.isEmpty
        if !guide.isHidden {
            let area=RainbowSweep.laneFootprint(viewport:viewport,origin:origin,board:board)
            guide.path=area.isNull || area.isEmpty ? nil:CGPath(rect:area,transform:nil)
            guide.alpha=0.5+CGFloat(sin(model.elapsed*12))*0.2
        }
        guard let sweep=model.sweep else {
            edge.isHidden=true;text.isHidden=true;bands.forEach{$0.isHidden=true};return
        }
        edge.isHidden=false;text.isHidden=false
        let x=sweep.frontX,area=sweep.footprint
        let path=CGMutablePath()
        for interval in RainbowVisibility.intervals(x:x,minY:area.minY,maxY:area.maxY,
                origin:sweep.origin,geometry:geometry,passesWalls:sweep.attacker.longShotT4) {
            path.move(to:CGPoint(x:x,y:interval.lowerBound))
            path.addLine(to:CGPoint(x:x,y:interval.upperBound))
        }
        edge.path=path
        let width=min(GameConfig.RainbowRuntime.trailLength,max(0,x-area.minX))
        for (index,band) in bands.enumerated() {
            band.isHidden=false
            band.path=CGPath(rect:CGRect(x:x-width,y:area.minY+area.height*CGFloat(index)/CGFloat(bands.count),
                                        width:width,height:area.height/CGFloat(bands.count)),transform:nil)
        }
        text.position=CGPoint(x:x-min(GameConfig.RainbowRuntime.trailLength/2,width/2),y:area.midY)
    }
}
