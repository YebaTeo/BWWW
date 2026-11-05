import SwiftUI
@main struct BeBaduyApp: App {
    @State private var dependencies = AppDependencies()
    private var testAppearance: ColorScheme? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") && ProcessInfo.processInfo.arguments.contains("--dark-appearance") { return .dark }
        #endif
        return nil
    }
    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--story-pilot") {
                    StoryPilotView(motion: dependencies.motion, previewReduceMotion: ProcessInfo.processInfo.arguments.contains("--story-reduce-motion"))
                } else {
                    HomeView(journey: dependencies.journey, motion: dependencies.motion)
                }
                #else
                HomeView(journey: dependencies.journey, motion: dependencies.motion)
                #endif
            }.tint(AppTheme.leaf).preferredColorScheme(testAppearance)
        }
    }
}
