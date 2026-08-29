// MusicManager.swift
// Sparkforge
//
// v2.1 (interim atmosphere): BGM playback for the Suno "16-bit chaos"
// batch. Zero-config by design — Brandon drops tracks into the project and
// they play; no code change per track, ever.
//
// TRACK CONVENTION (filename prefixes, any of mp3/m4a/wav):
//   bgm_title_*   → title-screen pool
//   bgm_boss_*    → boss-fight pool (falls back to the run pool if empty)
//   bgm_run_*     → in-run pool
//   bgm_*         → in-run pool (anything unprefixed-beyond-bgm)
// Pools shuffle without immediate repeats and loop forever. Context flips
// crossfade (GameConfig.BGM.crossfade); track-to-track within a pool is a
// straight segue.
//
// POLITENESS RULES:
//   • The player's own audio wins: if something else is playing when we'd
//     start, BGM stays silent for that app session (SFX unaffected).
//   • BGM: OFF in Settings fades out live; ON resumes. (The toggle finally
//     does something — "music coming soon" has arrived.)
//   • .ambient session (set by AudioManager): silent switch is respected.

import AVFoundation
import Foundation

final class MusicManager: NSObject, AVAudioPlayerDelegate {

    static let shared = MusicManager()

    enum Context { case title, run, boss }

    private(set) var context: Context = .title
    private var pools: [Context: [URL]] = [:]
    private var lastTrack: [Context: URL] = [:]
    private var player: AVAudioPlayer?
    /// The user's own audio was playing when we first tried to start —
    /// stand down for the rest of this app session.
    private var deferringToUserAudio = false

    var hasTracks: Bool { !pools.values.allSatisfy { $0.isEmpty } }

    private override init() {
        super.init()
        discoverTracks()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
    }

    /// Find every bundled bgm_* audio file, wherever Xcode flattened it.
    private func discoverTracks() {
        var title: [URL] = [], run: [URL] = [], boss: [URL] = []
        for ext in ["mp3", "m4a", "wav"] {
            for url in Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [] {
                let name = url.deletingPathExtension().lastPathComponent.lowercased()
                guard name.hasPrefix("bgm_") else { continue }
                if name.hasPrefix("bgm_title_") { title.append(url) }
                else if name.hasPrefix("bgm_boss_") { boss.append(url) }
                else { run.append(url) }   // bgm_run_* and plain bgm_*
            }
        }
        pools = [.title: title, .run: run, .boss: boss.isEmpty ? [] : boss]
        #if DEBUG
        NSLog("[BGM] discovered title=%d run=%d boss=%d", title.count, run.count, boss.count)
        #endif
    }

    // MARK: - Public surface

    /// Set the musical context. Same context = no-op; a change crossfades.
    func setContext(_ new: Context) {
        if new == context, player?.isPlaying == true { return }
        context = new
        guard SettingsManager.shared.bgmEnabled, !deferringToUserAudio else { return }
        playNext(crossfade: true)
    }

    /// Re-evaluate after the BGM toggle flips or the app returns foreground.
    func refresh() {
        guard hasTracks else { return }
        if !SettingsManager.shared.bgmEnabled {
            player?.setVolume(0, fadeDuration: TimeInterval(GameConfig.BGM.crossfade))
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(GameConfig.BGM.crossfade)) {
                [weak self] in
                if !SettingsManager.shared.bgmEnabled { self?.player?.pause() }
            }
            return
        }
        if player?.isPlaying != true { playNext(crossfade: true) }
    }

    // MARK: - Playback

    private func poolForCurrentContext() -> [URL] {
        let pool = pools[context] ?? []
        if !pool.isEmpty { return pool }
        // Boss falls back to run; title falls back to run; run falls back to
        // ANYTHING — one lonely track should still play everywhere.
        let runPool = pools[.run] ?? []
        if !runPool.isEmpty { return runPool }
        return pools.values.flatMap { $0 }
    }

    private func playNext(crossfade: Bool) {
        let pool = poolForCurrentContext()
        guard !pool.isEmpty else { return }

        // On first-ever start, cede to the player's own audio.
        if player == nil, AVAudioSession.sharedInstance().isOtherAudioPlaying {
            deferringToUserAudio = true
            #if DEBUG
            NSLog("[BGM] user audio detected — standing down this session")
            #endif
            return
        }

        // Shuffle without immediate repeat (when the pool allows it).
        var candidates = pool
        if pool.count > 1, let last = lastTrack[context] {
            candidates.removeAll { $0 == last }
        }
        guard let url = candidates.randomElement() else { return }
        lastTrack[context] = url

        let fade = TimeInterval(GameConfig.BGM.crossfade)
        if crossfade, let old = player, old.isPlaying {
            old.setVolume(0, fadeDuration: fade)
            DispatchQueue.main.asyncAfter(deadline: .now() + fade) { old.stop() }
        }

        guard let next = try? AVAudioPlayer(contentsOf: url) else { return }
        next.delegate = self
        next.volume = crossfade ? 0 : GameConfig.BGM.volume
        next.prepareToPlay()
        next.play()
        if crossfade { next.setVolume(GameConfig.BGM.volume, fadeDuration: fade) }
        player = next
        #if DEBUG
        NSLog("[BGM] playing %@", url.lastPathComponent)
        #endif
    }

    // MARK: - Delegate + interruptions

    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        guard SettingsManager.shared.bgmEnabled, !deferringToUserAudio else { return }
        playNext(crossfade: false)   // straight segue within the pool
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .ended, SettingsManager.shared.bgmEnabled, !deferringToUserAudio {
            player?.play()
        }
    }
}
