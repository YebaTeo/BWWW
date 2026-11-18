import Observation
import SwiftUI

enum HomeRoute: Hashable {
    case transition(PhaseID)
    case activity(PhaseID)
}

@Observable @MainActor final class HomeViewModel {
    var path: [HomeRoute] = []
    var showsCompletion = false

    func open(_ phase: PhaseID, journey: JourneyViewModel) {
        guard journey.progress.isUnlocked(phase) else { return }
        journey.open(phase)
        path = [.activity(phase)]
    }
}
