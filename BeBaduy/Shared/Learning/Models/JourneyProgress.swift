import Foundation

struct PhaseProgress: Codable, Equatable {
    var observed = false
    var performed = false
    var explanationAvailable = false
    var outcome: ActivityOutcome? { performed ? .performed : observed ? .observed : nil }
}
struct JourneyProgress: Codable, Equatable {
    var version = 3
    var introductionSeen = false
    var currentPhase: PhaseID = .narawas
    var phases: [String: PhaseProgress] = [:]
    var journeyCompleted = false
    func record(for phase: PhaseID) -> PhaseProgress { phases[phase.rawValue] ?? PhaseProgress() }
    func isUnlocked(_ phase: PhaseID) -> Bool {
        phase.index == 0 || PhaseID.allCases.prefix(phase.index).allSatisfy { record(for: $0).explanationAvailable }
    }
    mutating func complete(_ phase: PhaseID, outcome: ActivityOutcome) {
        guard isUnlocked(phase) else { return }
        var entry = record(for: phase)
        if outcome == .performed { entry.performed = true } else { entry.observed = true }
        entry.explanationAvailable = true; phases[phase.rawValue] = entry
    }
    var allComplete: Bool { PhaseID.allCases.allSatisfy { record(for: $0).explanationAvailable } }
    var isValid: Bool {
        version == 3 && isUnlocked(currentPhase) && (!journeyCompleted || allComplete) &&
        phases.allSatisfy { key, value in
            guard let phase = PhaseID(rawValue: key) else { return false }
            return value.explanationAvailable == (value.observed || value.performed) && (!value.explanationAvailable || isUnlocked(phase))
        }
    }
}
