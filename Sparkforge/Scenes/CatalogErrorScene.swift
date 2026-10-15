// CatalogErrorScene.swift
// Sparkforge
//
// v2.2 catalog migration (CL-113), Unit J2 — ruling D1 (Oct 4 2026): when the
// ability catalog fails to load, the app blocks gameplay with a concise error
// screen and keeps the full diagnostics in the log. Development builds also
// show the full report on the screen. Shown by GameViewController in place of
// the title; nothing else can be reached from it. There is no fallback pool.

import SpriteKit

final class CatalogErrorScene: SKScene {

    private let failure: CatalogLoadFailure

    init(size: CGSize, failure: CatalogLoadFailure) {
        self.failure = failure
        super.init(size: size)
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        let width = size.width - 32

        let title = UITheme.label("Sparkforge can't start", size: UITheme.Size.display, color: UITheme.Color.accent, bold: true)
        title.position = CGPoint(x: 0, y: size.height * 0.30)
        addChild(title)

        let summary = UITheme.label(failure.summary, size: UITheme.Size.body)
        summary.numberOfLines = 0
        summary.preferredMaxLayoutWidth = width
        summary.position = CGPoint(x: 0, y: size.height * 0.30 - 40)
        addChild(summary)

        let hint = UITheme.label("The ability catalog bundled with this build is invalid. Reinstall the app, or update it.", size: UITheme.Size.label)
        hint.numberOfLines = 0
        hint.preferredMaxLayoutWidth = width
        hint.position = CGPoint(x: 0, y: size.height * 0.30 - 100)
        addChild(hint)

        #if DEBUG
        // Development: every diagnostic, on screen as well as in the log.
        let report = UITheme.label(failure.report, size: UITheme.Size.caption)
        report.numberOfLines = 0
        report.preferredMaxLayoutWidth = width
        report.horizontalAlignmentMode = .center
        report.verticalAlignmentMode = .top
        report.position = CGPoint(x: 0, y: size.height * 0.30 - 150)
        addChild(report)
        #endif
    }
}
