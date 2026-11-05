import Observation
@Observable @MainActor final class NgunjalViewModel {
    var session = PhaseSessionState()
    private(set) var reached = 0
    let checkpoints = ["Tepi huma", "Jalan pulang", "Leuit"]
    func start() { reached = 0; session.start() }
    func visit(_ waypoint: Int) {
        guard session.isActive, checkpoints.indices.contains(waypoint) else { return }
        guard waypoint == reached else { session.feedback = "Ikuti jalan dari titik berikutnya: \(checkpoints[min(reached, 2)])."; return }
        reached += 1; session.feedback = "Tiba di \(checkpoints[waypoint].lowercased())."
        if reached == 3 { session.finish() }
    }
    func demonstrate() { reached = 3; session.finish(.observed) }
}
