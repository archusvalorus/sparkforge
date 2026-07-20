// AudioManager.swift
// Sparkforge
//
// v1.7: Procedural SFX — PCM buffers synthesized in code, no audio
// assets, matching the game's code-drawn identity. BGM playback lands
// when the Suno tracks arrive; until then bgmEnabled is storage-only.

import AVFoundation
import QuartzCore

final class AudioManager {

    static let shared = AudioManager()

    enum SFX: CaseIterable {
        case orbPickup
        case cardSelect
        case bossEntrance
        case playerDamage
        case levelUp
        case buildHint
        case skyStrike
        case bossExecute
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [SFX: AVAudioPCMBuffer] = [:]
    private var lastPlayed: [SFX: TimeInterval] = [:]

    private static let sampleRate: Double = 44_100
    /// Throttle so orb swarms don't machine-gun the pickup blip
    private static let minReplayInterval: TimeInterval = 0.06

    private init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)
        for _ in 0..<6 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        for sfx in SFX.allCases {
            buffers[sfx] = Self.render(sfx)
        }
        // .ambient: mixes with the player's own music, respects silent switch
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }

    func play(_ sfx: SFX) {
        guard SettingsManager.shared.sfxEnabled else { return }
        guard let buffer = buffers[sfx] else { return }

        let now = CACurrentMediaTime()
        if let last = lastPlayed[sfx], now - last < Self.minReplayInterval { return }
        lastPlayed[sfx] = now

        // Self-healing across audio session interruptions
        if !engine.isRunning {
            try? AVAudioSession.sharedInstance().setActive(true)
            guard (try? engine.start()) != nil else { return }
        }

        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    // MARK: - Synthesis

    private static func render(_ sfx: SFX) -> AVAudioPCMBuffer? {
        switch sfx {

        case .orbPickup:
            // Soft rising blip
            let d = 0.07
            return synth(duration: d) { t in
                let phase = sweepPhase(f0: 620, f1: 880, duration: d, t: t)
                return sin(phase) * envelope(t, duration: d, attack: 0.004) * 0.22
            }

        case .cardSelect:
            // Warm two-tone confirm: G4 then D5
            return synth(duration: 0.17) { t in
                if t < 0.06 {
                    let local = t
                    return sin(2 * .pi * 392 * local) * envelope(local, duration: 0.07, attack: 0.004) * 0.28
                } else {
                    let local = t - 0.06
                    return sin(2 * .pi * 587 * local) * envelope(local, duration: 0.11, attack: 0.004) * 0.28
                }
            }

        case .bossEntrance:
            // Low ominous swell with slow tremolo — root, fifth, sub-octave
            let d = 0.9
            return synth(duration: d) { t in
                let rise = min(t / 0.45, 1.0)
                let fall = t > 0.6 ? max(0, 1 - (t - 0.6) / 0.3) : 1.0
                let trem = 1 - 0.25 * (0.5 + 0.5 * sin(2 * .pi * 7 * t))
                let s = sin(2 * .pi * 82 * t)
                      + 0.6 * sin(2 * .pi * 123.5 * t)
                      + 0.4 * sin(2 * .pi * 41 * t)
                return s * 0.5 * rise * fall * trem * 0.5
            }

        case .playerDamage:
            // Dropping thud plus low-passed noise burst
            let d = 0.12
            return synthStateful(duration: d) { t, state in
                state.seed = state.seed &* 1_664_525 &+ 1_013_904_223
                let white = Double(state.seed >> 8) / Double(1 << 24) * 2 - 1
                state.lowpass += 0.12 * (white - state.lowpass)
                let thud = sin(sweepPhase(f0: 150, f1: 85, duration: d, t: t))
                return (thud * 0.7 + state.lowpass * 0.7) * envelope(t, duration: d, attack: 0.002) * 0.5
            }

        case .levelUp:
            // Rising arpeggio: C5, E5, G5
            let notes: [(freq: Double, start: Double, dur: Double)] = [
                (523.25, 0.0, 0.09),
                (659.25, 0.08, 0.09),
                (783.99, 0.16, 0.16)
            ]
            return synth(duration: 0.32) { t in
                var s = 0.0
                for note in notes where t >= note.start && t < note.start + note.dur {
                    let local = t - note.start
                    let env = envelope(local, duration: note.dur, attack: 0.005)
                    s += (sin(2 * .pi * note.freq * local)
                        + 0.15 * sin(2 * .pi * note.freq * 2 * local)) * env
                }
                return s * 0.3
            }

        case .buildHint:
            // Gentle bell — soft attack, two inharmonic partials, never shrill
            let d = 0.32
            return synth(duration: d) { t in
                let env = envelope(t, duration: d, attack: 0.03)
                let s = sin(2 * .pi * 660 * t) + 0.3 * sin(2 * .pi * 1056 * t)
                return s * env * 0.18
            }

        case .skyStrike:
            // Thunderbolt: a bright cracking transient over a rolling low rumble.
            // Loud and a little obnoxious on purpose — the Skybeam payoff.
            let d = 0.7
            return synthStateful(duration: d) { t, state in
                state.seed = state.seed &* 1_664_525 &+ 1_013_904_223
                let white = Double(state.seed >> 8) / Double(1 << 24) * 2 - 1
                // Heavy lowpass → deep rumble that lingers under the crack.
                state.lowpass += 0.04 * (white - state.lowpass)
                let rumble = state.lowpass * 2.4
                // Sharp broadband CRACK in the first ~70ms.
                let crack = t < 0.07 ? white * envelope(t, duration: 0.07, attack: 0.0008) * 0.85 : 0
                // Sub-bass boom under it.
                let boom = sin(2 * .pi * 58 * t) * 0.45
                let body = (rumble + boom) * envelope(t, duration: d, attack: 0.004)
                return (crack + body) * 0.55
            }

        case .bossExecute:
            // A deep, loud explosive boom + gore crunch — the boss-finish payoff.
            let d = 0.6
            return synthStateful(duration: d) { t, state in
                state.seed = state.seed &* 1_664_525 &+ 1_013_904_223
                let white = Double(state.seed >> 8) / Double(1 << 24) * 2 - 1
                state.lowpass += 0.05 * (white - state.lowpass)
                let boom = sin(sweepPhase(f0: 130, f1: 40, duration: d, t: t)) * 0.8
                let crunch = t < 0.12 ? white * envelope(t, duration: 0.12, attack: 0.001) * 0.7 : 0
                let rumble = state.lowpass * 2.2
                return (boom + crunch + rumble) * envelope(t, duration: d, attack: 0.003) * 0.62
            }
        }
    }

    // MARK: - Synth helpers

    private struct NoiseState {
        var seed: UInt32 = 0x5EED
        var lowpass: Double = 0
    }

    private static func makeBuffer(duration: Double) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(duration * sampleRate))
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(duration * sampleRate)
        return buffer
    }

    private static func synth(duration: Double, sample: (Double) -> Double) -> AVAudioPCMBuffer? {
        guard let buffer = makeBuffer(duration: duration),
              let data = buffer.floatChannelData?.pointee else { return nil }
        for i in 0..<Int(buffer.frameLength) {
            data[i] = Float(sample(Double(i) / sampleRate))
        }
        return buffer
    }

    private static func synthStateful(duration: Double,
                                      sample: (Double, inout NoiseState) -> Double) -> AVAudioPCMBuffer? {
        guard let buffer = makeBuffer(duration: duration),
              let data = buffer.floatChannelData?.pointee else { return nil }
        var state = NoiseState()
        for i in 0..<Int(buffer.frameLength) {
            data[i] = Float(sample(Double(i) / sampleRate, &state))
        }
        return buffer
    }

    /// Integrated phase for a linear frequency sweep (avoids chirp distortion)
    private static func sweepPhase(f0: Double, f1: Double, duration: Double, t: Double) -> Double {
        2 * .pi * (f0 * t + (f1 - f0) * t * t / (2 * duration))
    }

    /// Fast attack, squared decay to zero at `duration`
    private static func envelope(_ t: Double, duration: Double, attack: Double) -> Double {
        if t < attack { return t / attack }
        let rem = (t - attack) / max(duration - attack, 0.0001)
        let inv = max(0, 1 - rem)
        return inv * inv
    }
}
