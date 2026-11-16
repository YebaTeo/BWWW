import XCTest
import simd
@testable import BeBaduy

final class NarawasLookMotionTests: XCTestCase {
    private func sample(_ time: Double, _ rotation: simd_quatd) -> MotionSample {
        MotionSample(time: time, verticalAcceleration: 0, attitude: rotation.vector)
    }
    func testCalibratesToHeldPoseAndHandlesQuaternionSign() throws {
        var look = NarawasLookMotion()
        let pose = simd_quatd(angle: 1.2, axis: [1, 0, 0])
        let first = try XCTUnwrap(look.consume(sample(0, pose)))
        XCTAssertEqual(first.angle, 0, accuracy: 0.001)
        let equivalent = simd_quatd(vector: -pose.vector)
        let second = try XCTUnwrap(look.consume(sample(0.1, equivalent)))
        XCTAssertEqual(abs(simd_dot(second.vector, first.vector)), 1, accuracy: 0.001)
        XCTAssertNil(look.consume(sample(0.05, pose)))
        XCTAssertNil(look.consume(MotionSample(time: 1, verticalAcceleration: 0, attitude: .zero)))
    }
    func testTurningAcrossAngleBoundaryStaysContinuousAndResetRecenters() throws {
        var look = NarawasLookMotion()
        _ = look.consume(sample(0, simd_quatd(angle: .pi - 0.02, axis: [0, 1, 0])))
        let turned = try XCTUnwrap(look.consume(sample(0.1, simd_quatd(angle: -.pi + 0.02, axis: [0, 1, 0]))))
        XCTAssertLessThan(abs(turned.angle), 0.05)
        XCTAssertGreaterThan(abs(turned.angle), 0.01)
        look.reset()
        XCTAssertEqual(try XCTUnwrap(look.consume(sample(2, simd_quatd(angle: 1, axis: [1, 0, 0])))).angle, 0, accuracy: 0.001)
    }
    func testGyroRestrictsToHorizontalLeftRightOnly() throws {
        var look = NarawasLookMotion()
        _ = look.consume(sample(0, simd_quatd(angle: 0, axis: [0, 1, 0])))
        let purePitch = try XCTUnwrap(look.consume(sample(0.1, simd_quatd(angle: 0.6, axis: [1, 0, 0]))))
        XCTAssertEqual(purePitch.angle, 0, accuracy: 0.001)
        let pureRoll = try XCTUnwrap(look.consume(sample(0.2, simd_quatd(angle: 0.4, axis: [0, 0, 1]))))
        XCTAssertEqual(pureRoll.angle, 0, accuracy: 0.001)

        let combined3D = simd_quatd(angle: 0.5, axis: [0, 1, 0])
            * simd_quatd(angle: 0.6, axis: [1, 0, 0])
            * simd_quatd(angle: 0.4, axis: [0, 0, 1])
        let yawResult = try XCTUnwrap(look.consume(sample(0.3, combined3D)))
        XCTAssertEqual(yawResult.imag.x, 0, accuracy: 0.0001)
        XCTAssertEqual(yawResult.imag.z, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(abs(yawResult.imag.y), 0.1)
    }
    @MainActor func testMotionLifecycleRecenterAndLateCallback() {
        let motion = FakeMotion()
        let model = NarawasViewModel(motion: motion)
        model.start(); model.configureLookMotion(reduceMotion: false); model.setVisible(true)
        XCTAssertTrue(model.motionActive)
        motion.handler?(sample(0, simd_quatd(angle: 0, axis: [0, 1, 0])))
        motion.handler?(sample(0.1, simd_quatd(angle: 0.5, axis: [0, 1, 0])))
        XCTAssertGreaterThan(model.scene.motionOrientation.angle, 0.1)
        model.recenterLook()
        XCTAssertEqual(model.scene.motionOrientation.angle, 0, accuracy: 0.001)
        let stale = motion.handler
        model.setVisible(false)
        XCTAssertFalse(model.motionActive)
        stale?(sample(0.2, simd_quatd(angle: 1, axis: [0, 1, 0])))
        XCTAssertEqual(model.scene.motionOrientation.angle, 0, accuracy: 0.001)
        model.setVisible(true)
        XCTAssertTrue(model.motionActive)
        model.configureLookMotion(reduceMotion: true)
        XCTAssertFalse(model.motionActive)
        XCTAssertFalse(model.motionEnabled)
    }
    @MainActor func testNgoredTurnsAroundGravityWhenHeldAtAnAngle() {
        let motion = FakeMotion()
        let model = NgoredViewModel(motion: motion)
        model.start()
        model.setVisible(true)
        defer { model.setVisible(false) }

        let initial = model.scene.motionOrientation
        let pose = simd_quatd(angle: 1.2, axis: [1, 0, 0])
        let up = SIMD3<Double>(0, 0, 1)
        let gravity = pose.inverse.act(-up)
        motion.handler?(.init(time: 0, verticalAcceleration: 0, gravity: gravity, attitude: pose.vector))
        let pitch = simd_quatd(angle: 0.3, axis: [1, 0, 0]) * pose
        motion.handler?(.init(time: 0.1, verticalAcceleration: 0, gravity: pitch.inverse.act(-up), attitude: pitch.vector))
        XCTAssertEqual(abs(simd_dot(initial.vector, model.scene.motionOrientation.vector)), 1, accuracy: 0.001)

        let turned = simd_quatd(angle: 0.2, axis: up) * pose
        motion.handler?(.init(time: 0.2, verticalAcceleration: 0, gravity: gravity, attitude: turned.vector))
        let change = initial.inverse * model.scene.motionOrientation
        XCTAssertEqual(change.angle, 0.196, accuracy: 0.005)
        XCTAssertEqual(change.imag.x, 0, accuracy: 0.001)
        XCTAssertEqual(change.imag.z, 0, accuracy: 0.001)
    }

    @MainActor func testNgoredRecalibratesWhenSecondWeedingStarts() async throws {
        let motion = FakeMotion()
        let model = NgoredViewModel(motion: motion)
        model.start()
        model.setVisible(true)
        defer { model.setVisible(false) }
        model.beginInitialRainAfterCard()
        let deadline = ContinuousClock.now + .seconds(8)
        while model.step == .initialRain, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(model.step, .weeding)
        guard model.step == .weeding else { return }
        motion.handler?(sample(0, simd_quatd(angle: 0, axis: [0, 1, 0])))
        motion.handler?(sample(0.1, simd_quatd(angle: 0.3, axis: [0, 1, 0])))
        let beforeCycle = model.scene.motionOrientation
        let staleCallback = motion.handler

        for weed in 0..<4 {
            for _ in 0..<3 { model.remove(weed) }
        }
        model.observeRain()
        model.finishRain()
        XCTAssertEqual(model.step, .cycles)
        XCTAssertNil(motion.handler)
        staleCallback?(sample(0.2, simd_quatd(angle: 1, axis: [0, 1, 0])))
        model.setVisible(false)
        model.setVisible(true)
        XCTAssertNil(motion.handler)
        model.scene.advanceNgoredDayNight(by: 12)
        XCTAssertEqual(model.step, .secondWeeding)
        XCTAssertNotNil(motion.handler)

        // The phone has moved during the animation. That pose is the new baseline.
        motion.handler?(sample(12.2, simd_quatd(angle: 1.2, axis: [0, 1, 0])))
        XCTAssertEqual(abs(simd_dot(beforeCycle.vector, model.scene.motionOrientation.vector)), 1, accuracy: 0.0001)
        motion.handler?(sample(12.3, simd_quatd(angle: 1.4, axis: [0, 1, 0])))
        XCTAssertEqual((beforeCycle.inverse * model.scene.motionOrientation).angle, 0.196, accuracy: 0.005)
    }

    @MainActor func testMissingSensorAndInterruptionKeepTouchAvailable() {
        let motion = FakeMotion(); motion.available = false
        let model = NarawasViewModel(motion: motion)
        model.start(); model.configureLookMotion(reduceMotion: false); model.setVisible(true)
        XCTAssertFalse(model.motionActive); XCTAssertFalse(model.motionMessage.isEmpty)
        motion.available = true
        model.setVisible(true)
        motion.handler?(nil)
        XCTAssertFalse(model.motionActive)
        XCTAssertFalse(model.motionMessage.isEmpty)
        model.suspend()
    }
}
