struct LandscapeState: Equatable {
    let phase: PhaseID
    let isResult: Bool
    var assetName: String {
        if isResult && phase == .nukuh { return "ngahuru_after" }
        if phase == .ngalantai { return isResult ? "drying_rice_after" : "dibuat_after" }
        return "\(phase.rawValue)_\(isResult ? "after" : "before")"
    }
}
