import AVFoundation
import Observation

/// Synthesized acoustic sound effects for the Ngahuma farming journey.
@Observable @MainActor final class ActivityAudio {
    enum Cue: Hashable {
        case cut
        case woodCrack
        case treeFall
        case ignite
        case dig
        case seed
        case weed
        case harvest
        case bamboo
        case rain
    }

    static let shared = ActivityAudio()
    var enabled = true {
        didSet {
            if !enabled { stop() }
        }
    }

    @ObservationIgnored private var activePlayers: [AVAudioPlayer] = []
    @ObservationIgnored private var loopPlayer: AVAudioPlayer?
    @ObservationIgnored private var cache: [Cue: Data] = [:]

    private init() {}

    func stop() {
        loopPlayer?.stop()
        loopPlayer = nil
        activePlayers.forEach { $0.stop() }
        activePlayers.removeAll()
    }

    func play(_ cue: Cue) {
        guard enabled else { return }
        if cue == .rain {
            loopPlayer?.stop()
            loopPlayer = nil
        }
        let wav = cache[cue] ?? {
            let loaded = Self.audioData(for: cue)
            cache[cue] = loaded
            return loaded
        }()
        do {
            // Ambient honors the phone's silent switch and does not interrupt other audio.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            let player = try AVAudioPlayer(data: wav)
            if cue == .rain {
                player.numberOfLoops = -1
                player.volume = 0.55
                player.play()
                loopPlayer = player
            } else {
                activePlayers.removeAll { !$0.isPlaying }
                if activePlayers.count >= 4, let oldest = activePlayers.first {
                    oldest.stop()
                    activePlayers.removeFirst()
                }
                player.volume = cue == .ignite ? 1.0 : 0.78
                player.play()
                activePlayers.append(player)
            }
        } catch {}
    }

    private static func audioData(for cue: Cue) -> Data {
        if cue == .ignite,
           let url = Bundle.main.url(forResource: "ngahuma-ignite", withExtension: "wav"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return synthesizeWAV(for: cue)
    }

    private static func synthesizeWAV(for cue: Cue) -> Data {
        let rate = 44100
        let duration: Double
        switch cue {
        case .cut: duration = 0.38
        case .woodCrack: duration = 0.48
        case .treeFall: duration = 0.85
        case .ignite: duration = 0.64
        case .dig: duration = 0.30
        case .seed: duration = 0.42
        case .weed: duration = 0.28
        case .harvest: duration = 0.26
        case .bamboo: duration = 0.32
        case .rain: duration = 2.40
        }

        let count = Int(duration * Double(rate))
        var samples = Data(capacity: count * 2)
        var rng: UInt32 = 0x6D2B79F5 &+ UInt32(cue.hashValue.magnitude & 0xFFFF)
        var lowpass: Double = 0
        var bandpass: Double = 0
        var warmLow: Double = 0
        var subLow1: Double = 0
        var subLow2: Double = 0

        for index in 0..<count {
            let t = Double(index) / Double(rate)
            rng = 1664525 &* rng &+ 1013904223
            let white = Double(rng) / Double(UInt32.max) * 2.0 - 1.0
            lowpass = lowpass * 0.88 + white * 0.12
            bandpass = (white - lowpass) * 0.55 + bandpass * 0.45
            warmLow = warmLow * 0.955 + white * 0.045
            subLow1 = subLow1 * 0.982 + white * 0.018
            subLow2 = subLow2 * 0.982 + subLow1 * 0.018

            let signal: Double
            switch cue {
            case .cut:
                // Deep, heavy golok/bedog chop into dense hardwood trunk (low-pitched thwack)
                let strikeEnv = exp(-t * 28.0)
                let woodEnv = exp(-t * 14.0)
                let freq = 52.0 * exp(-t * 15.0) + 40.0
                let woodBody = sin(2.0 * .pi * freq * t) * 0.68
                    + sin(2.0 * .pi * (freq * 1.48) * t) * 0.34 * exp(-t * 22.0)
                let woodKnock = (subLow2 * 1.6 + warmLow * 0.65) * strikeEnv
                signal = (woodBody * woodEnv + woodKnock) * 0.84

            case .woodCrack:
                // Deep, low-pitched heavy timber groan & bass fiber splits as the trunk hinges
                let snaps: [(time: Double, freq: Double, amp: Double)] = [
                    (0.00, 62.0, 0.88),
                    (0.075, 52.0, 0.78),
                    (0.165, 68.0, 0.92),
                    (0.260, 44.0, 0.80)
                ]
                var acc = 0.0
                for snap in snaps where t >= snap.time {
                    let dt = t - snap.time
                    let env = exp(-dt * 22.0)
                    let pitch = snap.freq * exp(-dt * 5.5) + 26.0
                    let creak = (
                        sin(2.0 * .pi * pitch * dt) * 0.68
                        + sin(2.0 * .pi * (pitch * 0.5) * dt) * 0.38
                        + subLow2 * 1.4
                        + warmLow * 0.45
                    ) * env * snap.amp
                    acc += creak
                }
                signal = acc * 0.76

            case .treeFall:
                // Low-pitched heavy canopy displacement whoosh (0..0.32s) + deep sub-bass ground boom
                let swooshEnv = sin(min(1.0, t / 0.34) * .pi)
                let fallGlideFreq = 58.0 * exp(-t * 4.2) + 24.0
                let swoosh = (
                    subLow2 * 1.85
                    + warmLow * 0.42
                    + sin(2.0 * .pi * fallGlideFreq * t) * 0.32
                ) * swooshEnv * 0.58

                let impactT = max(0.0, t - 0.28)
                let impactEnv = t >= 0.28 ? exp(-impactT * 7.8) : 0.0
                let subFreq = 34.0 * exp(-impactT * 7.0) + 24.0
                let bodyFreq = 64.0 * exp(-impactT * 9.5) + 32.0
                let thud = (
                    sin(2.0 * .pi * subFreq * impactT) * 0.78
                    + sin(2.0 * .pi * bodyFreq * impactT) * 0.48 * exp(-impactT * 12.0)
                ) * impactEnv
                let earthRumble = (subLow2 * 2.1 + warmLow * 0.35) * (t >= 0.28 ? exp(-impactT * 5.8) : 0.0)
                signal = (swoosh + thud + earthRumble) * 0.86

            case .ignite:
                // Realistic wooden match (korek api):
                // 1) Coarse phosphorus strip scrape (0.00..0.095s)
                // 2) Bold chemical match-head pop & sulfur sizzle (0.075..0.26s)
                // 3) Warm flame bloom catching the dry brush (0.10..0.64s)
                var matchSignal = 0.0

                // Stage 1: Gritty matchstick drag across coarse striker strip
                if t < 0.098 {
                    let scrapeProgress = t / 0.098
                    let scrapeEnv = sin(scrapeProgress * .pi) * (0.45 + 0.55 * scrapeProgress)
                    // Irregular sandpaper grit modulation as match head catches abrasive grains
                    let gritMod = 0.50
                        + 0.30 * sin(2.0 * .pi * 175.0 * t + sin(2.0 * .pi * 43.0 * t) * 2.4)
                        + 0.20 * cos(2.0 * .pi * 310.0 * t)
                    let sweepFreq = 680.0 + scrapeProgress * 1150.0
                    let stripResonance = sin(2.0 * .pi * sweepFreq * t) * 0.28
                    let woodStickContact = sin(2.0 * .pi * 240.0 * t) * exp(-t * 48.0) * 0.55
                    let coarseFriction = (bandpass * 0.72 + (lowpass - warmLow) * 0.95 + stripResonance) * gritMod
                    matchSignal += (coarseFriction * scrapeEnv * 1.15) + woodStickContact
                }

                // Stage 2: Bold chemical ignition pop & rapid phosphorus/sulfur sizzle
                if t >= 0.074 {
                    let dt = t - 0.074
                    // Punchy chemical head burst ("pop-fzzzt")
                    let popEnv = exp(-dt * 38.0)
                    let popFreq = 145.0 * exp(-dt * 14.0) + 54.0
                    let headPop = (
                        sin(2.0 * .pi * popFreq * dt) * 0.85
                        + warmLow * 1.35
                        + bandpass * 0.55
                    ) * popEnv

                    // Dense chemical fizzing micro-sparks as the match head flares
                    let sizzleEnv = sin(min(1.0, dt / 0.19) * .pi) * exp(-dt * 6.5)
                    let crackleGate = sin(2.0 * .pi * 230.0 * dt) * cos(2.0 * .pi * 390.0 * dt) > 0.12 ? 1.35 : 0.45
                    let sulfurFizz = (bandpass * 0.68 + (lowpass - warmLow) * 0.82) * sizzleEnv * crackleGate * 0.78

                    matchSignal += headPop + sulfurFizz
                }

                // Stage 3: Bold, warm flame bloom & kindling crackle
                if t >= 0.095 {
                    let ft = t - 0.095
                    let bloomEnv = sin(min(1.0, ft / 0.54) * .pi) * exp(-ft * 2.2)
                    let flameTurbulence = 0.78 + 0.22 * sin(2.0 * .pi * 24.0 * ft)
                    let flameRoar = (
                        subLow2 * 1.95
                        + warmLow * 0.95
                        + sin(2.0 * .pi * (72.0 - min(24.0, ft * 40.0)) * ft) * 0.28
                    ) * bloomEnv * flameTurbulence
                    matchSignal += flameRoar * 0.92
                }

                signal = matchSignal * 0.92

            case .dig:
                // Heavy Aseuk bamboo pole stabbing deep into huma soil (deep sub-thud + earthen crunch)
                let thumpEnv = exp(-t * 16.0)
                let crunchEnv = exp(-t * 12.0)
                let poleFreq = 68.0 * exp(-t * 9.5) + 34.0
                let poleThump = (
                    sin(2.0 * .pi * poleFreq * t) * 0.76
                    + sin(2.0 * .pi * (poleFreq * 1.65) * t) * 0.34 * exp(-t * 22.0)
                ) * thumpEnv
                let soilCrunch = (subLow2 * 1.65 + warmLow * 0.72 + bandpass * 0.28) * crunchEnv * 0.58
                signal = (poleThump + soilCrunch) * 0.88

            case .seed:
                // Cascading dry rice grains (gabah) pattering into the soil hole
                let grains: [Double] = [0.00, 0.038, 0.072, 0.115, 0.158, 0.205, 0.255, 0.310]
                var patter = 0.0
                for (i, gTime) in grains.enumerated() where t >= gTime {
                    let dt = t - gTime
                    let grainFreq = 680.0 + Double((i * 97) % 340)
                    let env = exp(-dt * 55.0)
                    patter += (sin(2.0 * .pi * grainFreq * dt) * 0.45 + bandpass * 0.65) * env * 0.42
                }
                signal = patter * 0.75

            case .weed:
                // Kored blade scraping soil and fibrous weed roots
                let scrapeEnv = sin(min(1.0, t / duration) * .pi) * exp(-t * 4.5)
                let rootMod = 0.65 + 0.35 * sin(2.0 * .pi * 28.0 * t)
                let scrape = (bandpass * 0.70 + lowpass * 0.45) * rootMod * scrapeEnv
                signal = scrape * 0.62

            case .harvest:
                // Crisp etem / ani-ani stalk snip + dry golden rice straw rustle
                let snipEnv = exp(-t * 38.0)
                let snip = (sin(2.0 * .pi * 1380.0 * t) * 0.35 + sin(2.0 * .pi * 540.0 * t) * 0.35 + bandpass * 0.60) * snipEnv
                let rustleT = max(0.0, t - 0.03)
                let rustle = bandpass * (t >= 0.03 ? exp(-rustleT * 12.0) * 0.42 : 0.0)
                signal = (snip + rustle) * 0.72

            case .bamboo:
                // Hollow Sundanese bamboo resonance + gentle rice bundle brush
                let env = exp(-t * 14.0)
                let overtoneEnv = exp(-t * 26.0)
                let hollow = sin(2.0 * .pi * 248.0 * t) * 0.58 * env
                    + sin(2.0 * .pi * 642.0 * t) * 0.28 * overtoneEnv
                    + bandpass * exp(-t * 20.0) * 0.25
                signal = hollow * 0.70

            case .rain:
                // Gentle tropical huma rain with soft leaf droplet patters and seamless loop fade
                let loopFade = min(1.0, min(t / 0.12, (duration - t) / 0.12))
                let dropMod = pow(max(0.0, sin(2.0 * .pi * 19.0 * t + sin(2.0 * .pi * 7.0 * t))), 8.0) * 0.22
                let rainWash = lowpass * 0.55 + bandpass * (0.28 + dropMod)
                signal = rainWash * 0.24 * loopFade
            }

            let clamped = max(-1.0, min(1.0, signal))
            var pcm = Int16(clamped * 32767.0).littleEndian
            withUnsafeBytes(of: &pcm) { samples.append(contentsOf: $0) }
        }

        var wav = Data()
        func word<T: FixedWidthInteger>(_ number: T) {
            var little = number.littleEndian
            withUnsafeBytes(of: &little) { wav.append(contentsOf: $0) }
        }
        wav.append(Data("RIFF".utf8))
        word(UInt32(36 + samples.count))
        wav.append(Data("WAVEfmt ".utf8))
        word(UInt32(16))
        word(UInt16(1))
        word(UInt16(1))
        word(UInt32(rate))
        word(UInt32(rate * 2))
        word(UInt16(2))
        word(UInt16(16))
        wav.append(Data("data".utf8))
        word(UInt32(samples.count))
        wav.append(samples)
        return wav
    }
}
