import XCTest
import simd
@testable import BeBaduy

final class NukuhLookMotionTests: XCTestCase {
    private func sample(_ time: Double, _ rotation: simd_quatd) -> MotionSample {
        MotionSample(time: time, verticalAcceleration: 0, attitude: rotation.vector)
    }
    func testCalibratesToHeldPoseAndHandlesQuaternionSign() throws {
        var look = NukuhLookMotion()
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
        var look = NukuhLookMotion()
        _ = look.consume(sample(0, simd_quatd(angle: .pi - 0.02, axis: [0, 1, 0])))
        let turned = try XCTUnwrap(look.consume(sample(0.1, simd_quatd(angle: -.pi + 0.02, axis: [0, 1, 0]))))
        XCTAssertLessThan(abs(turned.angle), 0.05)
        XCTAssertGreaterThan(abs(turned.angle), 0.01)
        look.reset()
        XCTAssertEqual(try XCTUnwrap(look.consume(sample(2, simd_quatd(angle: 1, axis: [1, 0, 0])))).angle, 0, accuracy: 0.001)
    }
    @MainActor func testMotionLifecycleRecenterAndLateCallback() {
        let motion = FakeMotion()
        let model = NukuhViewModel(motion: motion)
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
    @MainActor func testMissingSensorAndInterruptionKeepTouchAvailable() {
        let motion = FakeMotion(); motion.available = false
        let model = NukuhViewModel(motion: motion)
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
