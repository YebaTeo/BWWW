import Foundation
import CoreGraphics

enum PhaseID: String, CaseIterable, Codable, Identifiable, Sendable {
    // Keep resource keys stable; progress is migrated separately.
    case narawas = "ngahuru"
    case ngaseuk, ngored
    case mipit = "dibuat"
    case ngalantai
    case ngaleuitkeunPare = "ngaleuitkeun_pare"
    var id: String { rawValue }
    var index: Int { Self.allCases.firstIndex(of: self)! }
    var next: Self? { Self.allCases.dropFirst(index + 1).first }

    /// Normalized Home scene progress [0.0 ... 1.0] representing this phase
    var homeProgress: CGFloat {
        switch self {
        case .narawas: return 0.0
        case .ngaseuk: return 0.333
        case .ngored: return 0.666
        case .mipit: return 0.75
        case .ngalantai: return 0.90
        case .ngaleuitkeunPare: return 1.0
        }
    }

    /// Progress adjusted for whether the stage is in introduction/activity vs completed result
    func progress(isResult: Bool) -> CGFloat {
        guard isResult else { return homeProgress }
        switch self {
        case .narawas: return 0.25
        case .ngaseuk: return 0.45
        case .ngored: return 0.70
        case .mipit: return 0.85
        case .ngalantai: return 0.95
        case .ngaleuitkeunPare: return 1.0
        }
    }
}
