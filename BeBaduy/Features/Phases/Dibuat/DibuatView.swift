import SwiftUI
struct DibuatView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model = DibuatViewModel()
    var body: some View {
        PhaseContainerView(content: DibuatContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance,
            introduction: { DibuatIntroductionView() }, activity: { DibuatActivityView(model: model) },
            description: { DibuatDescriptionView() })
    }
}
