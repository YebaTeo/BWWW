import Observation
@Observable @MainActor final class HomeViewModel {
    var path: [PhaseID] = []
    var showsCompletion = false
    func open(_ phase: PhaseID, journey: JourneyViewModel) {
        guard journey.progress.isUnlocked(phase) else { return }
        journey.open(phase); path = [phase]
    }
}
