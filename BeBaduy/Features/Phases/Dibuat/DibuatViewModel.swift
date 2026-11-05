import Observation
@Observable @MainActor final class DibuatViewModel {
    var session = PhaseSessionState()
    private(set) var harvested: Set<Int> = []
    func start() { harvested = []; session.start() }
    func harvest(_ head: Int) {
        guard session.isActive, (0..<4).contains(head), harvested.insert(head).inserted else { return }
        session.feedback = "Malai \(head + 1) dikumpulkan bersama tangkainya."
        if harvested.count == 4 { session.finish() }
    }
    func demonstrate() { harvested = Set(0..<4); session.finish(.observed) }
}
