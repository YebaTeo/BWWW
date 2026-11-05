import SwiftUI

/// Isolated development entry: the normal eleven-phase journey stays operational.
struct StoryPilotView: View {
    @State private var model: StoryJourneyViewModel
    private let previewReduceMotion: Bool
    init(motion: any MotionProviding, previewReduceMotion: Bool = false) {
        self.previewReduceMotion = previewReduceMotion
        _model = State(initialValue: StoryJourneyViewModel(
            journey: JourneyViewModel(store: StoryPreviewStore()), motion: motion))
    }
    var body: some View {
        NavigationStack {
            StoryContainerView(model: model) { id in
                switch id {
                case .ngaseukIntroduction: NgaseukIntroductionView(story: true)
                case .ngaseukActivity:
                    NgaseukStoryActivityView(model: model.ngaseuk, unlocked: model.unlocked,
                        plant: model.plant, motion: model.startMotion, demonstrate: model.demonstrate, replay: model.replay)
                case .ngaseukExplanation: NgaseukDescriptionView(story: true)
                case .ngoredIntroduction: NgoredIntroductionView(story: true)
                }
            }
            .environment(\.storyPreviewReduceMotion, previewReduceMotion)
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
        }.tint(AppTheme.leaf)
    }
}

#Preview("Cerita huma · pilot terisolasi") {
    StoryPilotView(motion: MotionService())
}

#Preview("Cerita huma · Reduce Motion") {
    StoryPilotView(motion: MotionService(), previewReduceMotion: true)
}

struct StoryScrollCue: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "chevron.up").font(.subheadline).foregroundStyle(.white.opacity(0.85))
            .padding(.top, 16).frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore).accessibilityLabel(text)
    }
}

// SwiftUI's system Reduce Motion environment is read-only. This extra value is
// only a deterministic preview override; consumers always OR it with the real setting.
private struct StoryPreviewReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var storyPreviewReduceMotion: Bool {
        get { self[StoryPreviewReduceMotionKey.self] }
        set { self[StoryPreviewReduceMotionKey.self] = newValue }
    }
}
