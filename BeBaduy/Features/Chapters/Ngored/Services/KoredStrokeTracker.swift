import CoreGraphics

/// Checks each new segment of the finger's path until one weed is hit.
struct KoredStrokeTracker {
    private var previous: CGPoint?
    private var hit = false

    mutating func begin(at point: CGPoint) {
        previous = point
        hit = false
    }

    mutating func move(to point: CGPoint, hitTest: (CGPoint, CGPoint) -> Bool) {
        guard !hit, let previous, previous != point else { return }
        self.previous = point
        hit = hitTest(previous, point)
    }

    /// Squared distance to the swipe in units of the target ellipse's radii.
    static func hitDistance(from start: CGPoint, to end: CGPoint, in target: CGRect) -> CGFloat? {
        guard target.width > 0, target.height > 0 else { return nil }
        let x = (start.x - target.midX) / (target.width / 2)
        let y = (start.y - target.midY) / (target.height / 2)
        let dx = (end.x - start.x) / (target.width / 2)
        let dy = (end.y - start.y) / (target.height / 2)
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return nil }
        let t = min(1, max(0, -(x * dx + y * dy) / lengthSquared))
        let distance = pow(x + t * dx, 2) + pow(y + t * dy, 2)
        return distance <= 1 ? distance : nil
    }
}
