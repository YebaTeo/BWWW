import XCTest
@testable import BeBaduy

@MainActor final class FakeMotion: MotionProviding {
    var available = true
    var handler: (@MainActor (MotionSample?) -> Void)?
    var stops = 0
    func start(handler: @escaping @MainActor (MotionSample?) -> Void) { self.handler = handler }
    func stop() { stops += 1; handler = nil }
}
final class NgaseukTests: XCTestCase {
    @MainActor private func digHole(_ vm: NgaseukViewModel, _ index: Int) {
        for _ in 0..<3 { vm.dig(index) }
    }

    func testDetectorNoiseSustainedCooldownAndRearm() {
        var detector = NgaseukMotionDetector()
        XCTAssertFalse(detector.consume(.init(time: 0, verticalAcceleration: -0.90)))
        XCTAssertFalse(detector.consume(.init(time: 0.1, verticalAcceleration: 0.02)))
        // Light or moderate movements (-0.1, -0.35) must not trigger a dig
        XCTAssertFalse(detector.consume(.init(time: 0.2, verticalAcceleration: -0.1)))
        XCTAssertFalse(detector.consume(.init(time: 0.25, verticalAcceleration: -0.35)))
        // Moving the phone UP (+0.45 for 50ms) followed by immediate braking at the top (-0.95) must NOT trigger a dig
        XCTAssertFalse(detector.consume(.init(time: 0.30, verticalAcceleration: 0.45)))
        XCTAssertFalse(detector.consume(.init(time: 0.35, verticalAcceleration: 0.40)))
        XCTAssertFalse(detector.consume(.init(time: 0.42, verticalAcceleration: -0.95)))
        // Settle back to neutral after upward motion lockout to arm
        XCTAssertFalse(detector.consume(.init(time: 0.80, verticalAcceleration: 0.0)))
        // Deliberate downward thrust (< -0.45) triggers the first strike
        XCTAssertTrue(detector.consume(.init(time: 0.90, verticalAcceleration: -0.90)))
        // Zero-crossing during the immediate rebound (< 0.22s after strike) must not re-arm
        XCTAssertFalse(detector.consume(.init(time: 1.05, verticalAcceleration: 0.0)))
        XCTAssertFalse(detector.consume(.init(time: 2.1, verticalAcceleration: -0.90)))
        // Steady neutral hold after rearmDelay re-arms, and after cooldown triggers
        XCTAssertFalse(detector.consume(.init(time: 2.2, verticalAcceleration: 0)))
        XCTAssertTrue(detector.consume(.init(time: 2.3, verticalAcceleration: -0.90)))
        // Cannot trigger again before cooldown (0.85s) elapses
        XCTAssertFalse(detector.consume(.init(time: 2.8, verticalAcceleration: 0)))
        XCTAssertFalse(detector.consume(.init(time: 3.0, verticalAcceleration: -0.90)))
        XCTAssertTrue(detector.consume(.init(time: 3.3, verticalAcceleration: -0.90)))
        XCTAssertFalse(detector.consume(.init(time: .nan, verticalAcceleration: -1)))
        detector.reset()
        XCTAssertFalse(detector.consume(.init(time: 4.5, verticalAcceleration: -0.95)))
    }
    @MainActor func testDiggingAndSeedingAreSeparateAndMotionStops() {
        let motion = FakeMotion(); let vm = NgaseukViewModel(motion: motion)
        vm.start(); vm.dig(0); XCTAssertTrue(vm.holes.isEmpty)
        vm.proceed(); digHole(vm, 0); vm.dig(0); vm.dig(-1)
        XCTAssertEqual(vm.holes, [0]); XCTAssertFalse(vm.seed(0))
        vm.startMotion()
        for stroke in 0..<3 {
            let t = Double(stroke) * 1.2
            motion.handler?(.init(time: t, verticalAcceleration: 0))
            motion.handler?(.init(time: t + 0.2, verticalAcceleration: -0.90))
        }
        digHole(vm, 2)
        XCTAssertEqual(vm.step, .holesReady)
        XCTAssertFalse(vm.motionActive); XCTAssertNil(vm.session.outcome)
        vm.proceed()
        XCTAssertTrue(vm.motionActive)
        XCTAssertTrue(vm.seed(0)); XCTAssertFalse(vm.seed(0))
        vm.seed(1); vm.seed(2)
        XCTAssertFalse(vm.motionActive)
        XCTAssertEqual(vm.session.outcome, .performed)
        vm.start(); XCTAssertTrue(vm.seeds.isEmpty)
    }

    @MainActor func testFieldShakePoursSeedsIntoEachHoleWithoutSelectingHole() async throws {
        let motion = FakeMotion(); let vm = NgaseukViewModel(motion: motion)
        vm.start(); vm.proceed()
        for index in 0..<3 { digHole(vm, index) }
        vm.proceed()
        XCTAssertEqual(vm.step, .seeding)
        XCTAssertNil(vm.peekTarget)
        XCTAssertTrue(vm.motionActive)

        for expectedHole in 0..<3 {
            XCTAssertEqual(vm.nextSeedTarget, expectedHole)
            let t = Double(expectedHole * 3 + 1)
            motion.handler?(.init(time: t, verticalAcceleration: 0))
            motion.handler?(.init(time: t + 0.1, verticalAcceleration: 0.22))
            motion.handler?(.init(time: t + 0.2, verticalAcceleration: -0.22))
            XCTAssertEqual(vm.peekTarget, expectedHole)
            XCTAssertTrue(vm.isBasketEntering)
            try await Task.sleep(for: .milliseconds(2100))
            XCTAssertTrue(vm.seeds.contains(expectedHole))
            XCTAssertNil(vm.peekTarget)
        }
        XCTAssertEqual(vm.seeds, [0, 1, 2])
        XCTAssertEqual(vm.session.outcome, .performed)
        XCTAssertFalse(vm.motionActive)
    }
    @MainActor func testUnavailableSensorAndDemoCancellation() async {
        let motion = FakeMotion(); motion.available = false
        let vm = NgaseukViewModel(motion: motion); vm.start(); vm.proceed(); vm.startMotion()
        XCTAssertFalse(vm.motionActive); XCTAssertFalse(vm.session.feedback.isEmpty)
        vm.demonstrate(); vm.suspend()
        await Task.yield()
        XCTAssertNil(vm.session.outcome); XCTAssertFalse(vm.isDemonstrating)
    }
    func testPourDetectorNeedsSteadyHoldAndOppositeMovement() {
        var detector = SeedPourMotionDetector()
        XCTAssertFalse(detector.consume(.init(time: 0, verticalAcceleration: 0.5)))
        XCTAssertFalse(detector.consume(.init(time: 1, verticalAcceleration: 0)))
        XCTAssertFalse(detector.consume(.init(time: 1.1, verticalAcceleration: 0.1)))
        XCTAssertFalse(detector.consume(.init(time: 1.2, verticalAcceleration: 0.25)))
        XCTAssertFalse(detector.consume(.init(time: 1.3, verticalAcceleration: 0.3)))
        XCTAssertTrue(detector.consume(.init(time: 1.4, verticalAcceleration: -0.25)))
        XCTAssertFalse(detector.consume(.init(time: 1.5, verticalAcceleration: 0.3)))
        XCTAssertFalse(detector.consume(.init(time: .nan, verticalAcceleration: -0.3)))
    }

    @MainActor func testPeekShakeFillsOnlySelectedHoleAndStopsMotion() async throws {
        let motion = FakeMotion(); let vm = NgaseukViewModel(motion: motion)
        vm.start(); vm.peek(0); XCTAssertNil(vm.peekTarget)
        vm.proceed(); for index in 0..<3 { digHole(vm, index) }; vm.proceed()
        vm.peek(1); XCTAssertTrue(vm.motionActive)
        let oldHandler = motion.handler
        motion.handler?(.init(time: 1, verticalAcceleration: 0))
        motion.handler?(.init(time: 1.1, verticalAcceleration: 0.25))
        motion.handler?(.init(time: 1.2, verticalAcceleration: -0.25))
        XCTAssertTrue(vm.isBasketEntering); XCTAssertFalse(vm.motionActive)
        XCTAssertTrue(vm.seeds.isEmpty)
        try await Task.sleep(for: .milliseconds(1900))
        XCTAssertEqual(vm.seeds, [1]); XCTAssertNil(vm.session.outcome)
        vm.closePeek(); vm.peek(2)
        oldHandler?(.init(time: 2, verticalAcceleration: 0))
        oldHandler?(.init(time: 2.1, verticalAcceleration: 0.3))
        oldHandler?(.init(time: 2.2, verticalAcceleration: -0.3))
        XCTAssertFalse(vm.isBasketEntering)
        vm.pourSeeds(); vm.closePeek(resumeFieldMotion: false)
        try await Task.sleep(for: .milliseconds(1900))
        XCTAssertEqual(vm.seeds, [1]); XCTAssertNil(vm.peekTarget)
        XCTAssertFalse(vm.motionActive)
    }

    @MainActor func testPeekWithoutSensorSupportsTouchAndCancelsOnSuspend() {
        let motion = FakeMotion(); motion.available = false
        let vm = NgaseukViewModel(motion: motion)
        vm.start(); vm.proceed(); for index in 0..<3 { digHole(vm, index) }; vm.proceed()
        vm.peek(0); XCTAssertFalse(vm.motionActive)
        vm.pourSeeds(); XCTAssertTrue(vm.isBasketEntering)
        vm.suspend(); XCTAssertFalse(vm.isBasketEntering); XCTAssertFalse(vm.isPouring); XCTAssertNil(vm.peekTarget)
        XCTAssertTrue(vm.seeds.isEmpty)
    }

}
