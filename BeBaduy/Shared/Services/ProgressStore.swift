import Foundation

@MainActor protocol ProgressStoring {
    func load() -> JourneyProgress
    func save(_ progress: JourneyProgress) throws
    var recoveryMessage: String? { get }
}

@MainActor final class ProgressStore: ProgressStoring {
    private let defaults: UserDefaults
    private let key = "BeBaduy.journey.v1"
    private(set) var recoveryMessage: String?
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> JourneyProgress {
        guard let data = defaults.data(forKey: key) else { return JourneyProgress() }
        guard let progress = try? JSONDecoder().decode(JourneyProgress.self, from: data), progress.isValid else {
            // Preserve unreadable data for recovery rather than silently destroying it.
            defaults.set(data, forKey: key + ".recovery")
            recoveryMessage = "Progres lama tidak dapat dibaca. Perjalanan baru tersedia; salinan data lama disimpan di perangkat."
            return JourneyProgress()
        }
        return progress
    }
    func save(_ progress: JourneyProgress) throws { defaults.set(try JSONEncoder().encode(progress), forKey: key) }
}
