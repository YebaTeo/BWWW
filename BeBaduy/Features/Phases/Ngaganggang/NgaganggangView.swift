import SwiftUI
struct NgaganggangView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model = NgaganggangViewModel()
    var body: some View {
        PhaseContainerView(content: NgaganggangContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance,
            introduction: { NgaganggangIntroductionView() }, activity: { NgaganggangActivityView(model: model) },
            description: { NgaganggangDescriptionView() })
    }
}
