import SwiftUI
struct NarawasView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model = NarawasViewModel()
    var body: some View {
        PhaseContainerView(content: NarawasContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance,
            introduction: { NarawasIntroductionView() }, activity: { NarawasActivityView(model: model) },
            description: { NarawasDescriptionView() })
    }
}
