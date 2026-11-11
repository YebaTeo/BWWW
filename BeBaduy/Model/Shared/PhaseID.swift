import Foundation
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
}
