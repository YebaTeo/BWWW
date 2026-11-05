import SwiftUI
struct NgubaranPareView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model = NgubaranPareViewModel()
    var body: some View {
        PhaseContainerView(content: NgubaranPareContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance,
            introduction: { NgubaranPareIntroductionView() }, activity: { NgubaranPareActivityView(model: model) },
            description: { NgubaranPareDescriptionView() })
    }
}
