import SpriteKit
import Metal
import ImageIO
import UniformTypeIdentifiers
import AppKit
var passed=0,failed=0
func check(_ name:String,_ ok:Bool){if ok{passed+=1}else{failed+=1;print("FAIL \(name)")}}
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
let args=CommandLine.arguments
let directory=args.count>1 && !args[1].hasPrefix("--") ? URL(fileURLWithPath:args[1]) : nil
let baseline=args.contains("--baseline")
func option(_ key:String)->String? {guard let i=args.firstIndex(of:key),i+1<args.count else{return nil};return args[i+1]}
let comparison: [String:[String:Double]] = option("--compare").flatMap { try? Data(contentsOf:URL(fileURLWithPath:$0)) }.flatMap {try? JSONDecoder().decode([String:[String:Double]].self,from:$0)} ?? [:]
var metrics:[String:[String:Double]]=[:]
if let directory=directory {try? FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)}
func plate(_ p:MenuProbe,_ name:String)->SKShapeNode? {
 guard let n=p.childNode(withName:name) else{return nil}
 if let s=n as? SKShapeNode{return s}
 return n.children.compactMap{$0 as? SKShapeNode}.first
}
func worldRect(_ p:MenuProbe,_ plate:SKShapeNode)->CGRect {
 let b=plate.path!.boundingBoxOfPath
 let lo=p.convert(CGPoint(x:b.minX,y:b.minY),from:plate),hi=p.convert(CGPoint(x:b.maxX,y:b.maxY),from:plate)
 return CGRect(x:lo.x,y:lo.y,width:hi.x-lo.x,height:hi.y-lo.y)
}
func color(_ c:SKColor)->(Double,Double,Double,Double) {let x=c.usingColorSpace(.sRGB)!;return (x.redComponent,x.greenComponent,x.blueComponent,x.alphaComponent)}
func luminance(_ c:SKColor)->Double {let (r,g,b,_)=color(c);func linear(_ v:Double)->Double{v<=0.04045 ? v/12.92:pow((v+0.055)/1.055,2.4)};return linear(r)*0.2126+linear(g)*0.7152+linear(b)*0.0722}
func contrast(_ a:SKColor,_ b:SKColor)->Double {let x=luminance(a),y=luminance(b);return (max(x,y)+0.05)/(min(x,y)+0.05)}
if !baseline {
 for font in ["AvenirNextCondensed-HeavyItalic","AvenirNext-Heavy","AvenirNext-Bold"] {check("native font resolves \(font)",NSFont(name:font,size:18) != nil)}
}
let cases:[(String,CGFloat,CGFloat,Bool,Insets)]=[
 ("phone-small",320,568,false,Insets(top:20,bottom:0)),("phone",375,812,false,Insets(top:44,bottom:34)),("phone-large",430,932,false,Insets(top:59,bottom:34)),
 ("phone-left",375,812,false,Insets(top:44,bottom:34,left:44)),("phone-right",375,812,false,Insets(top:44,bottom:34,right:44)),
 ("ipad",768,1024,true,Insets(top:24,bottom:20)),("ipad-large",1024,1366,true,Insets(top:24,bottom:20)),("ipad-landscape",1024,768,true,Insets(top:24,bottom:20)),("ipad-split",375,1024,true,Insets(top:24,bottom:20))]
for profile in ["established","new","claimed","no-daily","boss-no-history"] {
 let pm=ProgressionManager.shared,hs=HighScoreManager.shared,fp=ForgePathManager.shared,df=DailyForgeManager.shared
 pm.currentArena=profile == "new" ? 0:6;pm.forgeLevel=profile == "new" ? 0:12
 hs.totalRuns=["new","boss-no-history"].contains(profile) ? 0:84
 fp.picksAvailable=profile == "established" ? 2:0;fp.summary=profile == "claimed" ? [.init(branch:.init(icon:"⚡"),count:4)]:[]
 df.hasClaimedToday=["claimed","no-daily"].contains(profile);df.activeBlessing=profile == "claimed" ? .init(icon:"🔥",name:"Ember"):nil
 BossRegistry.shared.isAvailable=profile != "new";IAPManager.shared.hasRemovedAds=profile == "claimed"
 for (name,w,h,pad,insets) in cases {
  DeviceScale.isIPad=pad;DeviceScale.screenShort=min(w,h)
  let p=MenuProbe();p.size=CGSize(width:w,height:h);p.view?.safeAreaInsets=insets;p.build()
  let key=profile+"/"+name
  guard let play=plate(p,"ignitePromptBox") else {fatalError("primary absent")}
  let playRect=worldRect(p,play),word=p.titleLabel.calculateAccumulatedFrame()
  var row:[String:Double]=["playY":playRect.midY,"playWidth":playRect.width,"titleTop":word.maxY,"footerY":p.childNode(withName:"versionLabel")!.position.y]
  let names=["ignitePromptBox","forgePathButton","dailyForgeButton","codexHubButton","skinsButton","bossModeButton","removeAdsButton"]
  for n in names {if let q=plate(p,n) {row[n+"Y"]=worldRect(p,q).midY}}
  metrics[key]=row
  if !baseline {
   let expectedWidth=min(312,w-insets.left-insets.right-24),centerX=(insets.left-insets.right)/2
   check("primary retains taller hierarchy \(key)",playRect.height>42 && p.tapPrompt.fontSize>=30)
   check("primary initially safe and visible \(key)",playRect.maxY<h/2-insets.top-10 && playRect.minY > -h/2+insets.bottom+10)
   check("wordmark fits safe width \(key)",word.minX >= -w/2+insets.left+6 && word.maxX<=w/2-insets.right-6)
   check("wordmark subtitle clearance \(key)",word.minY>p.subtitleLabel.frame.maxY+6)
   check("subtitle primary clearance \(key)",p.subtitleLabel.frame.minY>playRect.maxY+8)
   let (red,green,blue,alpha)=color(play.strokeColor)
   check("actual sheer forge-gold stroke \(key)",abs(red-232.0/255)<0.01 && abs(green-191.0/255)<0.01 && abs(blue-100.0/255)<0.01 && alpha>0.4 && alpha<0.7)
   check("actual opaque white on blue contrast \(key)",color(p.tapPrompt.fontColor!).3==1 && contrast(p.tapPrompt.fontColor!,play.fillColor)>7)
   for n in names {
    guard let q=plate(p,n) else{continue};let rect=worldRect(p,q)
    check("shared column \(key) \(n)",abs(rect.width-expectedWidth)<0.01 && abs(rect.midX-centerX)<0.01)
    check("safe plate bounds \(key) \(n)",rect.minX>=(-w/2+insets.left+10) && rect.maxX<=w/2-insets.right-10)
    let label:SKLabelNode?
    switch n {case "ignitePromptBox":label=p.tapPrompt;case "forgePathButton":label=p.childNode(withName:"forgePathRowLabel") as? SKLabelNode
     default:label=p.childNode(withName:n)?.children.compactMap{$0 as? SKLabelNode}.first}
    if let label=label {
     check("bold label fits plate \(key) \(n)",(label.fontName?.contains("Bold")==true || label.fontName?.contains("Heavy")==true) && label.calculateAccumulatedFrame().width<rect.width-20 && label.frame.height<rect.height-10)
     check("resolved label contrast \(key) \(n)",contrast(label.fontColor!,q.fillColor)>=4.5)
    }
   }
   let codex=row["codexHubButtonY"]!,skins=row["skinsButtonY"]!
   check("mode gap matches Daily→Codex reference \(key)",abs(codex-skins-74)<0.01)
   if let boss=row["bossModeButtonY"] {check("Boss Mode separated \(key)",abs(skins-boss-74)<0.01)}
   if let prior=comparison[key],let oldPlay=prior["playY"] {
    check("upper stack retains comfortable spacing \(key)",abs(playRect.midY-oldPlay+6)<0.01)
   }
  }
  // Execute actual hit dispatch in both initial and scrolled coordinates; stub only destinations.
  let actions:[(String,String)]=[("ignitePromptBox","play"),("forgePathButton","path"),("dailyForgeButton","daily"),("codexHubButton","codex"),("skinsButton","skins"),("bossModeButton","boss"),("removeAdsButton","ads")]
  for offset in [CGFloat(0),p.clampedMenuOffset(10000)] {
   p.menuScrollOffset=offset;p.applyMenuScroll()
   for (name,action) in actions {if let q=plate(p,name) {
    let rect=worldRect(p,q);p.actions=[];p.handleHomeTapUp(CGPoint(x:rect.midX,y:rect.midY));check("same action after scroll \(key) \(name)",p.actions==[action])
    p.actions=[];p.handleHomeTapUp(CGPoint(x:rect.minX+3,y:rect.midY));check("left face hit \(key) \(name)",p.actions==[action])
    p.actions=[];p.handleHomeTapUp(CGPoint(x:rect.maxX-3,y:rect.midY));check("right face hit \(key) \(name)",p.actions==[action])
   }}
  }
  if !baseline {
   // Scrolling is intentional: each lower action must enter the safe viewport,
   // and extra mode spacing must never strand a row below the bottom clamp.
   for (name,_) in actions {if let q=plate(p,name) {
    let rest=metrics[key]![name+"Y"]!
    let offset=p.clampedMenuOffset(-rest)
    p.menuScrollOffset=offset;p.applyMenuScroll();let rect=worldRect(p,q)
    check("action reachable inside safe viewport \(key) \(name)",rect.minY>=(-h/2+insets.bottom+5) && rect.maxY<=h/2-insets.top-5)
   }}
  }
  let gear=p.childNode(withName:"settingsGearButton")!,gearPosition=gear.position
  check("fixed gear remains outside scroll \(key)",gearPosition==CGPoint(x:w/2-insets.right-26,y:h/2-insets.top-34))
  p.menuScrollOffset=0;p.applyMenuScroll()
  check("scroll restores primary \(key)",abs(worldRect(p,play).midY-playRect.midY)<0.01)
  p.actions=[];p.handleHomeTapUp(CGPoint(x:w/2-2,y:0));check("empty margin does not launch \(key)",!p.actions.contains("play"))
  if !baseline {
   // Async/localized prices keep the same destination and fit inside the existing plate.
   let price=SKLabelNode(fontNamed:"AvenirNext-Heavy");price.fontSize=min(17*DeviceScale.ui,20);price.text="Remove Ads — CHF 1’234.99"
   p.fitHomeLabel(price);check("long price fits \(key)",price.frame.width < min(312,w-insets.left-insets.right-24)-24)
  }
  if profile=="established",let directory=directory,["phone-small","phone","phone-large","ipad"].contains(name) {
   check("render top \(name)",render(p,to:directory.appendingPathComponent(name+"-top.png"),scale:pad ? 1:2))
   p.menuScrollOffset=p.clampedMenuOffset(10000);p.applyMenuScroll()
   check("render lower \(name)",render(p,to:directory.appendingPathComponent(name+"-lower.png"),scale:pad ? 1:2))
  }
 }
}
if let file=option("--metrics"),let data=try? JSONEncoder().encode(metrics) {try! data.write(to:URL(fileURLWithPath:file))}
print("Menu refinement: \(passed) passed / \(failed) failed");exit(failed==0 ? 0:1)
