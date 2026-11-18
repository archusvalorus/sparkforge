import Foundation
import CoreGraphics

/// Exact critical-ray partition of a vertical front against authored convex
/// rounded rectangles (core box Minkowski-summed with cornerRadius). Unlike a
/// fixed display sampling grid, no narrow shadow/opening is skipped.
enum RainbowVisibility {
    static func intervals(x:CGFloat,minY:CGFloat,maxY:CGFloat,origin:CGPoint,
                          geometry:ArenaGeometry,passesWalls:Bool)->[ClosedRange<CGFloat>] {
        guard minY<maxY else{return []}
        if passesWalls || geometry.blockedFootprints.isEmpty {return [minY...maxY]}
        let dx=x-origin.x,epsilon:CGFloat=1e-9
        var cuts=[minY,maxY]
        func cut(_ y:CGFloat) {if y.isFinite && y>minY && y<maxY {cuts.append(y)}}
        for footprint in geometry.blockedFootprints {
            let hx=footprint.halfExtents.width,hy=footprint.halfExtents.height,r=max(0,footprint.cornerRadius)
            func world(_ p:CGPoint)->CGPoint {footprint.center+p.rotated(by:footprint.rotation)}
            func project(_ q:CGPoint) {
                if abs(dx)<epsilon {if abs(q.x-x)<epsilon {cut(q.y)};return}
                let t=(q.x-origin.x)/dx
                guard t>0 && t<=1+epsilon else{return}
                cut(origin.y+(q.y-origin.y)/t)
            }
            let segments=[(CGPoint(x:-hx,y:hy+r),CGPoint(x:hx,y:hy+r)),
                          (CGPoint(x:-hx,y:-hy-r),CGPoint(x:hx,y:-hy-r)),
                          (CGPoint(x:hx+r,y:-hy),CGPoint(x:hx+r,y:hy)),
                          (CGPoint(x:-hx-r,y:-hy),CGPoint(x:-hx-r,y:hy))]
            for (localA,localB) in segments {
                let a=world(localA),b=world(localB);project(a);project(b)
                for plane in [origin.x,x] {
                    if abs(b.x-a.x)>epsilon {
                        let t=(plane-a.x)/(b.x-a.x)
                        if t>=0 && t<=1 {project(a.lerp(to:b,t:t))}
                    } else if abs(a.x-plane)<epsilon {project(a);project(b)}
                }
            }
            guard r>0 else{continue}
            for sx in [CGFloat(-1),CGFloat(1)] {for sy in [CGFloat(-1),CGFloat(1)] {
                let center=world(CGPoint(x:sx*hx,y:sy*hy))
                func arcPoint(_ q:CGPoint) {
                    let local=(q-center).rotated(by:-footprint.rotation)
                    guard sx*local.x>=(-epsilon) && sy*local.y>=(-epsilon) else{return}
                    project(q)
                }
                // Extrema of perspective slope on an arc are its junctions,
                // origin tangents, or intersections with the origin/front slab.
                let relative=origin-center,distance=relative.length
                if distance>r {
                    let angle=atan2(relative.y,relative.x),offset=acos(min(1,r/distance))
                    for t in [angle-offset,angle+offset] {
                        arcPoint(center+CGPoint(x:cos(t)*r,y:sin(t)*r))
                    }
                }
                for plane in [origin.x,x] {
                    let across=plane-center.x
                    if abs(across)<=r {
                        let up=sqrt(max(0,r*r-across*across))
                        arcPoint(CGPoint(x:plane,y:center.y+up));arcPoint(CGPoint(x:plane,y:center.y-up))
                    }
                }
            }}
        }
        if abs(dx)<epsilon {cut(origin.y)}
        cuts.sort()
        var unique:[CGFloat]=[]
        for y in cuts {if unique.last != y {unique.append(y)}}
        var result:[ClosedRange<CGFloat>]=[]
        for i in 1..<unique.count {
            let low=unique[i-1],high=unique[i]
            guard high>low else{continue}
            // Analytic critical rays bound every LOS change. The predicate is
            // shared with gameplay; this is interval classification, not a grid.
            let middle=low+(high-low)/2
            if !geometry.segmentBlockedExact(origin,CGPoint(x:x,y:middle)) {
                var visibleLow=low,visibleHigh=high
                if geometry.segmentBlockedExact(origin,CGPoint(x:x,y:low)) {
                    var blocked=low,clear=middle
                    for _ in 0..<GameConfig.RainbowRuntime.contactSearchSteps {
                        let point=blocked+(clear-blocked)/2
                        if geometry.segmentBlockedExact(origin,CGPoint(x:x,y:point)) {blocked=point} else {clear=point}
                    }
                    visibleLow=clear
                }
                if geometry.segmentBlockedExact(origin,CGPoint(x:x,y:high)) {
                    var clear=middle,blocked=high
                    for _ in 0..<GameConfig.RainbowRuntime.contactSearchSteps {
                        let point=clear+(blocked-clear)/2
                        if geometry.segmentBlockedExact(origin,CGPoint(x:x,y:point)) {blocked=point} else {clear=point}
                    }
                    visibleHigh=clear
                }
                if let previous=result.last,previous.upperBound==visibleLow {
                    result[result.count-1]=previous.lowerBound...visibleHigh
                } else {result.append(visibleLow...visibleHigh)}
            }
        }
        return result
    }
}
