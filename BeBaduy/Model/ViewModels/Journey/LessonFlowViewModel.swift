import Observation

/// Presentation state only; completion stays in JourneyViewModel.
@Observable @MainActor final class LessonFlowViewModel {
    enum Screen { case introduction, equipment, activity, result, explanation }
    private(set) var screen: Screen = .introduction
    private(set) var canSkip = false
    func restore(completed: Bool) { canSkip = completed }
    func explore(hasEquipment: Bool) { screen = hasEquipment ? .equipment : .activity }
    func beginActivity() { screen = .activity }
    func completed() {
        guard screen == .activity else { return }
        canSkip = true
        screen = .result
    }
    func explain() {
        guard canSkip else { return }
        screen = .explanation
    }
    func replay() { screen = .activity }
}
