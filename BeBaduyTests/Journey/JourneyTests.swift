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
        XCTAssertEqual(PhaseCatalog.all.map(\.title), ["Nukuh", "Ngaseuk", "Ngored", "Mipit", "Ngalantai", "Leuit"])
    }
    @MainActor func testGatingReplayAndRestart() {
        let store = MemoryStore(); let journey = JourneyViewModel(store: store)
        journey.open(.ngaseuk); journey.record(.ngaseuk, outcome: .performed)
        XCTAssertEqual(journey.completedCount, 0)
        XCTAssertEqual(journey.progress.currentPhase, .nukuh)
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
}
