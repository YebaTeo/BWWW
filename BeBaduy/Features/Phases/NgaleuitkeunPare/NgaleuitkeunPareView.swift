import SwiftUI
struct NgaleuitkeunPareView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model = NgaleuitkeunPareViewModel()
    var body: some View {
        PhaseContainerView(content: NgaleuitkeunPareContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance,
            introduction: { NgaleuitkeunPareIntroductionView() }, activity: { NgaleuitkeunPareActivityView(model: model) },
            description: { NgaleuitkeunPareDescriptionView() })
    }
}
