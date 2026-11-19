import Foundation
import Observation

@Observable @MainActor final class JourneyViewModel {
    private(set) var progress: JourneyProgress
    private(set) var storageMessage: String?
    func dismissStorageMessage() { storageMessage = nil }
    private let store: any ProgressStoring
    private var arrangedCollectionCardIDs: Set<String> = []
    init(store: any ProgressStoring) {
        self.store = store
        progress = store.load()
        storageMessage = store.recoveryMessage
        arrangedCollectionCardIDs = store.loadArrangedCollectionCards()
    }
    var completedCount: Int { PhaseID.allCases.filter { progress.record(for: $0).explanationAvailable }.count }
    func open(_ phase: PhaseID) {
        guard progress.isUnlocked(phase) else { return }
        progress.currentPhase = phase; persist()
    }
    private(set) var newlyEarnedCards: [ChapterCard] = []

    var pendingCollectionCards: [ChapterCard] {
        ChapterCard.all.filter { $0.isEarned(in: progress) && !arrangedCollectionCardIDs.contains($0.imageName) }
    }

    var hasPendingCollectionArrangement: Bool { !pendingCollectionCards.isEmpty }

    func markCollectionArrangementSeen() {
        let earnedIDs = ChapterCard.all
            .filter { $0.isEarned(in: progress) }
            .map(\.imageName)
        let updated = arrangedCollectionCardIDs.union(earnedIDs)
        guard updated != arrangedCollectionCardIDs else { return }
        arrangedCollectionCardIDs = updated
        store.saveArrangedCollectionCards(updated)
    }

    func record(_ phase: PhaseID, outcome: ActivityOutcome) {
        let previous = progress
        progress.complete(phase, outcome: outcome)
        newlyEarnedCards = ChapterCard.all.filter { !$0.isEarned(in: previous) && $0.isEarned(in: progress) }
        persist()
    }
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
        newlyEarnedCards = []
        arrangedCollectionCardIDs = []
        store.saveArrangedCollectionCards([])
        progress = JourneyProgress()
        progress.introductionSeen = true
        persist()
    }
    private func persist() {
        do { try store.save(progress); storageMessage = nil }
        catch { storageMessage = "Progres belum tersimpan. Coba lagi dengan membuka tahap ini kembali." }
    }
}
