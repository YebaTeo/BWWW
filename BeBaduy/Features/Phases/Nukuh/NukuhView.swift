import SwiftUI
struct NukuhView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model: NukuhViewModel
    init(journey: JourneyViewModel, motion: any MotionProviding, advance: @escaping () -> Void) {
        self.journey = journey; self.advance = advance
        _model = State(initialValue: NukuhViewModel(motion: motion))
    }
    var body: some View {
        PhaseContainerView(content: NukuhContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: { model.demonstrate() },
            restore: model.restore, advance: advance, suspend: model.suspend,
            activityVisibility: model.setVisible,
            introduction: { NukuhIntroductionView() }, activity: { NukuhActivityView(model: model) },
            description: { NukuhDescriptionView() })
    }
}
