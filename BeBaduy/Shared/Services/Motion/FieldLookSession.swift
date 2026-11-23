import Foundation
import Observation
import simd

/// Owns one calibrated motion subscription for a field camera.
@MainActor @Observable final class FieldLookSession {
    private let motion: (any MotionProviding)?
    private let scene: NgahumaScene
    @ObservationIgnored private var filter = NarawasLookMotion()
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var lastAppliedRotation: simd_quatf?
    private(set) var isActive = false
    var isAvailable: Bool { motion?.available == true }

    init(motion: (any MotionProviding)?, scene: NgahumaScene) {
        self.motion = motion
        self.scene = scene
    }

    func start(onInterruption: @escaping @MainActor () -> Void) {
        guard !isActive, let motion, motion.available else { return }
        filter.reset()
        lastAppliedRotation = nil
        scene.beginMotionLook()
        isActive = true
        let token = generation
        if motion.supportsPolling {
            motion.beginPolling()
            scene.onBeforeRenderFrame = { [weak self] dt in
                self?.stepPollingFrame(dt: dt, token: token, onInterruption: onInterruption)
            }
            return
        }
        motion.start { [weak self] sample in
            guard let self, self.isActive, self.generation == token else { return }
            guard let sample, sample.attitude != nil else {
                self.stop()
                onInterruption()
                return
            }
            if let rotation = self.filter.consume(sample) {
                self.scene.applyMotionLook(rotation, fixedPosition: true)
            }
        }
    }

    func stop() {
        scene.onBeforeRenderFrame = nil
        scene.clearLookEdge()
        lastAppliedRotation = nil
        guard isActive else { return }
        isActive = false
        generation += 1
        motion?.stop()
    }

    private func stepPollingFrame(dt: TimeInterval, token: Int, onInterruption: @escaping @MainActor () -> Void) {
        guard isActive, generation == token, let motion else { return }
        guard motion.available else {
            stop()
            onInterruption()
            return
        }
        let sample = motion.currentSample()
        guard let rotation = filter.step(sample: sample, dt: dt) else { return }
        if let lastAppliedRotation,
           abs(simd_dot(lastAppliedRotation.vector, rotation.vector)) >= 0.9999999 {
            return
        }
        lastAppliedRotation = rotation
        scene.applyMotionLook(rotation, fixedPosition: true)
    }
}
