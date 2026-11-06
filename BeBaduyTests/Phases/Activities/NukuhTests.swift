import XCTest
@testable import BeBaduy
@MainActor final class NukuhTests: XCTestCase {
    func testSceneCannotCompleteWithoutPreparation() {
        let vm = NukuhViewModel(); vm.start()
        vm.burn(); vm.scene.finishBurn(); vm.collect(-1)
        XCTAssertNil(vm.session.outcome)
        XCTAssertTrue(vm.collected.isEmpty)
        vm.suspend(); XCTAssertTrue(vm.scene.suspended)
    }
    func testReplayKeepsPreviouslySavedCredit() {
        var progress = JourneyProgress(); progress.complete(.nukuh, outcome: .observed)
        let vm = NukuhViewModel(); vm.restore(progress.record(for: .nukuh).outcome)
        vm.start(); XCTAssertNil(vm.session.outcome)
        XCTAssertTrue(progress.record(for: .nukuh).explanationAvailable)
    }
}
