// main.swift — deterministic validators for the Blood Barrier strip on the REAL
// HPBarNode (v2.1 A4b corrective pass, independent review findings).
// Each validator prints PASS/FAIL; exit 1 on any FAIL.

import Foundation
import SpriteKit

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("PASS  \(name)") }
    else { failed += 1; print("FAIL  \(name)  \(detail())") }
}

/// A tell is only real when the strip is visible AND has drawable geometry AND
/// shows its number — "visible" alone is what the reviewer caught.
func tellIsRendered(_ bar: HPBarNode, _ label: String) -> Bool {
    let p = bar.barrierPresentation
    return p.visible && p.hasShape && p.label == label
}

// H1 — the blocker: granted AND emptied before the first ordinary HUD draw.
do {
    let bar = HPBarNode(width: 210)
    check("H1a a fresh bar presents no barrier", !bar.barrierPresentation.visible)
    // Sanguinarian grants 12 and a hit eats all 12, both before updateHUD runs.
    bar.flashBarrier(absorbed: 12, maxHP: 100)
    check("H1b the absorption tell RENDERS: visible, with geometry and its number",
          tellIsRendered(bar, "+12"), "\(bar.barrierPresentation)")
    bar.updateBarrier(0, maxHP: 100)        // the HUD's first draw: the pool is 0
    check("H1c the emptied pool does not snatch the tell away mid-flash",
          tellIsRendered(bar, "+12"), "\(bar.barrierPresentation)")
    bar.endBarrierFlash()
    check("H1d once the tell completes, an empty strip hides", !bar.barrierPresentation.visible)
    bar.updateBarrier(0, maxHP: 100)
    check("H1e no ghost barrier afterwards", !bar.barrierPresentation.visible)
}

// H2 — exact depletion after a barrier had already been drawn.
do {
    let bar = HPBarNode(width: 210)
    bar.updateBarrier(20, maxHP: 100)
    check("H2a a granted pool renders", tellIsRendered(bar, "+20"), "\(bar.barrierPresentation)")
    bar.flashBarrier(absorbed: 20, maxHP: 100)      // the hit eats exactly 20
    bar.updateBarrier(0, maxHP: 100)
    check("H2b exact depletion keeps the tell on screen", tellIsRendered(bar, "+20"))
    bar.endBarrierFlash()
    check("H2c …then hides", !bar.barrierPresentation.visible)
}

// H3 — overflow: the barrier empties and HP takes the rest (split proven in
// damage-pipeline P10c; here it is the presentation that must survive).
do {
    let bar = HPBarNode(width: 210)
    bar.updateBarrier(10, maxHP: 100)
    bar.flashBarrier(absorbed: 10, maxHP: 100)      // 30 hit → 10 absorbed, 20 to HP
    bar.updateBarrier(0, maxHP: 100)
    check("H3a an over-absorbing hit still shows its tell", tellIsRendered(bar, "+10"))
    bar.endBarrierFlash()
    check("H3b …and the strip hides after it", !bar.barrierPresentation.visible)
}

// H4 — P3 regression: a refill during the flash must cancel the deferred hide.
do {
    let bar = HPBarNode(width: 210)
    bar.updateBarrier(20, maxHP: 100)
    bar.flashBarrier(absorbed: 20, maxHP: 100)
    bar.updateBarrier(0, maxHP: 100)                // emptied → hide deferred
    bar.updateBarrier(15, maxHP: 100)               // …then a kill refills it
    check("H4a the refill re-renders the strip at its new value", tellIsRendered(bar, "+15"))
    bar.endBarrierFlash()
    check("H4b the flash ending must NOT hide a barrier that exists again",
          tellIsRendered(bar, "+15"), "\(bar.barrierPresentation)")
}

// H5 — ordinary behaviour is unchanged.
do {
    let bar = HPBarNode(width: 210)
    bar.updateBarrier(30, maxHP: 100)
    bar.updateBarrier(0, maxHP: 100)
    check("H5a with no flash running, an emptied pool hides at once", !bar.barrierPresentation.visible)
    bar.updateBarrier(25, maxHP: 100)
    check("H5b a later grant renders again", tellIsRendered(bar, "+25"))
    bar.updateBarrier(25, maxHP: 50)                // max HP fell: same amount, new width
    check("H5c a max-HP change redraws the strip", tellIsRendered(bar, "+25"))
    bar.endBarrierFlash()
    check("H5d an end-of-flash with nothing deferred changes nothing", tellIsRendered(bar, "+25"))
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
