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
           ProcessInfo.processInfo.arguments.contains("--uitest-ngored") {
            journey.finishIntroduction()
            journey.record(.nukuh, outcome: .observed)
            journey.record(.ngaseuk, outcome: .observed)
            journey.open(.ngored)
        }
        #endif
    }
}
