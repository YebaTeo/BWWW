import Foundation

enum ActivityOutcome: String, Codable, Sendable { case observed, performed }
enum SessionStage { case introduction, active, reflection }

/// Only temporary presentation state. Durable completion belongs to JourneyViewModel.
struct PhaseSessionState {
    private(set) var stage: SessionStage = .introduction
    private(set) var outcome: ActivityOutcome?
    private(set) var event = 0
    var feedback = ""
    var isActive: Bool { stage == .active }
    var showsDescription: Bool { stage == .reflection }
    mutating func start() { stage = .active; feedback = ""; outcome = nil }
    mutating func finish(_ outcome: ActivityOutcome = .performed) {
        guard stage != .reflection else { return }
        self.outcome = outcome; stage = .reflection; event += 1
        feedback = outcome == .observed ? "Demonstrasi selesai. Lanjutkan untuk melihat penjelasan." : "Aktivitas selesai. Lanjutkan untuk melihat penjelasan."
    }
    mutating func restore(_ outcome: ActivityOutcome?) {
        guard let outcome else { return }
        self.outcome = outcome; stage = .reflection
    }
}
