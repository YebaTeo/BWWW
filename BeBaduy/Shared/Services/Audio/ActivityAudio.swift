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
        case cardFlip
        case cardGlow
    }

    static let shared = ActivityAudio()
    var enabled = true {
        didSet {
            if !enabled { stop() }
        }
    }

    private let playback = ActivityPlayback()

    private init() {}

    func stop() {
        playback.queue.async { [playback] in playback.stop() }
    }

    func play(_ cue: Cue) {
        guard enabled else { return }
        playback.queue.async { [playback] in playback.play(cue) }
    }
}

// Player creation, session configuration and playback share one FIFO queue.
// A stop enqueued after a tap also stops audio that was still opening on disk.
private final class ActivityPlayback: @unchecked Sendable {
    let queue = DispatchQueue(label: "org.bebaduy.activity-audio", qos: .userInitiated)
    private var activePlayers: [AVAudioPlayer] = []
    private var loopPlayer: AVAudioPlayer?

    func stop() {
        loopPlayer?.stop()
        loopPlayer = nil
        activePlayers.forEach { $0.stop() }
        activePlayers.removeAll()
    }

    func play(_ cue: ActivityAudio.Cue) {
        if cue == .rain {
            loopPlayer?.stop()
            loopPlayer = nil
        }
        let resource = cue == .ignite ? "ngahuma-ignite" : "activity-\(cue.rawValue)"
        let fileExtension = switch cue {
        case .cardFlip, .cardGlow: "mp3"
        default: "wav"
        }
        guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension) else { return }
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
                player.volume = switch cue {
                case .ignite: 1.0
                case .cardFlip: 0.9
                case .cardGlow: 0.85
                default: 0.78
                }
                player.play()
                activePlayers.append(player)
            }
        } catch {}
    }

}
