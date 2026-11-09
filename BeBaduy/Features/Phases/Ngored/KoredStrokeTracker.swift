import CoreGraphics

/// Counts deliberate downward strokes. A held/long drag counts once until lifted.
struct KoredStrokeTracker {
    private var start: CGPoint?
    private var lowest: CGFloat = 0
    private var struck = false
    mutating func reset() { self = Self() }
    mutating func move(blade: CGPoint, targets: [CGPoint], removed: Set<Int>) -> Int? {
        guard blade.x.isFinite, blade.y.isFinite else { return nil }
        guard let origin = start else { start = blade; lowest = blade.y; return nil }
        if blade.y < lowest - 14 {
            start = blade; lowest = blade.y; struck = false
            return nil
        }
        lowest = max(lowest, blade.y)
        if blade.y < origin.y { start = blade; return nil }
        guard !struck, blade.y - origin.y >= 22,
              abs(blade.x - origin.x) < blade.y - origin.y else { return nil }
        guard let index = targets.indices.filter({ !removed.contains($0) }).min(by: {
            hypot(blade.x - targets[$0].x, blade.y - targets[$0].y) < hypot(blade.x - targets[$1].x, blade.y - targets[$1].y)
        }), abs(blade.x - targets[index].x) <= 34, abs(blade.y - targets[index].y) <= 40 else { return nil }
        struck = true
        return index
    }
}
