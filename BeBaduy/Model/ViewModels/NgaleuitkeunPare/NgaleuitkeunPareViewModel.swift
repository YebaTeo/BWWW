import Observation
import Foundation
@Observable @MainActor final class NgaleuitkeunPareViewModel {
    var session = PhaseSessionState()
    private(set) var selected: Int?
    private(set) var storage: [Int: Int] = [:]
    private(set) var interiorVisible = false
    private(set) var isDemonstrating = false
    private var usedDemo = false
    @ObservationIgnored private var task: Task<Void, Never>?
    func start() { suspend(); selected = nil; storage = [:]; interiorVisible = false; usedDemo = false; session.start() }
    func select(_ bundle: Int) {
        guard session.isActive, (0..<3).contains(bundle), !storage.values.contains(bundle) else { return }
        selected = bundle; session.feedback = "Ikatan \(bundle + 1) dipilih. Ketuk leuit yang kosong."
    }
    @discardableResult func place(at space: Int) -> Bool {
        guard session.isActive, (0..<3).contains(space), let selected, storage[space] == nil, !storage.values.contains(selected) else { return false }
        storage[space] = selected; self.selected = nil
        ActivityAudio.shared.play(.bamboo)
        session.feedback = "\(storage.count) dari 3 leuit contoh terisi."
        return true
    }
    @discardableResult func drop(_ bundle: Int, at space: Int) -> Bool {
        guard (0..<3).contains(bundle), !storage.values.contains(bundle) else { return false }
        select(bundle); return place(at: space)
    }
    func inspectInterior() { guard session.isActive, storage.count == 3 else { return }; interiorVisible = true }
    func finish() { guard session.isActive, interiorVisible else { return }; session.finish(usedDemo ? .observed : .performed) }
    func suspend() { task?.cancel(); task = nil; isDemonstrating = false }
    func demonstrate() {
        guard session.isActive else { return }
        suspend(); usedDemo = true; isDemonstrating = true
        task = Task { [weak self] in
            guard let self else { return }
            for bundle in 0..<3 where !self.storage.values.contains(bundle) {
                do { try await Task.sleep(for: .milliseconds(800)) } catch { return }
                guard !Task.isCancelled else { return }
                if let space = (0..<3).first(where: { self.storage[$0] == nil }) { self.drop(bundle, at: space) }
            }
            self.inspectInterior()
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard !Task.isCancelled else { return }; self.finish(); self.isDemonstrating = false
        }
    }
}
