import SwiftUI
struct NgaseukView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model: NgaseukViewModel
    @Environment(\.scenePhase) private var scenePhase
    init(journey: JourneyViewModel, motion: any MotionProviding, advance: @escaping () -> Void) {
        self.journey = journey; self.advance = advance
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting"), arguments.contains("--uitest-ngaseuk-motion") {
            _model = State(initialValue: NgaseukViewModel(motion: NgaseukUITestMotion()))
            return
        }
        #endif
        _model = State(initialValue: NgaseukViewModel(motion: motion))
    }
    var body: some View {
        PhaseContainerView(content: PhaseContent.content(for: .ngaseuk), session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance, suspend: model.suspend, activityVisibility: model.setActivityVisible,
            showsInitialActivityCard: false,
            surface: { NgaseukActivitySurface(model: model) }, activity: { NgaseukActivityView(model: model) },
            description: { NgaseukDescriptionView() })
        .onDisappear { model.suspend() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.suspend() } }
    }
}
