enum ChapterCard: Hashable, Identifiable {
    case chapter(PhaseID)
    case epic

    var id: Self { self }

    var title: String {
        switch self {
        case .chapter(let phase): PhaseContent.content(for: phase).title
        case .epic: "EpicCard"
        }
    }

    var explanation: String {
        switch self {
        case .chapter(let phase): PhaseContent.content(for: phase).explanation
        case .epic: "Dari membuka huma hingga menyimpan pare di leuit, kamu telah menuntaskan keenam tahap perjalanan Ngahuma."
        }
    }

    var imageName: String {
        switch self {
        case .chapter(let phase): "Journey-\(phase.rawValue)"
        case .epic: "HumaSunsetValley"
        }
    }

    static let all = PhaseID.allCases.map(Self.chapter) + [.epic]

    func isEarned(in progress: JourneyProgress) -> Bool {
        switch self {
        case .chapter(let phase): progress.record(for: phase).explanationAvailable
        case .epic: progress.allComplete
        }
    }
}
