import Observation
@Observable @MainActor final class NarawasViewModel {
    var session = PhaseSessionState()
    private(set) var selected: Int?
    func start() { selected = nil; session.start() }
    func choose(_ plot: Int) {
        guard session.isActive, (0..<3).contains(plot) else { return }
        selected = plot
        if plot == 1 { session.finish() }
        else { session.feedback = plot == 0 ? "Petak A merupakan kawasan lindung pada peta ini. Pilih lahan yang diizinkan." : "Petak C berada di zona mata air yang dilindungi pada peta ini. Coba petak lain." }
    }
    func demonstrate() { selected = 1; session.finish(.observed) }
}
