import Observation
@Observable @MainActor final class NgaleuitkeunPareViewModel {
    var session = PhaseSessionState()
    private(set) var selected: Int?
    private(set) var storage: [Int: Int] = [:]
    func start() { selected = nil; storage = [:]; session.start() }
    func select(_ bundle: Int) {
        guard session.isActive, (0..<3).contains(bundle), !storage.values.contains(bundle) else { return }
        selected = bundle; session.feedback = "Ikatan \(bundle + 1) dipilih. Pilih ruang ilustrasi yang kosong."
    }
    func place(at space: Int) {
        guard session.isActive, (0..<3).contains(space), let selected else { return }
        guard storage[space] == nil else { session.feedback = "Ruang ini sudah terisi. Pilih ruang kosong lainnya."; return }
        storage[space] = selected; self.selected = nil
        if storage.count == 3 { session.finish() }
    }
    func demonstrate() { storage = [0:0, 1:1, 2:2]; session.finish(.observed) }
}
