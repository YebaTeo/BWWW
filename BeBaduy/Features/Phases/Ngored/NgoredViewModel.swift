import Observation
@Observable @MainActor final class NgoredViewModel {
    var session = PhaseSessionState()
    private(set) var removed: Set<Int> = []
    func start() { removed = []; session.start() }
    func remove(_ target: Int) {
        guard session.isActive else { return }
        guard (0..<4).contains(target) else { session.feedback = "Itu padi muda. Daunnya ramping dan tegak; pertahankan padi dan pilih gulma berdaun lebar pada ilustrasi."; return }
        guard removed.insert(target).inserted else { return }
        session.feedback = "Gulma \(target + 1) disingkirkan."
        if removed.count == 4 { session.finish() }
    }
    func demonstrate() { removed = Set(0..<4); session.finish(.observed) }
}
