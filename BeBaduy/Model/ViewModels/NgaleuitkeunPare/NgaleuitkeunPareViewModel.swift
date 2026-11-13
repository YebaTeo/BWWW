import Observation
import UIKit

@Observable @MainActor final class NgaleuitkeunPareViewModel {
    var session = PhaseSessionState()
    private(set) var isLadderPlaced = false
    private var usedDemo = false

    func start() {
        isLadderPlaced = false
        usedDemo = false
        session.start()
    }

    func placeLadder() {
        guard session.isActive, !isLadderPlaced else { return }
        isLadderPlaced = true
        ActivityAudio.shared.play(.bamboo)
        if !usedDemo { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    }

    func finish() {
        guard session.isActive, isLadderPlaced else { return }
        session.finish(usedDemo ? .observed : .performed)
    }

    func demonstrate() {
        guard session.isActive, !isLadderPlaced else { return }
        usedDemo = true
        placeLadder()
    }
}
