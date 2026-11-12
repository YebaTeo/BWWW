import SwiftUI
struct NgoredView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model: NgoredViewModel
    init(journey: JourneyViewModel, motion: (any MotionProviding)? = nil, advance: @escaping () -> Void) {
        self.journey = journey
        self.advance = advance
        _model = State(initialValue: NgoredViewModel(motion: motion))
    }
    var body: some View {
        PhaseContainerView(content: PhaseContent.content(for: .ngored), session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance, suspend: model.suspend, activityVisibility: model.setVisible,
            showsActiveControls: model.step == .weeding || model.step == .secondWeeding || model.step == .initialRain || model.step == .rain || model.step == .finalRain || model.step == .cycles || model.step == .finalCycles,
            surface: { NgoredActivitySurface(model: model) }, activity: { NgoredActivityView(model: model) },
            description: { NgoredDescriptionView() })
    }
}
