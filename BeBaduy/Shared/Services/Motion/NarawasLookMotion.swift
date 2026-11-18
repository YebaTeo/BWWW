import Foundation
import simd

/// Calibrates to the phone's current pose. Quaternion deltas avoid jumps at ±180°.
struct NarawasLookMotion {
    private let smoothingTime: Double
    private let stableHeading: Bool
    private var referenceUp = SIMD3<Float>(0, 1, 0)
    private var headingAxis = SIMD3<Float>(1, 0, 0)
    private var referenceHeading = SIMD3<Float>(1, 0, 0)
    private var lastHeading: Float = 0
    private var reference: simd_quatf?
    private var filtered = simd_quatf(angle: 0, axis: [0, 1, 0])
    private var lastTime: Double?
    init(smoothingTime: Double = 0.06, stableHeading: Bool = true) {
        self.smoothingTime = smoothingTime
        self.stableHeading = stableHeading
    }

    mutating func reset() { self = Self(smoothingTime: smoothingTime, stableHeading: stableHeading) }
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
            if stableHeading {
                let right = SIMD3<Float>(1, 0, 0)
                let horizontalRight = right - referenceUp * simd_dot(right, referenceUp)
                headingAxis = simd_length(horizontalRight) > 0.35 ? right : SIMD3<Float>(0, 0, -1)
                let horizontal = headingAxis - referenceUp * simd_dot(headingAxis, referenceUp)
                referenceHeading = simd_normalize(horizontal)
            }
            return filtered
        }
        let delta = simd_normalize(reference.inverse * orientation)
        // The delta is in the starting phone frame, where world up can
        // differ from the phone's Y axis depending on how it's held.
        let yawVector = SIMD4<Float>(0, simd_dot(delta.imag, referenceUp), 0, delta.real)
        let yawLength = simd_length(yawVector)
        let originalYaw = yawLength > 0.0001
            ? simd_quatf(vector: yawVector / yawLength)
            : simd_quatf(angle: 0, axis: [0, 1, 0])
        let target: simd_quatf
        if stableHeading {
            // Screen right stays horizontal while the phone is lifted. Derive
            // only heading from it; the camera's vertical angle remains fixed.
            let rotatedAxis = delta.act(headingAxis)
            let horizontal = rotatedAxis - referenceUp * simd_dot(rotatedAxis, referenceUp)
            if simd_length(horizontal) > 0.08 {
                let direction = simd_normalize(horizontal)
                lastHeading = atan2(
                    simd_dot(simd_cross(referenceHeading, direction), referenceUp),
                    simd_dot(referenceHeading, direction)
                )
            }
            target = simd_quatf(angle: lastHeading, axis: [0, 1, 0])
        } else {
            target = originalYaw
        }
        let blend = Float(1 - exp(-elapsed / smoothingTime))
        filtered = simd_normalize(simd_slerp(filtered, target, blend))
        return filtered
    }
}
