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
    func testDetectorNoiseSustainedCooldownAndRearm() {
        var detector = NgaseukMotionDetector()
        XCTAssertFalse(detector.consume(.init(time: 0, verticalAcceleration: -0.5)))
        XCTAssertFalse(detector.consume(.init(time: 0.1, verticalAcceleration: 0.02)))
        XCTAssertFalse(detector.consume(.init(time: 0.2, verticalAcceleration: -0.1)))
        XCTAssertTrue(detector.consume(.init(time: 0.3, verticalAcceleration: -0.4)))
        XCTAssertFalse(detector.consume(.init(time: 1.2, verticalAcceleration: -0.5)))
        XCTAssertFalse(detector.consume(.init(time: 1.3, verticalAcceleration: 0)))
        XCTAssertTrue(detector.consume(.init(time: 1.4, verticalAcceleration: -0.4)))
        XCTAssertFalse(detector.consume(.init(time: 1.5, verticalAcceleration: 0)))
        XCTAssertFalse(detector.consume(.init(time: 1.6, verticalAcceleration: -0.4)))
        XCTAssertTrue(detector.consume(.init(time: 2.1, verticalAcceleration: -0.4)))
        XCTAssertFalse(detector.consume(.init(time: .nan, verticalAcceleration: -1)))
        detector.reset()
        XCTAssertFalse(detector.consume(.init(time: 3, verticalAcceleration: -0.6)))
    }
    @MainActor func testTouchAndMotionShareDistinctTargetsAndStop() {
        let motion = FakeMotion(); let vm = NgaseukViewModel(motion: motion)
        vm.plant(0); XCTAssertTrue(vm.holes.isEmpty)
        vm.start(); vm.plant(0); vm.plant(0); vm.plant(-1); vm.plant(4)
        XCTAssertEqual(vm.holes, [0])
        vm.startMotion(); XCTAssertTrue(vm.motionActive)
        motion.handler?(.init(time: 0, verticalAcceleration: 0))
        motion.handler?(.init(time: 1, verticalAcceleration: -0.5))
        XCTAssertEqual(vm.holes, [0, 1])
        vm.pauseMotion(); XCTAssertFalse(vm.motionActive)
        vm.plant(2); XCTAssertTrue(vm.session.showsDescription)
        XCTAssertEqual(vm.session.outcome, .performed)
        vm.start(); XCTAssertTrue(vm.holes.isEmpty)
        vm.demonstrate(); XCTAssertEqual(vm.session.outcome, .observed)
    }
    @MainActor func testUnavailableAndInterruptedMotion() {
        let motion = FakeMotion(); motion.available = false
        let vm = NgaseukViewModel(motion: motion); vm.start(); vm.startMotion()
        XCTAssertFalse(vm.motionActive); XCTAssertFalse(vm.session.feedback.isEmpty)
        motion.available = true; vm.startMotion(); motion.handler?(nil)
        XCTAssertFalse(vm.motionActive); XCTAssertTrue(vm.holes.isEmpty)
        vm.plant(0); XCTAssertEqual(vm.holes.count, 1)
    }
}
