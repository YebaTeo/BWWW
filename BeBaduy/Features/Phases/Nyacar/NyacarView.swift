import SwiftUI
struct NyacarView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model = NyacarViewModel()
    var body: some View {
        PhaseContainerView(content: NyacarContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance,
            introduction: { NyacarIntroductionView() }, activity: { NyacarActivityView(model: model) },
            description: { NyacarDescriptionView() })
    }
}
