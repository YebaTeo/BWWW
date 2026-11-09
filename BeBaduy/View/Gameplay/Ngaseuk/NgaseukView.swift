import SwiftUI
struct NgaseukView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model: NgaseukViewModel
    @Environment(\.scenePhase) private var scenePhase
    init(journey: JourneyViewModel, motion: any MotionProviding, advance: @escaping () -> Void) {
        self.journey = journey; self.advance = advance
        _model = State(initialValue: NgaseukViewModel(motion: motion))
    }
    var body: some View {
        PhaseContainerView(content: NgaseukContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance, suspend: model.suspend,
            surface: { NgaseukActivitySurface(model: model) }, activity: { NgaseukActivityView(model: model) },
            description: { NgaseukDescriptionView() })
        .onDisappear { model.suspend() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.suspend() } }
    }
}
