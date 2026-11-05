import Observation
@Observable @MainActor final class NgahuruViewModel {
    var session = PhaseSessionState()
    private(set) var selected: Int?
    private(set) var slots: [Int?] = [nil, nil, nil]
    let cards = ["Hasil tebasan", "Tebasan kering", "Lahan setelah pembakaran"]
    let symbols = ["leaf", "sun.max", "square.3.layers.3d"]
    func start() { selected = nil; slots = [nil, nil, nil]; session.start() }
    func select(_ card: Int) {
        guard session.isActive, cards.indices.contains(card) else { return }
        selected = card; session.feedback = "Pilih posisi untuk \(cards[card].lowercased())."
    }
    func place(at position: Int) {
        guard session.isActive, slots.indices.contains(position), let card = selected else { return }
        for index in slots.indices where slots[index] == card { slots[index] = nil }
        slots[position] = card; selected = nil
        if slots.allSatisfy({ $0 != nil }) {
            if slots == [0, 1, 2] { session.finish() }
            else { session.feedback = "Belum berurutan. Hasil tebasan mengering dahulu, lalu lahan setelah pembakaran. Pilih kartu dan atur kembali posisinya." }
        }
    }
    func demonstrate() { slots = [0, 1, 2]; session.finish(.observed) }
}
