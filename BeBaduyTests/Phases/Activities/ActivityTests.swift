import XCTest
@testable import BeBaduy
@MainActor final class ActivityTests: XCTestCase {
    func testWeedingRequiresEightUniqueWeedsAndRain() {
        let vm = NgoredViewModel(); vm.start(skipInitialRain: true)
        vm.remove(8); vm.remove(-1); XCTAssertTrue(vm.removed.isEmpty)
        for i in 0..<4 {
            vm.remove(i); vm.remove(i)
            XCTAssertFalse(vm.removed.contains(i))
            vm.remove(i); vm.remove(i)
            XCTAssertEqual(vm.strokes[i], 3)
        }
        XCTAssertEqual(vm.removed.count, 4)
        XCTAssertEqual(vm.step, .cleared)
        vm.advanceToSecondWeedingForTesting()
        XCTAssertEqual(vm.step, .secondWeeding)
        for i in 4..<7 {
            vm.remove(i); vm.remove(i)
            XCTAssertFalse(vm.removed.contains(i))
            vm.remove(i); vm.remove(i)
            XCTAssertEqual(vm.strokes[i], 3)
        }
        XCTAssertEqual(vm.step, .secondCleared)
        XCTAssertNil(vm.session.outcome)
        vm.observeRain()
        vm.finishRain()
        XCTAssertEqual(vm.session.outcome, .performed)
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
        let harvest = MipitViewModel(motion: FakeMotion())
        harvest.start()
        harvest.finishHarvest()
        XCTAssertNil(harvest.session.outcome)
        for index in 0..<3 { harvest.harvest(index); harvest.harvest(index) }
        XCTAssertEqual(harvest.harvested.count, 3)
        harvest.finishHarvest()
        XCTAssertEqual(harvest.session.outcome, .performed)

        let vm = NgalantaiViewModel(motion: FakeMotion())
        vm.start()
        vm.finishDrying()
        XCTAssertNil(vm.session.outcome)
        XCTAssertEqual(vm.step, .awaitingLandscape)
        vm.orientationChanged(-1)
        XCTAssertEqual(vm.step, .balanceInstructions)
        vm.beginBalance(); vm.tick(100); XCTAssertEqual(vm.steadyTime, 0)
        vm.setBalance(0)
        for _ in 0..<20 { vm.tick(0.1) }
        vm.setBalance(0.2)
        XCTAssertEqual(vm.steadyTime, 0)
        vm.setBalance(0)
        vm.tick(0.1)
        vm.showHelp()
        XCTAssertEqual(vm.steadyTime, 0)
        vm.tick(0.1)
        XCTAssertEqual(vm.steadyTime, 0)
        vm.beginBalance()
        vm.orientationChanged(1)
        XCTAssertEqual(vm.step, .balanceInstructions)
        vm.beginBalance()
        vm.suspend()
        vm.tick(0.1)
        XCTAssertEqual(vm.steadyTime, 0)
        vm.resume()
        for _ in 0..<29 { vm.tick(0.1) }
        XCTAssertEqual(vm.step, .balancing)
        vm.tick(0.1)
        XCTAssertEqual(vm.step, .awaitingPortrait)
        vm.finishDrying(); XCTAssertNil(vm.session.outcome)
        vm.orientationChanged(0)
        XCTAssertEqual(vm.step, .drying); XCTAssertNil(vm.session.outcome)
        vm.finishDrying(); XCTAssertEqual(vm.session.outcome, .performed)
        let event = vm.session.event
        vm.finishDrying(); XCTAssertEqual(vm.session.event, event)
        vm.start()
        XCTAssertEqual(vm.step, .awaitingLandscape)
        vm.suspend()
    }
    func testBalanceCalibratesAndRecentersInBothLandscapeDirections() {
        for direction in [-1, 1] {
            let motion = FakeMotion()
            let vm = NgalantaiViewModel(motion: motion)
            vm.start()
            vm.orientationChanged(direction)
            vm.beginBalance()
            motion.handler?(.init(time: 0, verticalAcceleration: 0, gravity: SIMD3(0, 0.3, -0.9)))
            XCTAssertEqual(vm.balance, 0, accuracy: 0.001)
            for _ in 0..<10 { vm.tick(0.1) }
            XCTAssertEqual(vm.steadyTime, 1, accuracy: 0.001)
            motion.handler?(.init(time: 1, verticalAcceleration: 0, gravity: SIMD3(0, 0.7, -0.7)))
            XCTAssertGreaterThan(vm.balance * Double(direction), 0.18)
            XCTAssertEqual(vm.steadyTime, 0)
            vm.suspend()
            XCTAssertNil(motion.handler)
            vm.resume()
            motion.handler?(.init(time: 2, verticalAcceleration: 0, gravity: SIMD3(0, -0.2, -0.9)))
            XCTAssertEqual(vm.balance, 0, accuracy: 0.001)
            XCTAssertEqual(vm.steadyTime, 0)
            vm.suspend()
        }
    }

    func testLeuitCompletesOnlyAfterLadderPlacement() {
        let vm = NgaleuitkeunPareViewModel()
        vm.start()
        vm.finish()
        XCTAssertNil(vm.session.outcome)
        vm.placeLadder()
        XCTAssertTrue(vm.isLadderPlaced)
        XCTAssertNil(vm.session.outcome)
        vm.finish()
        XCTAssertEqual(vm.session.outcome, .performed)

        vm.start()
        XCTAssertFalse(vm.isLadderPlaced)
        vm.demonstrate()
        vm.finish()
        XCTAssertEqual(vm.session.outcome, .observed)
    }
}
