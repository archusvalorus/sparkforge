#!/usr/bin/env python3
"""Execute production coordinator and manager bodies; SDK/UI are explicit fakes."""
from pathlib import Path
import subprocess,tempfile,hashlib,json
here=Path(__file__).resolve().parent
repo=here.parent.parent
core=repo/'Sparkforge/Systems/AdConsentCoordinator.swift'
entitlement=repo/'Sparkforge/Systems/AdEntitlementState.swift'
preferences=repo/'Sparkforge/Systems/GameRunPreferences.swift'
manager=repo/'Sparkforge/Systems/AdReviveManager.swift'
with tempfile.TemporaryDirectory(prefix='sf-consent-') as tmp:
    tmp=Path(tmp)
    # Only imports change. The manager body is neither modeled nor reimplemented.
    extracted=tmp/'AdReviveManager.swift'
    extracted.write_text(manager.read_text().replace('import UIKit','import Foundation').replace('import GoogleMobileAds',''))
    for suite,files in [('coordinator',[entitlement,core,here/'CoordinatorTests.swift']),('ad-manager',[preferences,entitlement,core,extracted,here/'AdManagerTests.swift'])]:
        exe=tmp/suite
        subprocess.run(['swiftc','-warnings-as-errors','-module-cache-path',str(tmp/'module-cache'),'-parse-as-library',*[str(x) for x in files],'-o',str(exe)],check=True)
        subprocess.run([str(exe)],check=True)
    iap=repo/'Sparkforge/Systems/IAPManager.swift'
    extractedIAP=tmp/'IAPManager.swift'
    extractedIAP.write_text(iap.read_text().replace('import StoreKit','import Foundation').replace('private init()', 'init()'))
    exe=tmp/'sf-entitlement-proof'
    subprocess.run(['swiftc','-warnings-as-errors','-module-cache-path',str(tmp/'module-cache'),'-parse-as-library',str(preferences),str(entitlement),str(extractedIAP),str(here/'StoreKitFakes.swift'),str(here/'IAPTests.swift'),'-o',str(exe)],check=True)
    for scenario in ['fresh','cached-owner','delayed-owner','unverified','purchase-race','update-race','purchase-error','restore-error','restore-race','restore-serialized','revocation','revocation-during-finish','pending']:
        subprocess.run([str(exe),scenario],check=True)
print(json.dumps({'production_source_sha256':{str(p.relative_to(repo)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [entitlement,core,manager,iap]},'platform':'Foundation host; real production bodies; UIKit/GMA fakes, no network'},indent=2))

subprocess.run(["python3",str(here/"run-isolation.py")],check=True)
