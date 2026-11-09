import Foundation

/// Shared by the visible sky and the 3D lights: five cycles, ending in daylight.
enum HomeCelestialCycle {
    static func phase(progress: CGFloat) -> Double {
        let t = min(1, max(0, (progress - 0.666) / (0.75 - 0.666)))
        return Double(t) * .pi * 10
    }
}
