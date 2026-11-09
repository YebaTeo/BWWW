import Foundation

/// One gentle back-and-forth movement after a steady hold, not repeated shaking.
struct SeedPourMotionDetector {
    private var armed = false
    private var firstDirection: Double?
    private var firstTime: TimeInterval = 0
    private var lastTime = -Double.infinity
    mutating func reset() { self = Self() }
    mutating func consume(_ sample: MotionSample) -> Bool {
        guard sample.time.isFinite, sample.verticalAcceleration.isFinite, sample.time > lastTime else { return false }
        lastTime = sample.time
        let acceleration = sample.verticalAcceleration
        if !armed {
            if abs(acceleration) < 0.08 { armed = true }
            return false
        }
        if let direction = firstDirection {
            if sample.time - firstTime > 1.2 { firstDirection = nil }
            else if acceleration * direction < 0 && abs(acceleration) > 0.18 {
                reset()
                return true
            }
        }
        if firstDirection == nil && abs(acceleration) > 0.18 {
            firstDirection = acceleration
            firstTime = sample.time
        }
        return false
    }
}
