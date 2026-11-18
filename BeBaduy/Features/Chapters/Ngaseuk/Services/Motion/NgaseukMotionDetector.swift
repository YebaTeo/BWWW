import Foundation

struct NgaseukMotionDetector {
    private(set) var armed = false
    private var lastPlant = -Double.infinity
    private var lastUpwardTime = -Double.infinity
    private var lastTime = -Double.infinity
    let threshold = -0.45
    let upwardDisarmThreshold = 0.25
    let neutral = 0.16
    let cooldown = 0.85
    let rearmDelay = 0.22
    /// Short lockout after an upward lift so the braking at the top of the lift is ignored.
    let liftLockout = 0.12
    mutating func reset() { self = Self() }
    mutating func consume(_ sample: MotionSample) -> Bool {
        guard sample.time.isFinite, sample.verticalAcceleration.isFinite, sample.time >= lastTime else { return false }
        lastTime = sample.time

        let a = sample.verticalAcceleration

        // When lifting the phone UP, the movement starts with positive acceleration (> upwardDisarmThreshold)
        // and ends with negative braking deceleration when stopping at the top.
        // Disarming on positive acceleration prevents the top-of-lift braking from triggering a dig.
        if a > upwardDisarmThreshold {
            armed = false
            lastUpwardTime = sample.time
            return false
        }

        if abs(a) < neutral {
            if sample.time - lastPlant >= rearmDelay && sample.time - lastUpwardTime >= liftLockout {
                armed = true
            }
            return false
        }

        // Also allow a deliberate downward thrust right after an upward windup, once the
        // top-of-lift braking window has passed.
        let readyAfterWindup = lastUpwardTime > lastPlant && (liftLockout...0.45).contains(sample.time - lastUpwardTime)
        guard sample.time - lastPlant >= cooldown,
              sample.time - lastUpwardTime >= liftLockout,
              (armed || readyAfterWindup),
              a < threshold else { return false }
        armed = false
        lastPlant = sample.time
        return true
    }
}
