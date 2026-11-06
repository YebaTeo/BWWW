import Foundation
import Observation

@Observable @MainActor final class JourneyViewModel {
    private(set) var progress: JourneyProgress
    private(set) var storageMessage: String?
    private let store: any ProgressStoring
    init(store: any ProgressStoring) {
        self.store = store; progress = store.load(); storageMessage = store.recoveryMessage
    }
    var completedCount: Int { PhaseID.allCases.filter { progress.record(for: $0).explanationAvailable }.count }
    func open(_ phase: PhaseID) {
        guard progress.isUnlocked(phase) else { return }
        progress.currentPhase = phase; persist()
    }
    func record(_ phase: PhaseID, outcome: ActivityOutcome) { progress.complete(phase, outcome: outcome); persist() }
    func continueFrom(_ phase: PhaseID) -> PhaseID? {
        guard progress.record(for: phase).explanationAvailable, let next = phase.next else { return nil }
        open(next); return next
    }
    func finishJourney() {
        guard progress.allComplete else { return }
        progress.journeyCompleted = true; persist()
    }
    func finishIntroduction() { progress.introductionSeen = true; persist() }
    func restart() {
        progress = JourneyProgress()
        progress.introductionSeen = true
        persist()
    }
    private func persist() {
        do { try store.save(progress) }
        catch { storageMessage = "Progres belum tersimpan. Coba lagi dengan membuka tahap ini kembali." }
    }
}
