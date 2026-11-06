import AVFoundation
import Observation

/// Lightweight, synthesized activity cues; these are not recordings of Baduy rituals.
@Observable @MainActor final class ActivityAudio {
    enum Cue { case cut, dig, seed, harvest, bamboo, rain }
    static let shared = ActivityAudio()
    var enabled = true { didSet { if !enabled { stop() } } }
    @ObservationIgnored private var player: AVAudioPlayer?
    private init() {}
    func stop() { player?.stop(); player = nil }
    func play(_ cue: Cue) {
        guard enabled else { return }
        stop()
        let rate = 22050
        let duration: Double = cue == .rain ? 2 : cue == .cut ? 0.5 : 0.22
        let count = Int(duration * Double(rate))
        var samples = Data(capacity: count * 2)
        var noise: UInt32 = 17
        var smoothed: Double = 0
        for index in 0..<count {
            let t = Double(index) / Double(rate)
            noise = 1664525 &* noise &+ 1013904223
            let random = Double(noise) / Double(UInt32.max) * 2 - 1
            smoothed = smoothed * 0.8 + random * 0.2
            let envelope = cue == .rain ? 0.12 : exp(-t * (cue == .cut ? 8 : 22)) * 0.3
            let tone: Double
            switch cue {
            case .cut: tone = smoothed + sin(t * 2 * .pi * 120) * 0.5
            case .dig: tone = smoothed + sin(t * 2 * .pi * 80) * 0.4
            case .seed: tone = random * (sin(t * 2 * .pi * 35) > 0.6 ? 0.6 : 0.1)
            case .harvest: tone = random * 0.5
            case .bamboo: tone = sin(t * 2 * .pi * (320 - t * 400)) * 0.5 + smoothed * 0.2
            case .rain: tone = smoothed
            }
            var value = Int16(max(-1, min(1, tone * envelope)) * 32767).littleEndian
            withUnsafeBytes(of: &value) { samples.append(contentsOf: $0) }
        }
        var wav = Data()
        func word<T: FixedWidthInteger>(_ number: T) {
            var little = number.littleEndian
            withUnsafeBytes(of: &little) { wav.append(contentsOf: $0) }
        }
        wav.append(Data("RIFF".utf8)); word(UInt32(36 + samples.count)); wav.append(Data("WAVEfmt ".utf8))
        word(UInt32(16)); word(UInt16(1)); word(UInt16(1)); word(UInt32(rate)); word(UInt32(rate * 2))
        word(UInt16(2)); word(UInt16(16)); wav.append(Data("data".utf8)); word(UInt32(samples.count)); wav.append(samples)
        do {
            // Ambient honors the phone's silent switch and does not interrupt other audio.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            player = try AVAudioPlayer(data: wav)
            player?.numberOfLoops = cue == .rain ? -1 : 0
            player?.play()
        } catch { player = nil }
    }
}
