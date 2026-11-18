import AVFoundation
import Observation

/// Synthesized acoustic sound effects for the Ngahuma farming journey.
@Observable @MainActor final class ActivityAudio {
    enum Cue: String {
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
        let resource = cue == .ignite ? "ngahuma-ignite" : "activity-\(cue.rawValue)"
        guard let url = Bundle.main.url(forResource: resource, withExtension: "wav") else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            if session.category != .ambient || session.mode != .default {
                try session.setCategory(.ambient, mode: .default)
            }
            let player = try AVAudioPlayer(contentsOf: url)
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

}
