enum NukuhPlot {
    // Angles are in radians. Stagger the depths so neighboring trunks stay distinct.
    static let placements: [(angle: Float, distance: Float, yawOffset: Float, scale: Float)] = [
        (-0.065, 2.05, -0.06, 2.25),
        (-0.195, 2.35,  0.08, 2.45),
        ( 0.070, 2.40, -0.09, 2.15),
        ( 0.195, 2.12,  0.07, 2.38)
    ]

    static var indices: Range<Int> { placements.indices }
    static var count: Int { placements.count }
    static let ignitionRadius: Float = 0.34
}
