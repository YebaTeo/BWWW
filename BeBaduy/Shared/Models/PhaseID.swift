import Foundation

enum PhaseID: String, CaseIterable, Codable, Identifiable, Sendable {
    case narawas, nyacar, ngaganggang, ngahuru, ngaseuk, ngored
    case ngubaranPare = "ngubaran_pare"
    case dibuat
    case dryingRice = "drying_rice"
    case ngunjal
    case ngaleuitkeunPare = "ngaleuitkeun_pare"
    var id: String { rawValue }
    var index: Int { Self.allCases.firstIndex(of: self)! }
    var next: Self? { Self.allCases.dropFirst(index + 1).first }
}
