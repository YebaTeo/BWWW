import XCTest
@testable import BeBaduy

@MainActor final class MemoryStore: ProgressStoring {
    var value = JourneyProgress()
    var recoveryMessage: String?
    var writes = 0
    var arrangedCardIDs: Set<String> = []
    func load() -> JourneyProgress { value }
    func save(_ progress: JourneyProgress) throws { value = progress; writes += 1 }
    func loadArrangedCollectionCards() -> Set<String> { arrangedCardIDs }
    func saveArrangedCollectionCards(_ cardIDs: Set<String>) { arrangedCardIDs = cardIDs }
}
final class JourneyTests: XCTestCase {
    @MainActor func testCycleCardAwardsSurviveRelaunchAndReplay() {
        let store = MemoryStore()
        let journey = JourneyViewModel(store: store)
        for phase in PhaseID.allCases {
            journey.record(phase, outcome: .observed)
            XCTAssertEqual(journey.newlyEarnedCards, phase.next == nil ? [.epic] : [.chapter(phase)])
            journey.record(phase, outcome: .performed)
            XCTAssertTrue(journey.newlyEarnedCards.isEmpty)
        }
        let restored = JourneyViewModel(store: store)
        XCTAssertTrue(ChapterCard.epic.isEarned(in: restored.progress))
        restored.record(.ngaleuitkeunPare, outcome: .performed)
        XCTAssertTrue(restored.newlyEarnedCards.isEmpty)
    }

    func testCatalogAndResources() {
        XCTAssertEqual(PhaseCatalog.all.map(\.id), PhaseID.allCases)
        XCTAssertEqual(PhaseID.allCases.count, 6)
        XCTAssertEqual(PhaseCatalog.all.map(\.title), ["Narawas", "Ngaseuk", "Ngored", "Mipit", "Ngalantai", "Ngaleuitkeun"])
    }
    @MainActor func testGatingReplayAndRestart() {
        let store = MemoryStore(); let journey = JourneyViewModel(store: store)
        journey.open(.ngaseuk); journey.record(.ngaseuk, outcome: .performed)
        XCTAssertEqual(journey.completedCount, 0)
        XCTAssertEqual(journey.progress.currentPhase, .narawas)
        for phase in PhaseID.allCases {
            XCTAssertNil(journey.continueFrom(phase))
            journey.record(phase, outcome: .observed)
            XCTAssertEqual(journey.continueFrom(phase), phase.next)
        }
        journey.finishJourney()
        XCTAssertTrue(journey.progress.isValid)
        XCTAssertTrue(journey.progress.journeyCompleted)
        journey.record(.ngaseuk, outcome: .performed)
        XCTAssertTrue(journey.progress.record(for: .ngaseuk).observed)
        XCTAssertTrue(journey.progress.record(for: .ngaseuk).performed)
        XCTAssertEqual(JourneyViewModel(store: store).progress, journey.progress)
        journey.restart()
        XCTAssertEqual(journey.completedCount, 0)
        XCTAssertTrue(journey.progress.introductionSeen)
        XCTAssertFalse(journey.progress.journeyCompleted)
    }

    @MainActor func testOnboardingSceneFollowsCurrentStageAndEndsAtGranary() {
        var progress = JourneyProgress()
        XCTAssertEqual(GrowthStage.onboardingStage(for: progress).id, 0)
        for phase in PhaseID.allCases.prefix(2) {
            progress.complete(phase, outcome: .observed)
        }
        progress.currentPhase = .ngored
        XCTAssertEqual(GrowthStage.onboardingStage(for: progress).id, 2)
        for phase in PhaseID.allCases.dropFirst(2) {
            progress.complete(phase, outcome: .observed)
        }
        XCTAssertEqual(GrowthStage.onboardingStage(for: progress).id, 6)
        XCTAssertEqual(GrowthStage.onboardingStage(for: progress).targetProgress, 1)
    }

    @MainActor func testHomeUsesSavedCompletionAndRejectsLockedRoutes() {
        let store = MemoryStore()
        let journey = JourneyViewModel(store: store)
        let home = HomeViewModel()
        let preview = HomePreviewViewModel()

        home.open(.ngored, journey: journey)
        XCTAssertTrue(home.path.isEmpty)
        XCTAssertEqual(store.writes, 0)
        XCTAssertEqual(journey.completedCount, 0)
        preview.swipe(direction: 1, journey: journey.progress, reduceMotion: false)
        XCTAssertEqual(preview.selectedStage, 0)
        XCTAssertFalse(preview.isTransitioning)

        journey.record(.narawas, outcome: .performed)
        journey.record(.ngaseuk, outcome: .observed)
        preview.swipe(direction: 1, journey: journey.progress, reduceMotion: false)
        XCTAssertTrue(preview.isTransitioning)
        preview.swipe(direction: 1, journey: journey.progress, reduceMotion: false)
        XCTAssertEqual(preview.selectedStage, 1)
        preview.stop()
        preview.swipe(direction: -1, journey: journey.progress, reduceMotion: true)
        XCTAssertEqual(preview.selectedStage, 0)

        home.open(.narawas, journey: journey)
        XCTAssertEqual(home.path, [.activity(.narawas)])
        XCTAssertEqual(journey.progress.currentPhase, .narawas)
        home.open(.ngaseuk, journey: journey)
        XCTAssertEqual(home.path, [.activity(.ngaseuk)])
        XCTAssertEqual(journey.progress.currentPhase, .ngaseuk)
        let restored = JourneyViewModel(store: store).progress
        XCTAssertTrue(restored.record(for: .narawas).performed)
        preview.swipe(direction: 1, journey: restored, reduceMotion: true)
        preview.swipe(direction: 1, journey: restored, reduceMotion: true)
        preview.swipe(direction: 1, journey: restored, reduceMotion: true)
        XCTAssertEqual(preview.selectedStage, PhaseID.ngored.index)
    }

    @MainActor func testHomeSummaryRequiresLeuitCompletion() {
        var progress = JourneyProgress()
        for phase in PhaseID.allCases.dropLast() { progress.complete(phase, outcome: .observed) }
        let preview = HomePreviewViewModel()
        preview.selectStage(PhaseID.ngaleuitkeunPare.index, journey: progress, reduceMotion: true)
        preview.swipe(direction: 1, journey: progress, reduceMotion: true)
        XCTAssertEqual(preview.selectedStage, PhaseID.ngaleuitkeunPare.index)
        XCTAssertFalse(preview.canMove(direction: 1, journey: progress))

        progress.complete(.ngaleuitkeunPare, outcome: .performed)
        preview.swipe(direction: 1, journey: progress, reduceMotion: true)
        XCTAssertTrue(GrowthStage.allStages[preview.selectedStage].isConclusion)
        XCTAssertTrue(preview.canMove(direction: -1, journey: progress))
    }

    @MainActor func testCollectionArrangementPlaysOnlyForFirstTimeCardUnlock() {
        let store = MemoryStore()
        let journey = JourneyViewModel(store: store)
        XCTAssertFalse(journey.hasPendingCollectionArrangement)

        journey.record(.narawas, outcome: .performed)
        XCTAssertTrue(journey.hasPendingCollectionArrangement)
        XCTAssertEqual(journey.pendingCollectionCards, [.chapter(.narawas)])

        journey.record(.ngaseuk, outcome: .observed)
        XCTAssertTrue(journey.hasPendingCollectionArrangement)
        XCTAssertEqual(journey.pendingCollectionCards, [.chapter(.narawas), .chapter(.ngaseuk)])

        // Viewing the collection page marks all earned cards as arranged.
        journey.markCollectionArrangementSeen()
        XCTAssertFalse(journey.hasPendingCollectionArrangement)
        XCTAssertTrue(journey.pendingCollectionCards.isEmpty)

        // Replaying an already completed stage does not re-trigger the arrangement animation.
        journey.record(.ngaseuk, outcome: .performed)
        XCTAssertFalse(journey.hasPendingCollectionArrangement)

        // Persists across relaunches.
        let relaunched = JourneyViewModel(store: store)
        XCTAssertFalse(relaunched.hasPendingCollectionArrangement)

        // Restarting clears arranged state cleanly.
        relaunched.restart()
        XCTAssertFalse(relaunched.hasPendingCollectionArrangement)
        relaunched.record(.narawas, outcome: .observed)
        XCTAssertTrue(relaunched.hasPendingCollectionArrangement)
    }

    @MainActor func testCycleCompletionResetsMenuToStageOneWhilePreservingEarnedCards() {
        let store = MemoryStore()
        let journey = JourneyViewModel(store: store)
        journey.finishIntroduction()

        for phase in PhaseID.allCases {
            journey.record(phase, outcome: .performed)
        }
        XCTAssertTrue(journey.progress.allComplete)

        journey.completeCycleAndReturnToMenu()

        // Menu progress resets so only stage 1 (narawas) is unlocked and active.
        XCTAssertTrue(journey.progress.isValid)
        XCTAssertTrue(journey.progress.introductionSeen)
        XCTAssertFalse(journey.progress.journeyCompleted)
        XCTAssertEqual(journey.progress.currentPhase, .narawas)
        XCTAssertEqual(journey.completedCount, 0)
        XCTAssertTrue(journey.progress.isUnlocked(.narawas))
        for phase in PhaseID.allCases.dropFirst() {
            XCTAssertFalse(journey.progress.isUnlocked(phase))
        }

        // Explosion flag is armed once for MenuView.
        XCTAssertTrue(journey.pendingMenuCycleReset)
        XCTAssertTrue(journey.consumePendingMenuCycleReset())
        XCTAssertFalse(journey.consumePendingMenuCycleReset())

        let relaunched = JourneyViewModel(store: store)
        let secondSet: [ChapterCard] = [.sengon, .pungpuhunan, .kolecer, .garu, .lantaian, .kematian]
        XCTAssertEqual(ChapterCard.all.filter { $0.isEarned(in: relaunched.progress) }, PhaseID.allCases.map { .chapter($0) })
        for (phase, reward) in zip(PhaseID.allCases, secondSet) {
            relaunched.record(phase, outcome: .observed)
            XCTAssertEqual(relaunched.newlyEarnedCards, [reward])
            relaunched.record(phase, outcome: .performed)
            XCTAssertTrue(relaunched.newlyEarnedCards.isEmpty)
        }
        XCTAssertTrue(ChapterCard.all.allSatisfy { $0.isEarned(in: relaunched.progress) })
    }
}
