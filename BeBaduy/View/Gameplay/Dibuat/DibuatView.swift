import SwiftUI
struct DibuatView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var showsHelp = true
    @State private var model: DibuatViewModel
    init(journey: JourneyViewModel, motion: any MotionProviding, advance: @escaping () -> Void) {
        self.journey = journey; self.advance = advance
        _model = State(initialValue: DibuatViewModel(motion: motion))
    }
    var body: some View {
        PhaseContainerView(content: PhaseContent.content(for: .dibuat), session: model.session, journey: journey,
            start: start, replay: start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance, suspend: model.suspend,
            usesContextCards: false,
            surface: { DibuatActivitySurface(model: model)
                .disabled(showsHelp).allowsHitTesting(!showsHelp).accessibilityHidden(showsHelp) }, activity: { DibuatActivityView(model: model, showsHelp: $showsHelp) },
            description: { DibuatDescriptionView() })
    }
    private func start() {
        showsHelp = true
        model.start()
    }
}
