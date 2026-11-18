import Foundation

struct MotionSample: Sendable {
    let time: TimeInterval
    let verticalAcceleration: Double
    var roll: Double = 0
    var gravity: SIMD3<Double>? = nil
    var rotationRate: SIMD3<Double>? = nil
    var attitude: SIMD4<Double>? = nil
}
