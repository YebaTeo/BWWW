import SwiftUI
struct NgaleuitkeunPareView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model = NgaleuitkeunPareViewModel()
    var body: some View {
        PhaseContainerView(content: PhaseContent.content(for: .ngaleuitkeunPare), session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance,
            showsInitialActivityCard: false,
            surface: { NgaleuitkeunPareActivitySurface(model: model) }, activity: { NgaleuitkeunPareActivityView(model: model) },
            description: { NgaleuitkeunPareDescriptionView() })
    }
}
