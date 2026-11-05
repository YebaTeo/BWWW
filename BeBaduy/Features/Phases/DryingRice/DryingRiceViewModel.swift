import Observation
@Observable @MainActor final class DryingRiceViewModel {
    var session = PhaseSessionState()
    private(set) var selected: Int?
    private(set) var rack: [Int: Int] = [:]
    func start() { selected = nil; rack = [:]; session.start() }
    func select(_ group: Int) {
        guard session.isActive, (0..<3).contains(group), !rack.values.contains(group) else { return }
        selected = group; session.feedback = "Kelompok \(group + 1) dipilih. Pilih tempat kosong di rak."
    }
    func place(at slot: Int) {
        guard session.isActive, (0..<3).contains(slot), let selected else { return }
        guard rack[slot] == nil else { session.feedback = "Tempat ini sudah terisi. Pilih tempat kosong."; return }
        rack[slot] = selected; self.selected = nil
        session.feedback = "Padi diletakkan di rak bambu."
        if rack.count == 3 { session.finish() }
    }
    func demonstrate() { rack = [0:0, 1:1, 2:2]; session.finish(.observed) }
}
