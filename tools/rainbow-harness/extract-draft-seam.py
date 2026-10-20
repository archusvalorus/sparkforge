#!/usr/bin/env python3
"""Instrument only a temporary manager copy; fail on an unexpected seam.

The actual draw remains executable. Diagnostics record which final cards are
protected by scheduled production claims, including already-present capstones.
No second implementation of palette/draft/eligibility is used by the tests.
"""
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
def replace_once(old, new):
    global source
    if source.count(old) != 1:
        raise SystemExit('R0 draft seam changed: ' + old)
    source = source.replace(old, new)

replace_once('final class UpgradeManager {', '''final class UpgradeManager {
    // Test diagnostics only; not present in the production manager.
    var r0ProtectedIDs: [String: Set<RainbowPolicy.Protection>] = [:]
''')
replace_once('func drawCards(count: Int = 3, level: Int = 0, allowSecret: Bool = true) -> [UpgradeCard] {',
'''func drawCards(count: Int = 3, level: Int = 0, allowSecret: Bool = true) -> [UpgradeCard] {
        r0ProtectedIDs.removeAll()
''')
replace_once('drawn[0] = claimant              // front slot; capstones take the back',
'''drawn[0] = claimant              // front slot; capstones take the back
            r0ProtectedIDs[claimant.id, default: []].insert(.gateway)''')
replace_once('if drawn.contains(where: { $0.id == cap.id }) { continue }',
'''if drawn.contains(where: { $0.id == cap.id }) {
                r0ProtectedIDs[cap.id, default: []].insert(.capstone)
                continue
            }''')
replace_once('if forcedSlot >= 0 { drawn[forcedSlot] = cap; forcedSlot -= 1 }\n            else { drawn.append(cap) }',
'''if forcedSlot >= 0 { drawn[forcedSlot] = cap; forcedSlot -= 1 }
            else { drawn.append(cap) }
            r0ProtectedIDs[cap.id, default: []].insert(.capstone)''')
replace_once('        return drawn\n    }', '''        for card in drawn {
            if signatureSpread { r0ProtectedIDs[card.id, default: []].insert(.signatureOpening) }
            if card.isSecret { r0ProtectedIDs[card.id, default: []].insert(.secret) }
        }
        return drawn
    }''')
Path(sys.argv[2]).write_text(source)
print('R0 seam: 6 guarded diagnostics inserted into temporary real-manager copy')
