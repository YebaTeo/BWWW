struct LandscapeState: Equatable {
    let phase: PhaseID
    let isResult: Bool
    var assetName: String {
        // Share existing artwork where chapters now join; avoid duplicate image files.
        if isResult && phase == .nukuh { return "ngaseuk_before" }
        if isResult && phase == .dibuat { return "drying_rice_after" }
        return "\(phase.rawValue)_\(isResult ? "after" : "before")"
    }
}
