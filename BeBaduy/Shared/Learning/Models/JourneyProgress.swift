import Foundation

struct PhaseProgress: Codable, Equatable {
    var observed = false
    var performed = false
    var explanationAvailable = false
    var outcome: ActivityOutcome? { performed ? .performed : observed ? .observed : nil }
}
struct JourneyProgress: Codable, Equatable {
    var secondCycle = false
    var version = 3
    var introductionSeen = false
    var currentPhase: PhaseID = .narawas
    var phases: [String: PhaseProgress] = [:]
    var journeyCompleted = false
    var earnedCardIDs: Set<String> = []

    private enum CodingKeys: String, CodingKey {
        case secondCycle, version, introductionSeen, currentPhase, phases, journeyCompleted, earnedCardIDs
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        introductionSeen = try container.decode(Bool.self, forKey: .introductionSeen)
        currentPhase = try container.decode(PhaseID.self, forKey: .currentPhase)
        phases = try container.decode([String: PhaseProgress].self, forKey: .phases)
        journeyCompleted = try container.decode(Bool.self, forKey: .journeyCompleted)
        earnedCardIDs = try container.decodeIfPresent(Set<String>.self, forKey: .earnedCardIDs) ?? []
        secondCycle = try container.decodeIfPresent(Bool.self, forKey: .secondCycle)
            ?? (earnedCardIDs.contains(ChapterCard.epic.imageName) && !allComplete)

    }

    func record(for phase: PhaseID) -> PhaseProgress { phases[phase.rawValue] ?? PhaseProgress() }
    func isUnlocked(_ phase: PhaseID) -> Bool {
        phase.index == 0 || PhaseID.allCases.prefix(phase.index).allSatisfy { record(for: $0).explanationAvailable }
    }
    mutating func complete(_ phase: PhaseID, outcome: ActivityOutcome) {
        guard isUnlocked(phase) else { return }
        var entry = record(for: phase)
        if outcome == .performed { entry.performed = true } else { entry.observed = true }
        entry.explanationAvailable = true; phases[phase.rawValue] = entry
        earnedCardIDs.insert(ChapterCard.chapter(phase, secondCycle: secondCycle).imageName)
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
