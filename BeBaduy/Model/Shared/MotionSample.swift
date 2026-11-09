import Foundation

struct MotionSample: Sendable {
    let time: TimeInterval
    let verticalAcceleration: Double
    var roll: Double = 0
    var attitude: SIMD4<Double>? = nil
}
