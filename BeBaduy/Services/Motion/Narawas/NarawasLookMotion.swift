import Foundation
import simd

/// Calibrates to the phone's current pose. Quaternion deltas avoid jumps at ±180°.
struct NarawasLookMotion {
    private let smoothingTime: Double
    private var referenceUp = SIMD3<Float>(0, 1, 0)
    private var reference: simd_quatf?
    private var filtered = simd_quatf(angle: 0, axis: [0, 1, 0])
    private var lastTime: Double?
    init(smoothingTime: Double = 0.06) {
        self.smoothingTime = smoothingTime
    }

    mutating func reset() { self = Self(smoothingTime: smoothingTime) }
    mutating func consume(_ sample: MotionSample) -> simd_quatf? {
        guard sample.time.isFinite, let vector = sample.attitude,
              vector.x.isFinite, vector.y.isFinite, vector.z.isFinite, vector.w.isFinite,
              lastTime == nil || sample.time > lastTime! else { return nil }
        let length = simd_length(vector)
        guard length > 0.5, length < 1.5 else { return nil }
        let orientation = simd_quatf(vector: SIMD4<Float>(vector / length))
        let elapsed = lastTime.map { min(sample.time - $0, 0.1) } ?? 0
        lastTime = sample.time
        guard let reference else {
            self.reference = orientation
            if let gravity = sample.gravity {
                let magnitude = simd_length(gravity)
                if magnitude.isFinite, magnitude > 0.5 {
                    referenceUp = SIMD3<Float>(-gravity / magnitude)
                }
            }
            return filtered
        }
        let delta = simd_normalize(reference.inverse * orientation)
        // The delta is in the starting phone frame, where world up can
        // differ from the phone's Y axis depending on how it's held.
        let yawVector = SIMD4<Float>(0, simd_dot(delta.imag, referenceUp), 0, delta.real)
        let yawLength = simd_length(yawVector)
        let horizontalDelta = yawLength > 0.0001
            ? simd_quatf(vector: yawVector / yawLength)
            : simd_quatf(angle: 0, axis: [0, 1, 0])
        let blend = Float(1 - exp(-elapsed / smoothingTime))
        filtered = simd_normalize(simd_slerp(filtered, horizontalDelta, blend))
        return filtered
    }
}
