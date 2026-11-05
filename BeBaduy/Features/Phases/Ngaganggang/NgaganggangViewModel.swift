import Observation
@Observable @MainActor final class NgaganggangViewModel {
    var session = PhaseSessionState()
    private(set) var position = 0.0
    private(set) var visited: Set<Int> = []
    let states = ["Masih basah", "Mulai kering", "Sudah kering"]
    func start() { position = 0; visited = []; session.start() }
    func visit(_ value: Double) {
        guard session.isActive, value.isFinite, (0...2).contains(value) else { return }
        position = value.rounded(); let checkpoint = Int(position)
        visited.insert(checkpoint); session.feedback = states[checkpoint]
        if visited.count == 3 { session.finish() }
    }
    func demonstrate() { position = 2; visited = Set(0..<3); session.finish(.observed) }
}
