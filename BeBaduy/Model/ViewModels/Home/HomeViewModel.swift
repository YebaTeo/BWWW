import Observation
import SwiftUI

@Observable @MainActor final class HomeViewModel {
    var path: [PhaseID] = []
    var showsCompletion = false

    func open(_ phase: PhaseID, journey: JourneyViewModel) {
        guard journey.progress.isUnlocked(phase) else { return }
        journey.open(phase)
        if phase == .narawas {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { path = [phase] }
        } else {
            path = [phase]
        }
    }
}
