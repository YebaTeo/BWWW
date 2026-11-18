enum NarawasPlot {
    // Three interactive trees distributed around the clearing, matching HEAD.
    static let placements: [(angle: Float, distance: Float, yawOffset: Float, scale: Float)] = [
        (0, 1.84, -0.06, 2.25),
        (2 * .pi / 3, 1.86, -0.09, 2.15),
        (4 * .pi / 3, 1.85, -0.08, 2.20)
    ]

    static var indices: Range<Int> { placements.indices }
    static var count: Int { placements.count }
    static let ignitionRadius: Float = 0.34
}
