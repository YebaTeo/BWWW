import Foundation
enum PhaseID: String, CaseIterable, Codable, Identifiable, Sendable {
    // Keep resource keys stable; progress is migrated separately.
    case nukuh = "ngahuru"
    case ngaseuk, ngored, dibuat
    case ngaleuitkeunPare = "ngaleuitkeun_pare"
    var id: String { rawValue }
    var index: Int { Self.allCases.firstIndex(of: self)! }
    var next: Self? { Self.allCases.dropFirst(index + 1).first }
}
