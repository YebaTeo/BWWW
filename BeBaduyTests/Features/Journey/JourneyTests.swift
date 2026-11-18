import XCTest
@testable import BeBaduy

@MainActor final class MemoryStore: ProgressStoring {
    var value = JourneyProgress()
    var recoveryMessage: String?
    var writes = 0
    func load() -> JourneyProgress { value }
    func save(_ progress: JourneyProgress) throws { value = progress; writes += 1 }
}
final class JourneyTests: XCTestCase {
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
        XCTAssertEqual(home.path, [.preview(.narawas)])
        XCTAssertEqual(journey.progress.currentPhase, .narawas)
        home.open(.ngaseuk, journey: journey)
        XCTAssertEqual(home.path, [.preview(.ngaseuk)])
        XCTAssertEqual(journey.progress.currentPhase, .narawas)
        home.start(.ngaseuk, journey: journey)
        XCTAssertEqual(home.path, [.preview(.ngaseuk), .activity(.ngaseuk)])
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
}
