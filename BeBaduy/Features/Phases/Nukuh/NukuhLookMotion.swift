import Foundation
import simd

/// Calibrates to the phone's current pose. Quaternion deltas avoid jumps at ±180°.
struct NukuhLookMotion {
    private var reference: simd_quatf?
    private var filtered = simd_quatf(angle: 0, axis: [0, 1, 0])
    private var lastTime: Double?
    mutating func reset() { self = Self() }
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
            return filtered
        }
        let delta = simd_normalize(reference.inverse * orientation)
        let blend = Float(1 - exp(-elapsed / 0.06))
        filtered = simd_normalize(simd_slerp(filtered, delta, blend))
        return filtered
    }
}
