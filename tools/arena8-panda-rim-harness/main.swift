import Foundation
import CoreGraphics

var passed = 0, failed = 0
func check(_ name: String, _ ok: Bool) {
    if ok { passed += 1 } else { failed += 1; print("FAIL \(name)") }
}
func close(_ a: CGFloat, _ b: CGFloat, _ tolerance: CGFloat = 0.000001) -> Bool {
    abs(a - b) <= tolerance
}
// Covers wide, tall, translated and square rectangular controls.
for world in [CGRect(x:-1050,y:-660,width:2100,height:1320),
              CGRect(x:230,y:-900,width:500,height:1800),
              CGRect(x:-15,y:42,width:800,height:800)] {
    for fraction: CGFloat in [0.5, 0.98, 1] {
        let hx = world.width * fraction / 2, hy = world.height * fraction / 2
        for i in 0..<1440 {
            let angle = CGFloat(i) * 2 * .pi / 1440
            guard let p = Arena8PandaEntry.entry(in:world,angle:angle,rimFraction:fraction) else {
                check("finite-sample-produced",false);continue
            }
            let x = p.x-world.midX, y = p.y-world.midY
            let label = "\(world)-\(fraction)-\(i)"
            check(label+"-inside-rim", abs(x)<=hx+0.000001 && abs(y)<=hy+0.000001)
            check(label+"-on-rim",close(abs(x),hx) || close(abs(y),hy))
            check(label+"-same-angular-ray",close(x*sin(angle)-y*cos(angle),0))
            check(label+"-forward",x*cos(angle)+y*sin(angle)>0)
            let stored = CGPoint(x:CGFloat(Float(p.x)),y:CGFloat(Float(p.y)))
            let tolerance = max(max(abs(p.x),abs(p.y)),1) * CGFloat(Float.ulpOfOne) * 2
            check(label+"-Float-within-outer-world",stored.x >= world.minX-tolerance && stored.x <= world.maxX+tolerance && stored.y >= world.minY-tolerance && stored.y <= world.maxY+tolerance)
            check(label+"-Float-rim",abs(abs(stored.x-world.midX)-hx)<=tolerance || abs(abs(stored.y-world.midY)-hy)<=tolerance)
            let negative = Arena8PandaEntry.entry(in:world,angle:angle-2 * .pi,rimFraction:fraction)
            check(label+"-negative-angle-wrap",negative.map{close($0.x,p.x) && close($0.y,p.y)} == true)
            let wrap = Arena8PandaEntry.entry(in:world,angle:angle+2 * .pi,rimFraction:fraction)
            check(label+"-wrap",wrap.map{close($0.x,p.x) && close($0.y,p.y)} == true)
        }
        for (angle,x,y) in [(CGFloat(0),hx,CGFloat(0)),(.pi/2,0,hy),(.pi,-hx,0),(3 * .pi/2,0,-hy)] {
            let p=Arena8PandaEntry.entry(in:world,angle:angle,rimFraction:fraction)
            check("cardinal",p.map{close($0.x,world.midX+x) && close($0.y,world.midY+y)} == true)
        }
        let corner=atan2(hy,hx)
        for angle in [corner,.pi-corner,.pi+corner,2 * .pi-corner] {
            let p=Arena8PandaEntry.entry(in:world,angle:angle,rimFraction:fraction)
            check("corner",p.map{close(abs($0.x-world.midX),hx) && close(abs($0.y-world.midY),hy)} == true)
            for delta: CGFloat in [-0.00000001,0.00000001] {
                let nearby=angle+delta
                let q=Arena8PandaEntry.entry(in:world,angle:nearby,rimFraction:fraction)
                check("corner-side-perturbation",q.map{close(($0.x-world.midX)*sin(nearby)-($0.y-world.midY)*cos(nearby),0) && (close(abs($0.x-world.midX),hx) || close(abs($0.y-world.midY),hy))} == true)
            }
        }
    }
}
let rect=CGRect(x:-100,y:-50,width:200,height:100)
for angle:CGFloat in [.nan,.infinity,-.infinity] {
    check("invalid-angle",Arena8PandaEntry.entry(in:rect,angle:angle,rimFraction:0.98)==nil)
}
for fraction:CGFloat in [0,-1,1.01,.nan,.infinity] {
    check("invalid-fraction",Arena8PandaEntry.entry(in:rect,angle:0,rimFraction:fraction)==nil)
}
for world in [CGRect.zero,CGRect(x:0,y:0,width:0,height:50),CGRect(x:0,y:0,width:-100,height:50)] {
    check("degenerate-world",Arena8PandaEntry.entry(in:world,angle:0,rimFraction:0.98)==nil)
}
print("Panda rim checks: \(passed) passed / \(failed) failed")
exit(failed == 0 ? 0 : 1)
