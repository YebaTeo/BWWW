import SwiftUI
struct NgoredView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model = NgoredViewModel()
    var body: some View {
        PhaseContainerView(content: NgoredContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance, suspend: model.suspend, activityVisibility: model.setVisible,
            surface: { NgoredActivitySurface(model: model) }, activity: { NgoredActivityView(model: model) },
            description: { NgoredDescriptionView() })
    }
}
