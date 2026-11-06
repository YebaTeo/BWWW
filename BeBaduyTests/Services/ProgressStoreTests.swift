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
        progress.complete(.nukuh, outcome: .performed); progress.currentPhase = .ngaseuk
        try store.save(progress)
        XCTAssertEqual(ProgressStore(defaults: defaults).load(), progress)
        progress.version = 200
        try store.save(progress)
        let incompatible = ProgressStore(defaults: defaults)
        XCTAssertEqual(incompatible.load(), JourneyProgress())
        XCTAssertNotNil(incompatible.recoveryMessage)
        XCTAssertNotNil(defaults.data(forKey: "BeBaduy.journey.v2.recovery"))
        defaults.set(Data([0, 1, 2]), forKey: "BeBaduy.journey.v2")
        let corrupt = ProgressStore(defaults: defaults)
        XCTAssertEqual(corrupt.load(), JourneyProgress()); XCTAssertNotNil(corrupt.recoveryMessage)
    }
    @MainActor func testLegacyMigrationKeepsOriginalAndRequiresDrying() throws {
        let name = "migration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let old = Data(#"{"version":1,"currentPhase":"ngunjal","phases":{"ngahuru":{"observed":false,"performed":true,"explanationAvailable":true},"ngaseuk":{"observed":false,"performed":true,"explanationAvailable":true},"ngored":{"observed":true,"performed":false,"explanationAvailable":true},"dibuat":{"observed":true,"performed":false,"explanationAvailable":true}}}"#.utf8)
        defaults.set(old, forKey: "BeBaduy.journey.v1")
        let migrated = ProgressStore(defaults: defaults).load()
        XCTAssertTrue(migrated.isValid)
        XCTAssertEqual(migrated.currentPhase, .dibuat)
        XCTAssertEqual(migrated.record(for: .nukuh).outcome, .observed)
        XCTAssertFalse(migrated.record(for: .dibuat).explanationAvailable)
        XCTAssertEqual(defaults.data(forKey: "BeBaduy.journey.v1"), old)
        XCTAssertEqual(ProgressStore(defaults: defaults).load(), migrated)
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
