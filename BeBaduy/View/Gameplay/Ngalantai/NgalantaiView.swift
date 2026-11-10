import SwiftUI
struct NgalantaiView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var chapterVisible = false
    @State private var model: NgalantaiViewModel
    init(journey: JourneyViewModel, motion: any MotionProviding, advance: @escaping () -> Void) {
        self.journey = journey; self.advance = advance
        _model = State(initialValue: NgalantaiViewModel(motion: motion))
    }
    var body: some View {
        PhaseContainerView(content: PhaseContent.content(for: .ngalantai), session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: { model.session.restore($0) }, advance: advance, suspend: model.suspend,
            activityVisibility: { if $0 { model.resume() } else { model.suspend() } },
            usesContextCards: false,
            surface: { NgalantaiActivitySurface(model: model) }, activity: { NgalantaiActivityView(model: model) },
            description: { ReflectionText(content: PhaseContent.content(for: .ngalantai)) })
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
