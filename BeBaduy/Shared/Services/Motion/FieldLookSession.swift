import Observation

/// Owns one calibrated motion subscription for a field camera.
@MainActor @Observable final class FieldLookSession {
    private let motion: (any MotionProviding)?
    private let scene: NgahumaScene
    @ObservationIgnored private var filter = NarawasLookMotion()
    @ObservationIgnored private var generation = 0
    private(set) var isActive = false
    var isAvailable: Bool { motion?.available == true }

    init(motion: (any MotionProviding)?, scene: NgahumaScene) {
        self.motion = motion
        self.scene = scene
    }

    func start(onInterruption: @escaping @MainActor () -> Void) {
        guard !isActive, let motion, motion.available else { return }
        filter.reset()
        scene.beginMotionLook()
        isActive = true
        let token = generation
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
        scene.clearLookEdge()
        guard isActive else { return }
        isActive = false
        generation += 1
        motion?.stop()
    }
}
