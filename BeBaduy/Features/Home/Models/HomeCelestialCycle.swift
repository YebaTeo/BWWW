import Foundation

/// Shared by the visible sky and the 3D lights: two cycles, ending in daylight.
enum HomeCelestialCycle {
    static func phase(progress: CGFloat) -> Double {
        // Keep the sun and moon moving throughout the slower rice growth.
        // Two cycles in ten seconds preserve the five-second sky tempo.
        let t = min(1, max(0, (progress - 0.666) / (0.75 - 0.666)))
        return Double(t) * .pi * 4
    }
}
