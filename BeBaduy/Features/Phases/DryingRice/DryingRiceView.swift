import SwiftUI
struct DryingRiceView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model = DryingRiceViewModel()
    var body: some View {
        PhaseContainerView(content: DryingRiceContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance,
            introduction: { DryingRiceIntroductionView() }, activity: { DryingRiceActivityView(model: model) },
            description: { DryingRiceDescriptionView() })
    }
}
