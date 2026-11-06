import SwiftUI
struct DibuatView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model: DibuatViewModel
    init(journey: JourneyViewModel, motion: any MotionProviding, advance: @escaping () -> Void) {
        self.journey = journey; self.advance = advance
        _model = State(initialValue: DibuatViewModel(motion: motion))
    }
    var body: some View {
        PhaseContainerView(content: DibuatContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance, suspend: model.suspend,
            activityVisibility: { if $0 { model.resume() } else { model.suspend() } },
            introduction: { DibuatIntroductionView() }, activity: { DibuatActivityView(model: model) },
            description: { DibuatDescriptionView() })
    }
}
