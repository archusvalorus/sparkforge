#!/usr/bin/env python3
"""Execute live privacy/IAP/ad bodies and extracted lifecycle entries with explicit SDK fakes."""
from pathlib import Path
import subprocess,tempfile,json,hashlib
here=Path(__file__).resolve().parent;repo=here.parent.parent

def block(source,signature):
    start=source.index(signature);opening=source.index('{',start);depth=1;pos=opening+1
    while depth:
        if source[pos]=='{':depth+=1
        if source[pos]=='}':depth-=1
        pos+=1
    return source[start:pos]
with tempfile.TemporaryDirectory(prefix='sf-isolation-') as work:
    work=Path(work);sources=[];hashes={}
    for name in ['GameRunPreferences','AdEntitlementState','AdConsentCoordinator','AdConsentPlatform','IAPManager','AdReviveManager']:
        p=repo/'Sparkforge/Systems'/f'{name}.swift';s=p.read_text();hashes[str(p.relative_to(repo))]=hashlib.sha256(p.read_bytes()).hexdigest()
        for module in ['UIKit','AppTrackingTransparency','UserMessagingPlatform','GoogleMobileAds','StoreKit']:
            s=s.replace(f'import {module}','import Foundation')
        if name=='IAPManager':s=s.replace('private init()', 'init()')
        q=work/p.name;q.write_text(s);sources.append(str(q))
    snippets=[]
    for name,path,superclass,signatures in [
        ('AppLifecycle','Sparkforge/Utils/AppDelegate.swift','',['func applicationDidBecomeActive(_ application: UIApplication)', 'func applicationWillResignActive(_ application: UIApplication)']),
        ('SceneLifecycle','Sparkforge/SceneDelegate.swift','',['func sceneDidBecomeActive(_ scene: UIScene)', 'func sceneWillResignActive(_ scene: UIScene)']),
        ('PresenterLifecycle','Sparkforge/GameViewController.swift',': UIViewController',['override func viewDidAppear(_ animated: Bool)']),
        ('SettingsPrivacyLifecycle','Sparkforge/Nodes/SettingsMenuNode.swift','',['private static var privacyRowRequired: Bool'])]:
        p=repo/path;s=p.read_text();hashes[path]=hashlib.sha256(p.read_bytes()).hexdigest();bodies=[block(s,x) for x in signatures]
        # Visibility only: execute the actual property expression without a full SpriteKit renderer.
        if name=='SettingsPrivacyLifecycle':bodies=[x.replace('private static','static') for x in bodies]
        snippets.append('@MainActor final class '+name+superclass+' {\n'+'\n'.join(bodies)+'\n}')
    # Remove only the complete Debug UIKit diagnostic-rendering block from the
    # extracted presenter method. Its isolation guard remains verbatim, and all
    # actual platform, IAP and manager DEBUG branches compile unchanged.
    g=snippets[2];start=g.index('        #if DEBUG');end=g.index('        #endif',start)+len('        #endif');snippets[2]=g[:start]+g[end:]
    q=work/'Lifecycle.swift';q.write_text('import Foundation\n'+'\n'.join(snippets));sources.append(str(q))
    exe=work/'isolation'
    subprocess.run(['swiftc','-DDEBUG','-warnings-as-errors','-module-cache-path',str(work/'module-cache'),'-parse-as-library',*sources,str(here/'StoreKitFakes.swift'),str(here/'IsolationFakes.swift'),str(here/'IsolationTests.swift'),'-o',str(exe)],check=True)
    for room in ['--arena8-game','--arena8-six']:
        for owner in [False,True]:
            subprocess.run([str(exe),room,*(['--isolation-cached-owner'] if owner else [])],check=True)
print(json.dumps({'real_source_sha256':hashes,'scope':'Actual privacy/IAP/ad bodies; lifecycle entries extracted verbatim except full Debug UI probe block and access-only Settings visibility; explicit platform fakes, no network.'},indent=2))
