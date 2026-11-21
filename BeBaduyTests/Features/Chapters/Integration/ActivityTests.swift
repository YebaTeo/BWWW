import XCTest
@testable import BeBaduy
@MainActor final class ActivityTests: XCTestCase {
    func testNgoredCyclesPassSecondNightAndCompleteOnceAfterResume() {
        let scene = NgahumaScene()
        var completions = 0
        scene.animateNgoredDayNight(cycles: 3, duration: 12, growthFrom: 0.18, growthTo: 0.5) {
            completions += 1
        }
        scene.advanceNgoredDayNight(by: 7) // Middle of the second night.
        XCTAssertEqual(completions, 0)
        scene.setSuspended(true)
        scene.advanceNgoredDayNight(by: 20)
        XCTAssertEqual(completions, 0)
        scene.setSuspended(false)
        scene.advanceNgoredDayNight(by: 4)
        XCTAssertEqual(completions, 0)
        scene.advanceNgoredDayNight(by: 1)
        XCTAssertEqual(completions, 1)
        scene.advanceNgoredDayNight(by: 12)
        XCTAssertEqual(completions, 1)
    }

    func testNgoredDaytimeCancelsPreviousCycleCompletion() {
        let scene = NgahumaScene()
        var completions = 0
        scene.animateNgoredDayNight(cycles: 3, duration: 12, growthFrom: 0.18, growthTo: 0.5) {
            completions += 1
        }
        scene.advanceNgoredDayNight(by: 7)
        scene.presentNgoredDaytime()
        scene.advanceNgoredDayNight(by: 12)
        XCTAssertEqual(completions, 0)
    }

    func testOneSwipeUprootsEachWeedInBothRounds() async throws {
        let vm = NgoredViewModel()
        vm.start()
        vm.setVisible(true)
        defer { vm.setVisible(false) }
        vm.beginInitialRainAfterCard()
        let deadline = ContinuousClock.now + .seconds(8)
        while vm.step == .initialRain, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        for round in [0..<4, 4..<7] {
            vm.remove(round.upperBound)
            XCTAssertFalse(vm.removed.contains(round.upperBound))
            for index in round {
                vm.remove(index)
                XCTAssertTrue(vm.removed.contains(index))
                let count = vm.removed.count
                vm.remove(index)
                XCTAssertEqual(vm.removed.count, count)
            }
            XCTAssertEqual(vm.step, round.lowerBound == 0 ? .cleared : .secondCleared)
            vm.observeRain()
            vm.finishRain()
            vm.scene.advanceNgoredDayNight(by: 12)
        }
        XCTAssertEqual(vm.session.outcome, .performed)
    }

    func testCurvedSwipeHitsBeforeLiftAndCanOnlyUprootOneWeed() {
        var stroke = KoredStrokeTracker()
        let weed = CGRect(x: 80, y: 80, width: 40, height: 80)
        var hits = 0
        func hit(_ start: CGPoint, _ end: CGPoint) -> Bool {
            guard KoredStrokeTracker.hitDistance(from: start, to: end, in: weed) != nil else { return false }
            hits += 1
            return true
        }
        stroke.begin(at: CGPoint(x: 30, y: 20))
        stroke.move(to: CGPoint(x: 30, y: 120), hitTest: hit)
        XCTAssertEqual(hits, 0)
        stroke.move(to: CGPoint(x: 170, y: 120), hitTest: hit)
        XCTAssertEqual(hits, 1)
        stroke.move(to: CGPoint(x: 30, y: 120), hitTest: hit)
        XCTAssertEqual(hits, 1)
        stroke.begin(at: CGPoint(x: 170, y: 120))
        stroke.move(to: CGPoint(x: 30, y: 120), hitTest: hit)
        XCTAssertEqual(hits, 2)
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
        for _ in 0..<20 { vm.centerBalance(); vm.tick(0.1) }
        vm.setBalance(0.8)
        vm.tick(0.1)
        XCTAssertEqual(vm.steadyTime, 1.95, accuracy: 0.001)
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
        for _ in 0..<69 { vm.centerBalance(); vm.tick(0.1) }
        XCTAssertEqual(vm.step, .balancing)
        vm.centerBalance()
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
            for _ in 0..<10 { vm.centerBalance(); vm.tick(0.1) }
            XCTAssertEqual(vm.steadyTime, 1, accuracy: 0.001)
            motion.handler?(.init(time: 1, verticalAcceleration: 0, gravity: SIMD3(0, 0.7, -0.7)))
            XCTAssertGreaterThan(vm.balance * Double(direction), 0.18)
            vm.tick(0.1)
            XCTAssertEqual(vm.steadyTime, 0.95, accuracy: 0.001)
            vm.centerBalance(); vm.tick(0.1)
            XCTAssertEqual(vm.steadyTime, 1.05, accuracy: 0.001)
            vm.suspend()
            XCTAssertNil(motion.handler)
            vm.resume()
            motion.handler?(.init(time: 2, verticalAcceleration: 0, gravity: SIMD3(0, -0.2, -0.9)))
            XCTAssertEqual(vm.balance, 0, accuracy: 0.001)
            XCTAssertEqual(vm.steadyTime, 0)
            vm.suspend()
        }
    }

    func testNgalantaiNeedsActiveCorrectionAsLoadShifts() {
        let vm = NgalantaiViewModel(motion: FakeMotion())
        vm.start()
        vm.orientationChanged(1)
        vm.beginBalance()
        vm.setBalance(0)
        for _ in 0..<50 { vm.tick(0.1) }
        XCTAssertEqual(vm.step, .balancing)
        XCTAssertLessThan(vm.steadyTime, NgalantaiViewModel.requiredSteadyTime)
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
