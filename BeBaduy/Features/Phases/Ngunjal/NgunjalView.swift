import SwiftUI
struct NgunjalView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model = NgunjalViewModel()
    var body: some View {
        PhaseContainerView(content: NgunjalContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance,
            introduction: { NgunjalIntroductionView() }, activity: { NgunjalActivityView(model: model) },
            description: { NgunjalDescriptionView() })
    }
}
