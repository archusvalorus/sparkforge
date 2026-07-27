// LionNode.swift
// Sparkforge
//
// v2.0 art pass — the mountain lion, the Nature Canon's 5% jackpot pet.
//
// Replaces the 🦁 emoji placeholder. Same split as every other creature here:
// this node knows how to stand, prowl and maul; GameScene decides when. It has
// no opinion about targets, damage or duration.
//
// Played straight on purpose (see docs/art-briefs.md §3). It arrives among
// rabbits, squirrels and a bluebird — the CONTRAST is the joke, so the lion
// itself has to be genuinely impressive rather than comic.

import SpriteKit

final class LionNode: SKNode {

    private let sprite: SKSpriteNode
    private var idleFrames: [SKTexture] = []
    private var prowlFrames: [SKTexture] = []
    private var maulFrames: [SKTexture] = []
    private var currentClip = ""
    private var mauling = false

    /// Fallback if the art is ever missing — a recognisable cat still prowls
    /// rather than nothing at all.
    private static let fallback = "🦁"

    override init() {
        idleFrames = (1...2).map { SKTexture(imageNamed: "lion_idle_\($0)") }
        prowlFrames = (1...4).map { SKTexture(imageNamed: "lion_prowl_\($0)") }
        maulFrames = (1...2).map { SKTexture(imageNamed: "lion_maul_\($0)") }
        sprite = SKSpriteNode(texture: idleFrames.first)
        super.init()
        zPosition = 7

        if let first = idleFrames.first, first.size().width > 1 {
            let aspect = first.size().height / max(first.size().width, 1)
            let w = GameConfig.Tree.lionSize * GameConfig.Tree.lionFrameBoxRatio
            sprite.size = CGSize(width: w, height: w * aspect)
            addChild(sprite)
            play("idle", idleFrames, 0.7)
        } else {
            let label = SKLabelNode(text: Self.fallback)
            label.fontSize = GameConfig.Tree.lionSize
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            addChild(label)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Clips

    /// Guarded on the current clip so the update loop can call this every frame
    /// without restarting the animation — restarting each tick is the classic
    /// sprite stutter, and it never shows up in code review.
    private func play(_ name: String, _ frames: [SKTexture], _ tpf: TimeInterval) {
        guard !frames.isEmpty, currentClip != name else { return }
        currentClip = name
        sprite.removeAction(forKey: "anim")
        sprite.run(.repeatForever(.animate(with: frames, timePerFrame: tpf,
                                           resize: false, restore: false)), withKey: "anim")
    }

    /// Drive from the scene each frame: prowling when it's closing on prey,
    /// idle when there's nothing to hunt. A maul in progress owns the sprite.
    func setMoving(_ moving: Bool) {
        guard !mauling else { return }
        if moving { play("prowl", prowlFrames, 0.14) } else { play("idle", idleFrames, 0.7) }
    }

    /// Face travel. The art is right-facing; the scene mirrors for left.
    func face(_ dx: CGFloat) {
        if dx < -0.05 { sprite.xScale = -1 }
        else if dx > 0.05 { sprite.xScale = 1 }
    }

    /// One strike. Brief and violent — two frames, fast, then straight back to
    /// hunting. It never poses.
    func maul() {
        guard maulFrames.count == 2, !mauling else { return }
        mauling = true
        currentClip = "maul"
        sprite.removeAction(forKey: "anim")
        sprite.run(.sequence([
            .setTexture(maulFrames[0], resize: false), .wait(forDuration: 0.09),
            .setTexture(maulFrames[1], resize: false), .wait(forDuration: 0.16),
            .run { [weak self] in
                self?.mauling = false
                self?.currentClip = ""      // let the next setMoving re-apply
            }
        ]), withKey: "anim")
    }
}
