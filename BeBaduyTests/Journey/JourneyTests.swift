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
    func testCatalogStableOrderAndReferences() {
        XCTAssertEqual(PhaseCatalog.all.map(\.id), PhaseID.allCases)
        XCTAssertEqual(Set(PhaseID.allCases.map(\.rawValue)).count, 11)
        XCTAssertEqual(PhaseID.allCases.map(\.rawValue), ["narawas", "nyacar", "ngaganggang", "ngahuru", "ngaseuk", "ngored", "ngubaran_pare", "dibuat", "drying_rice", "ngunjal", "ngaleuitkeun_pare"])
        for content in PhaseCatalog.all {
            XCTAssertFalse(content.introduction.isEmpty)
            XCTAssertFalse(content.explanation.isEmpty)
            XCTAssertFalse(content.sourceIDs.isEmpty)
            XCTAssertTrue(content.sourceIDs.allSatisfy { id in SourceCatalog.all.contains { $0.id == id } })
            XCTAssertNotEqual(content.before.assetName, content.after.assetName)
        }
    }
    @MainActor func testUnlockContinueResumeReplayAndFinalCompletion() {
        let store = MemoryStore(); let journey = JourneyViewModel(store: store)
        journey.open(.ngaseuk); XCTAssertEqual(journey.progress.currentPhase, .narawas)
        journey.record(.ngaseuk, outcome: .performed); XCTAssertEqual(journey.completedCount, 0)
        journey.finishJourney(); XCTAssertFalse(journey.progress.journeyCompleted)
        for phase in PhaseID.allCases {
            XCTAssertTrue(journey.progress.isUnlocked(phase))
            XCTAssertNil(journey.continueFrom(phase))
            journey.record(phase, outcome: .observed)
            let first = journey.progress
            journey.record(phase, outcome: .observed); XCTAssertEqual(journey.progress, first)
            XCTAssertEqual(journey.progress.currentPhase, phase)
            XCTAssertEqual(journey.continueFrom(phase), phase.next)
        }
        journey.finishJourney(); XCTAssertTrue(journey.progress.journeyCompleted)
        let restored = JourneyViewModel(store: store)
        XCTAssertEqual(restored.progress, journey.progress)
        restored.open(.ngaseuk)
        let beforeReplay = restored.progress
        let vm = NgaseukViewModel(motion: FakeMotion())
        vm.session.restore(restored.progress.record(for: .ngaseuk).outcome)
        XCTAssertTrue(vm.session.showsDescription)
        vm.start(); vm.plant(0)
        XCTAssertEqual(restored.progress, beforeReplay)
        vm.plant(1); vm.plant(2)
        restored.record(.ngaseuk, outcome: vm.session.outcome!)
        XCTAssertTrue(restored.progress.record(for: .ngaseuk).observed)
        XCTAssertTrue(restored.progress.record(for: .ngaseuk).performed)
        XCTAssertEqual(restored.progress.record(for: .narawas), beforeReplay.record(for: .narawas))
        XCTAssertTrue(restored.progress.journeyCompleted)
        XCTAssertTrue(restored.progress.isValid)
    }
    @MainActor func testUnfinishedResumeRestartsShortActivity() {
        let store = MemoryStore(); let journey = JourneyViewModel(store: store)
        for phase in PhaseID.allCases.prefix(4) { journey.record(phase, outcome: .performed) }
        journey.open(.ngaseuk)
        let partial = NgaseukViewModel(motion: FakeMotion()); partial.start(); partial.plant(0)
        let resumed = JourneyViewModel(store: store)
        XCTAssertEqual(resumed.progress.currentPhase, .ngaseuk)
        let fresh = NgaseukViewModel(motion: FakeMotion())
        fresh.session.restore(resumed.progress.record(for: .ngaseuk).outcome)
        XCTAssertEqual(fresh.session.stage, .introduction); XCTAssertTrue(fresh.holes.isEmpty)
    }
}
