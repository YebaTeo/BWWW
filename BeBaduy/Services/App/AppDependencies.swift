import Observation
import Foundation
@Observable @MainActor final class AppDependencies {
    let journey: JourneyViewModel
    let motion: MotionService
    init() {
        var defaults = UserDefaults.standard
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let suite = "BeBaduy.UITests"
            defaults = UserDefaults(suiteName: suite)!
            if ProcessInfo.processInfo.arguments.contains("--reset-progress") { defaults.removePersistentDomain(forName: suite) }
        }
        #endif
        journey = JourneyViewModel(store: ProgressStore(defaults: defaults)); motion = MotionService()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting"),
           ProcessInfo.processInfo.arguments.contains("--uitest-explanations") {
            journey.finishIntroduction()
            for phase in PhaseID.allCases { journey.record(phase, outcome: .observed) }
            journey.open(.narawas)
        }
        if ProcessInfo.processInfo.arguments.contains("--uitesting"),
           let phase = ProcessInfo.processInfo.arguments.contains("--uitest-mipit") ? PhaseID.mipit :
                       ProcessInfo.processInfo.arguments.contains("--uitest-ngored") ? PhaseID.ngored :
                       ProcessInfo.processInfo.arguments.contains("--uitest-ngaseuk") ? PhaseID.ngaseuk : nil {
            journey.finishIntroduction()
            journey.record(.narawas, outcome: .observed)
            if phase != .ngaseuk { journey.record(.ngaseuk, outcome: .observed) }
            if phase == .mipit { journey.record(.ngored, outcome: .observed) }
            journey.open(phase)
        }
        #endif
    }
}
