enum PhaseCatalog {
    static let all = PhaseID.allCases.map { PhaseContent.content(for: $0) }

    static func content(for id: PhaseID) -> PhaseContent {
        PhaseContent.content(for: id)
    }
}
