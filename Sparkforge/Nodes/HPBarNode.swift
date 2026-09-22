// HPBarNode.swift
// Sparkforge
//
// v1.4: Horizontal HP progress bar.
// v1.6: Health-green fill (matches health-orb language — green = health,
// per color canon) shifting amber → red as it drains. "HP" tag on the left.
// Pulses red at low HP. Shows numeric HP when damaged.

import SpriteKit

final class HPBarNode: SKNode {
    
    // MARK: - Config
    
    private let barWidth: CGFloat
    private let barHeight: CGFloat = 16  // v1.7 legibility pass: 5 → 16
    
    // MARK: - Nodes
    
    private let backgroundBar: SKShapeNode
    private let fillBar: SKShapeNode
    private let hpLabel: SKLabelNode
    private let tagLabel: SKLabelNode  // v1.6: "HP" tag
    /// v2.1 A4b (CL-21): the Blood Barrier strip under the bar — bone-white
    /// with a dark-red edge, width ∝ barrier / max HP, plus its number.
    private let barrierStrip: SKShapeNode
    private let barrierLabel: SKLabelNode
    private let barrierHeight: CGFloat = 4
    /// v2.1 A4b: when the strip may hide — a hit that EMPTIES the pool still
    /// shows its absorption flash first (pure state, harness-proven).
    private var barrierTell = BarrierTellState()
    private var drawnBarrierMaxHP = -1

    // MARK: - State

    private var lastHP: Int = -1
    private var isLowHP: Bool = false
    /// v1.6: current tier color — flashes restore to this, not a hardcoded hex
    private var baseColor = SKColor(hex: 0x44DD66)

    // MARK: - Init

    init(width: CGFloat = 120) {
        self.barWidth = width

        // Background (dark track, green-tinted)
        backgroundBar = SKShapeNode(rectOf: CGSize(width: width, height: barHeight), cornerRadius: 4)
        backgroundBar.fillColor = SKColor(hex: 0x112211)
        backgroundBar.strokeColor = SKColor(hex: 0x224422, alpha: 0.6)
        backgroundBar.lineWidth = 1

        // Fill (health green — same family as health orbs)
        fillBar = SKShapeNode(rectOf: CGSize(width: 1, height: barHeight), cornerRadius: 4)
        fillBar.fillColor = SKColor(hex: 0x44DD66)
        fillBar.strokeColor = .clear

        // v1.7: HP numbers live ON the bar, always visible
        hpLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        hpLabel.fontSize = 11
        hpLabel.fontColor = SKColor(hex: 0xFFFFFF)
        hpLabel.verticalAlignmentMode = .center
        hpLabel.horizontalAlignmentMode = .center
        hpLabel.position = .zero
        hpLabel.zPosition = 2

        // v1.6: "HP" tag left of the bar
        tagLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        tagLabel.text = "HP"
        tagLabel.fontSize = 11
        tagLabel.fontColor = SKColor(hex: 0x44DD66, alpha: 0.8)
        tagLabel.verticalAlignmentMode = .center
        tagLabel.horizontalAlignmentMode = .right
        tagLabel.position = CGPoint(x: -width / 2 - 7, y: 0)

        barrierStrip = SKShapeNode()
        barrierStrip.fillColor = SKColor(hex: 0xEDE4D3)
        barrierStrip.strokeColor = SKColor(hex: 0x8A1426)
        barrierStrip.lineWidth = 1
        barrierStrip.isHidden = true
        barrierLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        barrierLabel.fontSize = 8
        barrierLabel.fontColor = SKColor(hex: 0xEDE4D3)
        barrierLabel.verticalAlignmentMode = .center
        barrierLabel.horizontalAlignmentMode = .left
        barrierLabel.isHidden = true

        super.init()

        addChild(backgroundBar)
        addChild(fillBar)
        addChild(hpLabel)
        addChild(tagLabel)
        addChild(barrierStrip)
        addChild(barrierLabel)

        updateFill(1.0, currentHP: GameConfig.Player.baseMaxHP, maxHP: GameConfig.Player.baseMaxHP)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Update
    
    /// Update HP bar. Shows numeric HP when not at full health.
    func updateFill(_ progress: CGFloat, currentHP: Int, maxHP: Int) {
        let clamped = max(0, min(progress, 1.0))
        let fillWidth = max(1, barWidth * clamped)
        
        fillBar.path = CGPath(
            roundedRect: CGRect(
                x: -barWidth / 2,
                y: -barHeight / 2,
                width: fillWidth,
                height: barHeight
            ),
            cornerWidth: 4,
            cornerHeight: 4,
            transform: nil
        )
        
        // v1.6: health green → warning amber → danger red as it drains
        if clamped > 0.6 {
            baseColor = SKColor(hex: 0x44DD66)  // Health green (orb language)
        } else if clamped > 0.25 {
            baseColor = SKColor(hex: 0xEE8833)  // Warning amber-orange
        } else {
            baseColor = SKColor(hex: 0xFF1111)  // Danger red
        }
        fillBar.fillColor = baseColor
        
        // v1.7: numbers always on the bar
        hpLabel.text = "\(max(currentHP, 0))/\(maxHP)"
        
        // Low HP pulse
        let newLowHP = clamped <= 0.25 && currentHP > 0
        if newLowHP && !isLowHP {
            startLowHPPulse()
        } else if !newLowHP && isLowHP {
            stopLowHPPulse()
        }
        isLowHP = newLowHP
        
        lastHP = currentHP
    }
    
    // MARK: - Damage Flash
    
    /// Brief red flash on taking damage (v1.6: restores to tier color)
    func flashDamage() {
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.fillBar.fillColor = SKColor(hex: 0xFF5544) },
            SKAction.wait(forDuration: 0.08),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.fillBar.fillColor = self.baseColor
            }
        ])
        run(flash, withKey: "hpFlash")
    }

    // MARK: - v2.1 A4b: Blood Barrier

    /// Redraw the barrier strip (only when something visible changed).
    func updateBarrier(_ amount: Int, maxHP: Int) {
        let sizeChanged = maxHP != drawnBarrierMaxHP
        guard barrierTell.update(amount: amount) || (sizeChanged && amount > 0) else { return }
        guard amount > 0, maxHP > 0 else { hideBarrierStrip(); return }
        drawBarrierStrip(amount: amount, maxHP: maxHP)
    }

    /// Give the strip its geometry and number, and show it.
    private func drawBarrierStrip(amount: Int, maxHP: Int) {
        drawnBarrierMaxHP = maxHP
        let w = max(2, barWidth * min(1, CGFloat(amount) / CGFloat(maxHP)))
        let y = -barHeight / 2 - 1 - barrierHeight / 2     // tight under the bar
        barrierStrip.path = CGPath(roundedRect: CGRect(x: -barWidth / 2, y: y - barrierHeight / 2,
                                                       width: w, height: barrierHeight),
                                   cornerWidth: 2, cornerHeight: 2, transform: nil)
        barrierLabel.text = "+\(amount)"
        barrierLabel.position = CGPoint(x: -barWidth / 2 + w + 4, y: y)
        barrierStrip.isHidden = false
        barrierLabel.isHidden = false
    }

    private func hideBarrierStrip() {
        barrierStrip.isHidden = true
        barrierLabel.isHidden = true
    }

    /// A hit the barrier absorbed: the strip flashes (a FULLY absorbed hit
    /// flashes only this — the HP bar stays calm).
    /// A hit the barrier absorbed: the strip flashes (a FULLY absorbed hit
    /// flashes only this — the HP bar stays calm). `absorbed` is what this hit
    /// soaked, so a pool GRANTED AND EMPTIED between two HUD draws still has
    /// something to show: without it the strip would be "visible" with no shape
    /// or number, and the player would see no tell at all.
    func flashBarrier(absorbed: Int, maxHP: Int) {
        barrierTell.absorbedHit()
        if barrierTell.drawnAmount <= 0, absorbed > 0, maxHP > 0,
           barrierTell.update(amount: absorbed) {
            drawBarrierStrip(amount: absorbed, maxHP: maxHP)
        }
        barrierStrip.isHidden = false
        barrierLabel.isHidden = false
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.barrierStrip.fillColor = SKColor(hex: 0xFFFFFF) },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in self?.endBarrierFlash() }
        ])
        barrierStrip.run(flash, withKey: "barrierFlash")
    }

    /// The flash finished (its own completion step, so it is testable): an
    /// emptied pool hides now — never a lingering 0 strip — while a pool that
    /// refilled mid-flash stays on screen.
    func endBarrierFlash() {
        barrierStrip.fillColor = SKColor(hex: 0xEDE4D3)
        if barrierTell.flashEnded() { hideBarrierStrip() }
    }

    #if DEBUG
    /// Harness probe: what the strip is actually PRESENTING — not just whether
    /// a flag says visible, but whether it has drawable geometry and a number.
    var barrierPresentation: (visible: Bool, hasShape: Bool, label: String) {
        (!barrierStrip.isHidden && !barrierLabel.isHidden,
         barrierStrip.path != nil,
         barrierLabel.text ?? "")
    }
    #endif

    // MARK: - Heal Flash

    /// Brief bright-mint flash on healing (v1.6: reads against the green bar)
    func flashHeal() {
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.fillBar.fillColor = SKColor(hex: 0xBBFFCC) },
            SKAction.wait(forDuration: 0.12),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.fillBar.fillColor = self.baseColor
            }
        ])
        run(flash, withKey: "hpFlash")
    }
    
    // MARK: - Low HP Pulse
    
    private func startLowHPPulse() {
        let pulse = SKAction.sequence([
            SKAction.run { [weak self] in self?.fillBar.alpha = 0.5 },
            SKAction.wait(forDuration: 0.3),
            SKAction.run { [weak self] in self?.fillBar.alpha = 1.0 },
            SKAction.wait(forDuration: 0.3)
        ])
        fillBar.run(SKAction.repeatForever(pulse), withKey: "lowHPPulse")
    }
    
    private func stopLowHPPulse() {
        fillBar.removeAction(forKey: "lowHPPulse")
        fillBar.alpha = 1.0
    }
}
