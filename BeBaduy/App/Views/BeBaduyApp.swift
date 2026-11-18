import SwiftUI
@main struct BeBaduyApp: App {
    @UIApplicationDelegateAdaptor(HarvestOrientationDelegate.self) private var orientationDelegate
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
                HomeView(journey: dependencies.journey, motion: dependencies.motion)
            }.tint(AppTheme.leaf).preferredColorScheme(testAppearance)
        }
    }
}
