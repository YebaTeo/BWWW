struct LandscapeState: Equatable {
    let phase: PhaseID
    let isResult: Bool
    var assetName: String { "\(phase.rawValue)_\(isResult ? "after" : "before")" }
}
