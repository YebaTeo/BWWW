import SwiftUI
struct NgoredView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    private let wasPreparedBeforeNavigation: Bool
    @State private var model: NgoredViewModel
    init(journey: JourneyViewModel, motion: (any MotionProviding)? = nil,
         preparedModel: NgoredViewModel? = nil, advance: @escaping () -> Void) {
        self.journey = journey
        self.advance = advance
        wasPreparedBeforeNavigation = preparedModel != nil
        _model = State(initialValue: preparedModel ?? NgoredViewModel(motion: motion))
    }
    var body: some View {
        PhaseContainerView(content: PhaseContent.content(for: .ngored), session: model.session, journey: journey,
            prepareActivity: wasPreparedBeforeNavigation ? nil : { await model.scene.prepareNgoredField() },
            start: start,
            restore: { model.session.restore($0) }, advance: advance, suspend: model.suspend, activityVisibility: model.setVisible,
            showsActiveControls: model.step == .cleared || model.step == .secondCleared || model.step == .complete,
            surface: { NgoredActivitySurface(model: model) }, activity: { NgoredActivityView(model: model) },
            description: { NgoredDescriptionView() })
    }

    private func start() {
        model.start()
        if journey.progress.record(for: .ngored).explanationAvailable {
            model.beginInitialRainAfterCard()
        }
    }
}
