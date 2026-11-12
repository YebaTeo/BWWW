import SwiftUI
struct MipitView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var showsHelp = true
    @State private var model: MipitViewModel
    init(journey: JourneyViewModel, motion: any MotionProviding, advance: @escaping () -> Void) {
        self.journey = journey; self.advance = advance
        _model = State(initialValue: MipitViewModel(motion: motion))
    }
    var body: some View {
        PhaseContainerView(content: PhaseContent.content(for: .mipit), session: model.session, journey: journey,
            start: start, replay: start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance, suspend: model.suspend,
            usesContextCards: false,
            mipitHarvested: model.harvested,
            surface: { MipitActivitySurface(model: model)
                .disabled(showsHelp).allowsHitTesting(!showsHelp).accessibilityHidden(showsHelp) }, activity: { MipitActivityView(model: model, showsHelp: $showsHelp) },
            description: { MipitDescriptionView() })
    }
    private func start() {
        showsHelp = true
        model.start()
    }
}
