import XCTest
@testable import BeBaduy
final class ProgressStoreTests: XCTestCase {
    @MainActor func testRoundTripAndCorruptVersionRecovery() throws {
        let name = "BeBaduy.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ProgressStore(defaults: defaults)
        XCTAssertEqual(store.load(), JourneyProgress())
        var progress = JourneyProgress()
        progress.complete(.narawas, outcome: .performed); progress.currentPhase = .nyacar
        try store.save(progress)
        XCTAssertEqual(ProgressStore(defaults: defaults).load(), progress)
        progress.version = 200
        try store.save(progress)
        let incompatible = ProgressStore(defaults: defaults)
        XCTAssertEqual(incompatible.load(), JourneyProgress())
        XCTAssertNotNil(incompatible.recoveryMessage)
        XCTAssertNotNil(defaults.data(forKey: "BeBaduy.journey.v1.recovery"))
        defaults.set(Data([0, 1, 2]), forKey: "BeBaduy.journey.v1")
        let corrupt = ProgressStore(defaults: defaults)
        XCTAssertEqual(corrupt.load(), JourneyProgress()); XCTAssertNotNil(corrupt.recoveryMessage)
    }
    func testRejectInconsistentRecord() {
        var progress = JourneyProgress(); progress.phases["unknown"] = PhaseProgress()
        XCTAssertFalse(progress.isValid)
        progress = JourneyProgress(); progress.phases["ngaseuk"] = .init(observed: true, explanationAvailable: true)
        XCTAssertFalse(progress.isValid)
        progress = JourneyProgress(); progress.journeyCompleted = true
        XCTAssertFalse(progress.isValid)
    }
}
