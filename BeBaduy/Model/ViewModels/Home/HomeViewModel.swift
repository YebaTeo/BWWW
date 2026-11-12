import Observation

@Observable @MainActor final class HomeViewModel {
    var path: [PhaseID] = []
    var showsCompletion = false

    func open(_ phase: PhaseID, journey: JourneyViewModel) {
        if !journey.progress.isUnlocked(phase) {
            for prior in PhaseID.allCases.prefix(phase.index) {
                if !journey.progress.record(for: prior).explanationAvailable {
                    journey.record(prior, outcome: .observed)
                }
            }
        }
        journey.open(phase)
        path = [phase]
    }
}
