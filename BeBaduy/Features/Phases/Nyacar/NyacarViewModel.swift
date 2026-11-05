import Observation
@Observable @MainActor final class NyacarViewModel {
    var session = PhaseSessionState()
    private(set) var cleared: Set<Int> = []
    func start() { cleared = []; session.start() }
    func clear(_ target: Int) {
        guard session.isActive else { return }
        guard (0..<4).contains(target) else { session.feedback = "Pohon berguna ditandai untuk dipertahankan. Pilih semak atau cabang bertanda tebas."; return }
        guard cleared.insert(target).inserted else { return }
        session.feedback = "Bagian \(target + 1) dibersihkan. Pohon berguna tetap dijaga."
        if cleared.count == 4 { session.finish() }
    }
    func demonstrate() { cleared = Set(0..<4); session.finish(.observed) }
}
