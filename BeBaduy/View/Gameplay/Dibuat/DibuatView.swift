import SwiftUI
struct DibuatView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var chapterVisible = false
    @State private var model: DibuatViewModel
    init(journey: JourneyViewModel, motion: any MotionProviding, advance: @escaping () -> Void) {
        self.journey = journey; self.advance = advance
        _model = State(initialValue: DibuatViewModel(motion: motion))
    }
    var body: some View {
        PhaseContainerView(content: DibuatContent.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance, suspend: model.suspend,
            activityVisibility: { if $0 { model.resume() } else { model.suspend() } },
            usesActivitySheet: false,
            surface: { DibuatActivitySurface(model: model) }, activity: { DibuatActivityView(model: model) },
            description: { DibuatDescriptionView() })
            .background {
                HarvestOrientation(allowsLandscape: chapterVisible && model.allowsLandscape && model.session.isActive,
                    returnToPortrait: model.step == .awaitingPortrait,
                    onChange: model.orientationChanged)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            .onAppear { chapterVisible = true }
            .onDisappear { chapterVisible = false }
    }
}
