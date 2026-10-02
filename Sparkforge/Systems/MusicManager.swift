// MusicManager.swift
// Sparkforge
//
// BGM playback. v2.1 geometry Unit 4 replaced the per-context pools with ONE
// shuffled deck of every bundled `bgm_*` track (Brandon's settled plan, Oct 1 —
// docs/arena6-geometry-reconciliation.md §5 Unit 4, audio subunit):
//   • one shared deck (BGMDeck): each track once per cycle, then a reshuffle
//     that never opens with the track that just played; it lives for the app
//     session and is never persisted;
//   • CONTINUOUS: title ↔ run ↔ boss never changes the song — a new track is
//     drawn only when one finishes;
//   • RESUME: an OS interruption, backgrounding, and BGM OFF → ON all resume
//     the current track where it was (no new draw);
//   • a track that can't be opened is dropped for the session and logged — no
//     spin, no double advance; a start the session refuses is retried on the
//     next transport event. The rules are one table, BGMPolicy.
// File names carry no context any more (`bgm_<title>_<id8>.mp3`; see
// Sparkforge/Audio/BGM/README.txt).
//
// POLITENESS RULES (unchanged):
//   • The player's own audio wins: if something else is playing at the FIRST
//     start, BGM stays silent for that app session (SFX unaffected).
//   • BGM: OFF in Settings fades out live; ON fades the same song back in.
//   • .ambient session (set by AudioManager): silent switch is respected.

import AVFoundation
import Foundation
import UIKit

final class MusicManager: NSObject, AVAudioPlayerDelegate {

    static let shared = MusicManager()

    enum Context { case title, run, boss }

    /// The scene's musical context. Tracked for the scenes; it never changes
    /// the song (continuous playback).
    private(set) var context: Context = .title
    private var deck = BGMDeck<URL>([])
    private var rng = SystemRandomNumberGenerator()
    private var player: AVAudioPlayer?
    /// The user's own audio was playing when we first tried to start —
    /// stand down for the rest of this app session.
    private var deferringToUserAudio = false
    /// A song has started at least once this session (the user-audio check is
    /// a first-start rule).
    private var everStarted = false

    var hasTracks: Bool { !deck.isEmpty }

    private override init() {
        super.init()
        discoverTracks()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    /// Every bundled bgm_* audio file, wherever Xcode flattened it — one deck.
    private func discoverTracks() {
        var urls: [URL] = []
        for ext in ["mp3", "m4a", "wav"] {
            for url in Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [] {
                guard url.deletingPathExtension().lastPathComponent.lowercased().hasPrefix("bgm_") else { continue }
                urls.append(url)
            }
        }
        deck = BGMDeck(urls.sorted { $0.lastPathComponent < $1.lastPathComponent })
        #if DEBUG
        NSLog("[BGM] deck of %d tracks", deck.eligible.count)
        #endif
    }

    // MARK: - Public surface

    /// Record the musical context. Continuous playback: a playing (or a
    /// toggle-paused) song carries straight through; only when nothing has
    /// started yet does this begin the deck (BGMPolicy).
    func setContext(_ new: Context) {
        context = new
        perform(.contextChanged, fadeIn: true)
    }

    /// Re-evaluate after the BGM toggle flips. OFF fades out and PAUSES (the
    /// position is kept); ON fades the same song back in, or starts the deck.
    func refresh() {
        guard hasTracks else { return }
        perform(SettingsManager.shared.bgmEnabled ? .toggledOn : .toggledOff, fadeIn: true)
    }

    // MARK: - Transport (the rules live in BGMPolicy, executed in tools/bgm-harness)

    private func perform(_ event: BGMPolicy.Event, fadeIn: Bool) {
        switch BGMPolicy.action(for: event, enabled: SettingsManager.shared.bgmEnabled,
                                deferring: deferringToUserAudio, hasPlayer: player != nil) {
        case .none:
            break
        case .startDeck:
            playNext(fadeIn: true)
        case .resume:
            if let current = player { resume(current, fadeIn: fadeIn) }
        case .pause:
            player?.setVolume(0, fadeDuration: TimeInterval(GameConfig.BGM.crossfade))
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(GameConfig.BGM.crossfade)) {
                [weak self] in
                if !SettingsManager.shared.bgmEnabled { self?.player?.pause() }
            }
        case .playNext:
            playNext(fadeIn: false)   // a straight segue to the deck's next track
        }
    }

    private func resume(_ current: AVAudioPlayer, fadeIn: Bool) {
        guard !current.isPlaying else {
            current.setVolume(GameConfig.BGM.volume, fadeDuration: TimeInterval(GameConfig.BGM.crossfade))
            return
        }
        if fadeIn { current.volume = 0 }
        current.play()
        if fadeIn { current.setVolume(GameConfig.BGM.volume, fadeDuration: TimeInterval(GameConfig.BGM.crossfade)) }
    }

    /// Draw the deck's next track and start it. A track that can't be OPENED is
    /// dropped for the session and the next is drawn (bounded by the deck); a
    /// start the SESSION refuses puts the track back and waits for the next
    /// transport event to retry (independent review m2), unless that same track
    /// was just refused too — then it's dropped and the next is drawn.
    private func playNext(fadeIn: Bool) {
        // On the first-ever start only, cede to the player's own audio
        // (review N1: not at every song change).
        if !everStarted, AVAudioSession.sharedInstance().isOtherAudioPlaying {
            deferringToUserAudio = true
            #if DEBUG
            NSLog("[BGM] user audio detected — standing down this session")
            #endif
            return
        }
        for _ in 0...deck.eligible.count {
            guard let url = deck.draw(using: &rng) else { return }
            guard let next = try? AVAudioPlayer(contentsOf: url) else {
                deck.failed(url)
                #if DEBUG
                NSLog("[BGM] could not open %@ — dropped for this session", url.lastPathComponent)
                #endif
                continue
            }
            next.delegate = self
            next.volume = fadeIn ? 0 : GameConfig.BGM.volume
            next.prepareToPlay()
            guard next.play() else {
                // Once: kept for the next transport event. Twice in a row: the
                // file's fault — dropped, and the next track is drawn now.
                let dropped = deck.refused(url)
                #if DEBUG
                NSLog(dropped ? "[BGM] %@ refused twice — dropped for this session"
                              : "[BGM] the session refused %@ — kept for the next try", url.lastPathComponent)
                #endif
                if dropped { continue }
                return
            }
            deck.started(url)
            everStarted = true
            if fadeIn { next.setVolume(GameConfig.BGM.volume, fadeDuration: TimeInterval(GameConfig.BGM.crossfade)) }
            player = next
            #if DEBUG
            NSLog("[BGM] playing %@ (cycle %d)", url.lastPathComponent, deck.cyclesStarted)
            #endif
            return
        }
    }

    // MARK: - Delegate, interruptions, foreground

    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        guard p === player else { return }
        player = nil
        perform(.trackFinished, fadeIn: false)
    }

    func audioPlayerDecodeErrorDidOccur(_ p: AVAudioPlayer, error: Error?) {
        guard p === player, let url = p.url else { return }
        deck.failed(url)
        player = nil
        #if DEBUG
        NSLog("[BGM] decode error in %@ — dropped for this session", url.lastPathComponent)
        #endif
        perform(.trackBroken, fadeIn: false)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
        perform(.interruptionEnded, fadeIn: false)
    }

    /// Back from the background (or any deactivation): the same song resumes —
    /// or, if a start was refused earlier, the deck starts now.
    @objc private func handleDidBecomeActive(_ note: Notification) {
        perform(.becameActive, fadeIn: false)
    }
}
