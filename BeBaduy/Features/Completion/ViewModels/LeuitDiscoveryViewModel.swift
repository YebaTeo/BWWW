import Observation

@Observable @MainActor final class LeuitDiscoveryViewModel {
    enum Step: Equatable {
        case choosing, movingForward, awaitingReveal, revealing, revealed, finished
    }

    private(set) var step = Step.choosing
    private(set) var selected: Int?
    private(set) var visit = 0

    private let cardCount: Int

    init(cardCount: Int) {
        self.cardCount = cardCount
    }

    func choose(_ index: Int) {
        guard step == .choosing, (0..<cardCount).contains(index) else { return }
        selected = index
        step = .movingForward
    }

    func finishMoving(visit: Int) {
        guard self.visit == visit, step == .movingForward else { return }
        step = .awaitingReveal
    }

    func reveal() {
        guard step == .awaitingReveal else { return }
        step = .revealing
    }

    func finishRevealing(visit: Int) {
        guard self.visit == visit, step == .revealing else { return }
        step = .revealed
    }

    func finish() -> Bool {
        guard step == .revealed else { return false }
        step = .finished
        return true
    }

    func reset() {
        visit += 1
        step = .choosing
        selected = nil
    }
}
