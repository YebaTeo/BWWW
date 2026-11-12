import Observation
import Foundation
@Observable @MainActor final class NgoredViewModel {
    enum Step { case weeding, cleared, rain }
    var session = PhaseSessionState()
    private(set) var removed: Set<Int> = []
    private(set) var lastRemoved: Int?
    private(set) var strokes: [Int: Int] = [:]
    private(set) var step: Step = .weeding
    private(set) var isDemonstrating = false
    private var usedDemo = false
    @ObservationIgnored private var task: Task<Void, Never>?
    func start() { suspend(); removed = []; strokes = [:]; lastRemoved = nil; step = .weeding; usedDemo = false; session.start() }
    func remove(_ target: Int) {
        guard session.isActive, step == .weeding else { return }
        guard (0..<8).contains(target) else { session.feedback = "Ini padi. Bersihkan gulma di sekitarnya."; return }
        guard !removed.contains(target) else { return }
        strokes[target, default: 0] += 1
        ActivityAudio.shared.play(.weed)
        session.feedback = "Gulma \(target + 1): \(strokes[target] ?? 0)/3 sapuan."
        guard strokes[target] == 3 else { return }
        removed.insert(target)
        lastRemoved = target
        session.feedback = "\(removed.count) dari 8 gulma disingkirkan."
        if removed.count == 8 { step = .cleared }
    }
    func observeRain() { guard session.isActive, step == .cleared else { return }; step = .rain; ActivityAudio.shared.play(.rain) }
    func finishRain() { guard session.isActive, step == .rain else { return }; ActivityAudio.shared.stop(); session.finish(usedDemo ? .observed : .performed) }
    func setVisible(_ value: Bool) { if value && step == .rain { ActivityAudio.shared.play(.rain) } else if !value { suspend() } }
    func suspend() { ActivityAudio.shared.stop(); task?.cancel(); task = nil; isDemonstrating = false }
    func demonstrate() {
        guard session.isActive else { return }
        suspend(); usedDemo = true; isDemonstrating = true
        task = Task { [weak self] in
            for index in 0..<8 {
                for _ in 0..<3 {
                    do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                    guard !Task.isCancelled, let self else { return }; self.remove(index)
                }
            }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard !Task.isCancelled, let self else { return }; self.observeRain()
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard !Task.isCancelled else { return }; self.finishRain(); self.isDemonstrating = false
        }
    }
}
