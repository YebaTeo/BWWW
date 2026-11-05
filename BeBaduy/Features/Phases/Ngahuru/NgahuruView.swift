import SwiftUI
struct NgahuruView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model = NgahuruViewModel()
    var body: some View {
        PhaseContainerView(content: NgahuruContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance,
            introduction: { NgahuruIntroductionView() }, activity: { NgahuruActivityView(model: model) },
            description: { NgahuruDescriptionView() })
    }
}
