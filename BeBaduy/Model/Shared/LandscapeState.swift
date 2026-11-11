struct LandscapeState: Equatable {
    let phase: PhaseID
    let isResult: Bool
    var assetName: String {
        if isResult && phase == .narawas { return "ngahuru_after" }
        if phase == .ngalantai { return isResult ? "drying_rice_after" : "mipit_after" }
        let prefix = phase == .mipit ? "mipit" : phase.rawValue
        return "\(prefix)_\(isResult ? "after" : "before")"
    }
}
