import Observation
import SwiftUI

enum HomeRoute: Hashable {
    case preview(PhaseID)
    case activity(PhaseID)
}

@Observable @MainActor final class HomeViewModel {
    var path: [HomeRoute] = []
    var showsCompletion = false

    func open(_ phase: PhaseID, journey: JourneyViewModel) {
        guard journey.progress.isUnlocked(phase) else { return }
        path = [.preview(phase)]
    }

    func start(_ phase: PhaseID, journey: JourneyViewModel) {
        guard journey.progress.isUnlocked(phase),
              case .some(.preview) = path.last else { return }
        journey.open(phase)
        if phase == .narawas {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { path.append(.activity(phase)) }
        } else {
            path.append(.activity(phase))
        }
    }
}
