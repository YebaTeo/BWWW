import CoreMotion

/// AppDependencies creates exactly one manager for the app.
@MainActor final class MotionService: MotionProviding {
    private let manager = CMMotionManager()
    private var generation = 0
    var available: Bool { manager.isDeviceMotionAvailable }
    func start(handler: @escaping @MainActor (MotionSample?) -> Void) {
        stop()
        guard available else { handler(nil); return }
        let token = generation
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            let sample = data.flatMap { data -> MotionSample? in
                let gravity = data.gravity
                let magnitude = (gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z).squareRoot()
                guard magnitude > 0.5 else { return nil }
                let acceleration = data.userAcceleration
                // Project onto gravity (`gravity` points toward Earth's center, so `userAcceleration · gravity > 0`
                // when accelerating downward and `< 0` when accelerating upward).
                // Negate `downward` so `verticalAcceleration` is negative (< 0) when accelerating DOWNWARD
                // and positive (> 0) when accelerating UPWARD.
                let downward = (acceleration.x * gravity.x + acceleration.y * gravity.y + acceleration.z * gravity.z) / magnitude
                let q = data.attitude.quaternion
                let rate = data.rotationRate
                return MotionSample(time: data.timestamp, verticalAcceleration: -downward, roll: data.attitude.roll, gravity: SIMD3(gravity.x, gravity.y, gravity.z), rotationRate: SIMD3(rate.x, rate.y, rate.z), attitude: SIMD4(q.x, q.y, q.z, q.w))
            }
            let failed = error != nil || sample == nil
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                if failed { self.stop(); handler(nil) } else { handler(sample) }
            }
        }
    }
    func stop() { generation += 1; manager.stopDeviceMotionUpdates() }
}
