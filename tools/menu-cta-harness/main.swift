import SpriteKit
import Metal
import ImageIO
import UniformTypeIdentifiers
var passed=0,failed=0
func check(_ name:String,_ ok:Bool){if ok{passed+=1;print("PASS MENU \(name)")}else{failed+=1;print("FAIL MENU \(name)")}}
func isWhite(_ c:SKColor?)->Bool {guard let c=c?.usingColorSpace(.sRGB) else{return false};return abs(c.redComponent-1)<0.001 && abs(c.greenComponent-1)<0.001 && abs(c.blueComponent-1)<0.001 && abs(c.alphaComponent-1)<0.001}
func render(_ probe:MenuProbe,to url:URL,scale:CGFloat)->Bool {
 guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue(),let buffer=queue.makeCommandBuffer() else{return false}
 let width=Int(probe.size.width*scale),height=Int(probe.size.height*scale)
 let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:width,height:height,mipmapped:false);desc.usage=[.renderTarget,.shaderRead];desc.storageMode = .shared
 guard let texture=device.makeTexture(descriptor:desc) else{return false}
 let scene=SKScene(size:probe.size);scene.anchorPoint=CGPoint(x:0.5,y:0.5);scene.scaleMode = .aspectFit;scene.backgroundColor = .black;scene.addChild(probe)
 let renderer=SKRenderer(device:device);renderer.scene=scene;renderer.update(atTime:0)
 let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=texture;pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store;pass.colorAttachments[0].clearColor=MTLClearColorMake(0,0,0,1)
 renderer.render(withViewport:CGRect(x:0,y:0,width:width,height:height),commandBuffer:buffer,renderPassDescriptor:pass);buffer.commit();buffer.waitUntilCompleted()
 var bytes=[UInt8](repeating:0,count:width*height*4);texture.getBytes(&bytes,bytesPerRow:width*4,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)
 let data=Data(bytes);guard let provider=CGDataProvider(data:data as CFData),let image=CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent),let dest=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil) else{return false}
 CGImageDestinationAddImage(dest,image,nil);let ok=CGImageDestinationFinalize(dest);probe.removeFromParent();return ok
}
let cases:[(String,CGFloat,CGFloat,Bool,Insets)] = [
 ("small-phone",320,568,false,Insets(top:20,bottom:0)),("phone",375,812,false,Insets(top:44,bottom:34)),("phone-large",430,932,false,Insets(top:59,bottom:34)),("phone-asymmetric",375,812,false,Insets(top:44,bottom:34,left:44,right:0)),("ipad",768,1024,true,Insets(top:24,bottom:20)),("ipad-large",1024,1366,true,Insets(top:24,bottom:20)),("ipad-landscape",1024,768,true,Insets(top:24,bottom:20,left:0,right:0)),("ipad-split",375,1024,true,Insets(top:24,bottom:20))]
for (name,w,h,pad,insets) in cases {
 DeviceScale.isIPad=pad
 let p=MenuProbe();p.size=CGSize(width:w,height:h);p.view?.safeAreaInsets=insets;p.buildTop()
 guard let box=p.childNode(withName:"ignitePromptBox") as? SKShapeNode else{check("primary exists \(name)",false);continue}
 let bounds=box.frame
 check("primary stays inside horizontal safe width \(name)",bounds.minX>=(-w/2+insets.left) && bounds.maxX<=w/2-insets.right)
 check("primary initially visible without scroll \(name)",bounds.maxY<h/2-insets.top && bounds.minY > -h/2+insets.bottom)
 check("primary larger than secondary42pt controls \(name)",bounds.height>42 && bounds.width*bounds.height>312*42)
 check("PLAY NOW legible opaque white nonitalic \(name)",p.tapPrompt.text=="PLAY NOW!" && p.tapPrompt.fontName=="Menlo-Bold" && p.tapPrompt.alpha==1 && isWhite(p.tapPrompt.fontColor) && p.tapPrompt.fontSize>=30)
 check("lettering fits blue face \(name)",p.tapPrompt.calculateAccumulatedFrame().width<bounds.width-24 && p.tapPrompt.frame.height<bounds.height-16)
 let edges=p.tapPrompt.children.compactMap{$0 as? SKLabelNode}
 check("eight restrained gold edges preserve white face \(name)",edges.count==8 && edges.allSatisfy{$0.text=="PLAY NOW!" && $0.name=="playGoldEdge" && $0.zPosition<0 && $0.position.length<=1.01})
 check("static CTA never dims \(name)",!box.hasActions() && !p.tapPrompt.hasActions())
 check("subtitle clearance \(name)",bounds.maxY<p.subtitleLabel.frame.minY-10)
 p.tapPlay(at:box.position);check("same start dispatch \(name)",p.startCalls==1)
 p.tapPlay(at:CGPoint(x:bounds.maxX+30,y:bounds.midY));check("empty space still does not start \(name)",p.startCalls==1)
 p.tapPlay(at:CGPoint(x:bounds.minX+1,y:bounds.minY+1));check("enlarged face remains hittable \(name)",p.startCalls==2)
 // Existing scrolling moves the complete letter stack and hit target together.
 let last=SKNode();last.position=CGPoint(x:0,y:-h);last.zPosition=10;p.addChild(last)
 let gear=SKNode();gear.name="settingsGearButton";gear.zPosition=30;gear.position=CGPoint(x:w/2-30,y:h/2-50);p.addChild(gear)
 p.buildMenuScrollSet(topInset:insets.top,bottomInset:insets.bottom);let original=box.position
 p.menuScrollOffset=p.clampedMenuOffset(100000);p.applyMenuScroll()
 check("scroll retains gold/white alignment \(name)",p.tapPrompt.position==box.position && edges.allSatisfy{$0.parent === p.tapPrompt})
 check("fixed gear excluded from scrolling \(name)",gear.position==CGPoint(x:w/2-30,y:h/2-50))
 p.tapPlay(at:box.position);check("scrolled hit target follows primary \(name)",p.startCalls==3)
 p.menuScrollOffset=0;p.applyMenuScroll();check("scroll returns primary to origin \(name)",box.position==original)
 if CommandLine.arguments.count>1 && ["phone","ipad"].contains(name) {
  let directory=URL(fileURLWithPath:CommandLine.arguments[1]);try? FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
  check("offscreen Metal render \(name)",render(p,to:directory.appendingPathComponent(name+".png"),scale:name=="phone" ? 2:1))
 }
}
// Relative luminance of the opaque colors used by the real construction.
func luminance(_ hex:UInt32)->Double{[16,8,0].enumerated().reduce(0){sum,item in let c=Double((hex>>item.element)&255)/255;let v=c<=0.04045 ? c/12.92:pow((c+0.055)/1.055,2.4);return sum+v*[0.2126,0.7152,0.0722][item.offset]}}
let blue=luminance(0x0753A5);check("white on blue contrast exceeds7to1",1.05/(blue+0.05)>7)
print("Menu CTA: \(passed) passed / \(failed) failed");exit(failed==0 ? 0:1)
