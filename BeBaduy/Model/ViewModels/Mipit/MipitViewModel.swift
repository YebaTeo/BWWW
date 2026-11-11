import Observation
import Foundation

@Observable @MainActor final class MipitViewModel {
    enum Step { case harvesting, harvestSuccess }
    static let harvestCount = 3
    var session = PhaseSessionState()
    private(set) var harvested: Set<Int> = []
    private(set) var lastHarvest: Int?
    private(set) var step: Step = .harvesting
    private(set) var isDemonstrating = false
    private var usedDemo = false
    @ObservationIgnored private var demo: Task<Void, Never>?

    init(motion: any MotionProviding) {}

    func start() {
        suspend()
        harvested = []; lastHarvest = nil; step = .harvesting; usedDemo = false
        session.start()
    }

    func harvest(_ index: Int) {
        guard session.isActive, step == .harvesting,
              (0..<Self.harvestCount).contains(index), harvested.insert(index).inserted else { return }
        lastHarvest = index
        ActivityAudio.shared.play(.harvest)
        if harvested.count == Self.harvestCount { step = .harvestSuccess }
    }

    func finishHarvest() {
        guard session.isActive, step == .harvestSuccess else { return }
        session.finish(usedDemo ? .observed : .performed)
    }

    func suspend() {
        demo?.cancel(); demo = nil
        isDemonstrating = false
    }

    func demonstrate() {
        guard session.isActive, step == .harvesting, !isDemonstrating else { return }
        isDemonstrating = true
        usedDemo = true
        demo = Task { [weak self] in
            for index in 0..<Self.harvestCount {
                guard let self, !Task.isCancelled else { return }
                self.harvest(index)
                do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
            }
            self?.isDemonstrating = false
        }
    }
}
