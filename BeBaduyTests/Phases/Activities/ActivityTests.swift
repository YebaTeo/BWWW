import XCTest
@testable import BeBaduy
@MainActor final class ActivityTests: XCTestCase {
    func testWeedingRequiresEightUniqueWeedsAndRain() {
        let vm = NgoredViewModel(); vm.start()
        vm.remove(8); vm.remove(-1); XCTAssertTrue(vm.removed.isEmpty)
        for i in 0..<8 {
            vm.remove(i); vm.remove(i)
            XCTAssertFalse(vm.removed.contains(i))
            vm.remove(i); vm.remove(i)
            XCTAssertEqual(vm.strokes[i], 3)
        }
        XCTAssertEqual(vm.removed.count, 8); XCTAssertNil(vm.session.outcome)
        vm.finishRain(); XCTAssertNil(vm.session.outcome)
        vm.observeRain(); vm.finishRain(); XCTAssertEqual(vm.session.outcome, .performed)
    }
    func testKoredRequiresNewDownstrokeAndContact() {
        var tracker = KoredStrokeTracker()
        let targets = [CGPoint(x: 100, y: 150)]
        XCTAssertNil(tracker.move(blade: CGPoint(x: 100, y: 110), targets: targets, removed: []))
        XCTAssertNil(tracker.move(blade: CGPoint(x: 100, y: 120), targets: targets, removed: []))
        XCTAssertEqual(tracker.move(blade: CGPoint(x: 100, y: 140), targets: targets, removed: []), 0)
        XCTAssertNil(tracker.move(blade: CGPoint(x: 100, y: 165), targets: targets, removed: []))
        XCTAssertNil(tracker.move(blade: CGPoint(x: 100, y: 130), targets: targets, removed: []))
        XCTAssertEqual(tracker.move(blade: CGPoint(x: 100, y: 155), targets: targets, removed: []), 0)
        tracker.reset()
        XCTAssertNil(tracker.move(blade: CGPoint(x: 200, y: 100), targets: targets, removed: []))
        XCTAssertNil(tracker.move(blade: CGPoint(x: 200, y: 150), targets: targets, removed: []))
        tracker.reset()
        XCTAssertNil(tracker.move(blade: CGPoint(x: 100, y: 110), targets: targets, removed: [0]))
        XCTAssertNil(tracker.move(blade: CGPoint(x: 100, y: 150), targets: targets, removed: [0]))
    }
    func testHarvestBalanceAndDryingCannotBeSkipped() {
        let vm = DibuatViewModel(motion: FakeMotion()); vm.start()
        vm.finishDrying(); XCTAssertNil(vm.session.outcome)
        for i in 0..<4 { vm.harvest(i); vm.harvest(i) }
        XCTAssertEqual(vm.step, .balanceInstructions)
        vm.beginBalance(); vm.tick(100); XCTAssertEqual(vm.steadyTime, 0)
        vm.setBalance(0)
        for _ in 0..<31 { vm.tick(0.1) }
        XCTAssertEqual(vm.step, .drying); XCTAssertNil(vm.session.outcome)
        vm.finishDrying(); XCTAssertEqual(vm.session.outcome, .performed)
        vm.suspend()
    }
    func testLeuitUniqueBundlesAndInteriorGate() {
        let vm = NgaleuitkeunPareViewModel(); vm.start()
        XCTAssertFalse(vm.drop(-1, at: 0)); XCTAssertTrue(vm.drop(2, at: 0))
        XCTAssertFalse(vm.drop(2, at: 1)); XCTAssertFalse(vm.drop(1, at: 0))
        XCTAssertTrue(vm.drop(0, at: 1)); XCTAssertTrue(vm.drop(1, at: 2))
        XCTAssertNil(vm.session.outcome)
        vm.finish(); XCTAssertNil(vm.session.outcome)
        vm.inspectInterior(); vm.finish(); XCTAssertEqual(vm.session.outcome, .performed)
    }
}
