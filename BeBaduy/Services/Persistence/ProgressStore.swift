import Foundation
@MainActor protocol ProgressStoring {
    func load() -> JourneyProgress
    func save(_ progress: JourneyProgress) throws
    var recoveryMessage: String? { get }
}
@MainActor final class ProgressStore: ProgressStoring {
    private let defaults: UserDefaults
    private let key = "BeBaduy.journey.v2"
    private(set) var recoveryMessage: String?
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> JourneyProgress {
        if let data = defaults.data(forKey: key) {
            if var progress = try? JSONDecoder().decode(JourneyProgress.self, from: data) {
                if progress.version == 2 {
                    progress.version = 3
                    let harvest = progress.record(for: .mipit)
                    if harvest.explanationAvailable && harvest.outcome != nil {
                        progress.phases[PhaseID.ngalantai.rawValue] = harvest
                    }
                    if progress.isValid { try? save(progress); return progress }
                }
                if progress.isValid { return progress }
            }
            defaults.set(data, forKey: key + ".recovery")
            recoveryMessage = "Progres tidak dapat dibaca. Salinan data lama disimpan di perangkat."
            return JourneyProgress()
        }
        guard let data = defaults.data(forKey: "BeBaduy.journey.v1") else { return JourneyProgress() }
        struct Legacy: Decodable { let version: Int; let phases: [String: PhaseProgress] }
        guard let old = try? JSONDecoder().decode(Legacy.self, from: data), old.version == 1 else {
            defaults.set(data, forKey: "BeBaduy.journey.v1.recovery")
            recoveryMessage = "Progres lama tidak dapat dibaca. Data lama tetap disimpan."
            return JourneyProgress()
        }
        var progress = JourneyProgress()
        progress.introductionSeen = true
        for phase in PhaseID.allCases {
            let keys = phase == .ngalantai ? ["drying_rice"] : [phase.rawValue]
            guard keys.allSatisfy({ old.phases[$0]?.explanationAvailable == true && old.phases[$0]?.outcome != nil }) else { break }
            progress.complete(phase, outcome: .observed)
            progress.currentPhase = phase.next ?? phase
        }
        recoveryMessage = "Perjalanan kini memiliki enam bab. Bab lama yang sesuai ditandai pernah dijelajahi. Aktivitas baru dapat dicoba kembali; data lama tetap disimpan."
        try? save(progress)
        return progress
    }
    func save(_ progress: JourneyProgress) throws { defaults.set(try JSONEncoder().encode(progress), forKey: key) }
}
