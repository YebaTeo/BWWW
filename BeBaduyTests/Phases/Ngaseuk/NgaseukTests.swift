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
    @MainActor func testDiggingAndSeedingAreSeparateAndMotionStops() {
        let motion = FakeMotion(); let vm = NgaseukViewModel(motion: motion)
        vm.start(); vm.dig(0); XCTAssertTrue(vm.holes.isEmpty)
        vm.proceed(); vm.dig(0); vm.dig(0); vm.dig(-1)
        XCTAssertEqual(vm.holes, [0]); XCTAssertFalse(vm.seed(0))
        vm.startMotion()
        motion.handler?(.init(time: 0, verticalAcceleration: 0))
        motion.handler?(.init(time: 1, verticalAcceleration: -0.5))
        vm.dig(2)
        XCTAssertEqual(vm.step, .holesReady)
        XCTAssertFalse(vm.motionActive); XCTAssertNil(vm.session.outcome)
        vm.proceed()
        XCTAssertTrue(vm.seed(0)); XCTAssertFalse(vm.seed(0))
        vm.seed(1); vm.seed(2)
        XCTAssertEqual(vm.session.outcome, .performed)
        vm.start(); XCTAssertTrue(vm.seeds.isEmpty)
    }
    @MainActor func testUnavailableSensorAndDemoCancellation() async {
        let motion = FakeMotion(); motion.available = false
        let vm = NgaseukViewModel(motion: motion); vm.start(); vm.proceed(); vm.startMotion()
        XCTAssertFalse(vm.motionActive); XCTAssertFalse(vm.session.feedback.isEmpty)
        vm.demonstrate(); vm.suspend()
        await Task.yield()
        XCTAssertNil(vm.session.outcome); XCTAssertFalse(vm.isDemonstrating)
    }
}
