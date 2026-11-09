import Foundation

struct NgaseukMotionDetector {
    private(set) var armed = false
    private var lastPlant = -Double.infinity
    private var lastTime = -Double.infinity
    let threshold = -0.28
    let neutral = 0.08
    let cooldown = 0.65
    mutating func reset() { self = Self() }
    mutating func consume(_ sample: MotionSample) -> Bool {
        guard sample.time.isFinite, sample.verticalAcceleration.isFinite, sample.time >= lastTime else { return false }
        lastTime = sample.time
        if abs(sample.verticalAcceleration) < neutral { armed = true; return false }
        guard armed, sample.verticalAcceleration < threshold, sample.time - lastPlant >= cooldown else { return false }
        armed = false; lastPlant = sample.time; return true
    }
}
