import Observation

@Observable @MainActor final class LeuitDiscoveryViewModel {
    enum Topic: Int, CaseIterable {
        case birth, marriage, death

        var title: String {
            switch self {
            case .birth: "Kelahiran"
            case .marriage: "Pernikahan"
            case .death: "Kematian"
            }
        }

        var choiceLabel: String {
            switch self {
            case .birth: "Pilih kartu pertama"
            case .marriage: "Pilih kartu kedua"
            case .death: "Pilih kartu ketiga"
            }
        }
    }

    enum Step: Equatable {
        case choosing, movingForward, awaitingReveal, revealing, revealed, finished
    }

    private(set) var step = Step.choosing
    private(set) var selected: Topic?
    private(set) var visit = 0

    func choose(_ topic: Topic) {
        guard step == .choosing else { return }
        selected = topic
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
