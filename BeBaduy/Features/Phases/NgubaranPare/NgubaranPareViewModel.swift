import Observation
@Observable @MainActor final class NgubaranPareViewModel {
    var session = PhaseSessionState()
    let names = ["Mengkudu", "Laja / lengkuas", "Kelapa"]
    let details = ["Buah lonjong dengan permukaan bertotol", "Rimpang beruas di pangkal batang berdaun", "Buah bulat bersabut pada pohon berpelepah"]
    private(set) var matched: Set<Int> = []
    private(set) var selected: Int?
    func start() { matched = []; selected = nil; session.start() }
    func select(_ plant: Int) {
        guard session.isActive, names.indices.contains(plant), !matched.contains(plant) else { return }
        selected = plant; session.feedback = "Ilustrasi \(plant + 1) dipilih. Pilih nama yang cocok."
    }
    func match(_ name: Int) {
        guard session.isActive, names.indices.contains(name), let selected else { return }
        guard name == selected else { session.feedback = "Belum cocok. Bandingkan bentuk buah atau rimpang dengan kartu acuan."; return }
        matched.insert(name); self.selected = nil; session.feedback = "Cocok: \(names[name])."
        if matched.count == 3 { session.finish() }
    }
    func demonstrate() { matched = Set(0..<3); session.finish(.observed) }
}
