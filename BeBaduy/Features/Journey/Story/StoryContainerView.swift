import SwiftUI

private struct StoryLayout: Equatable {
    var frames: [StorySectionID: CGRect] = [:]
    var origin: CGFloat?
}
private struct StoryFramesKey: PreferenceKey {
    static let defaultValue = StoryLayout()
    static func reduce(value: inout StoryLayout, nextValue: () -> StoryLayout) {
        let next = nextValue()
        value.frames.merge(next.frames, uniquingKeysWith: { _, new in new })
        if let origin = next.origin { value.origin = origin }
    }
}

/// Page at ordinary text sizes; retain readable overflow for accessibility text.
struct StorySnapBehavior: ScrollTargetBehavior {
    let enabled: Bool
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard enabled else { return }
        PagingScrollTargetBehavior().updateTarget(&target, context: context)
        target.rect.origin.y = Self.singlePageOffset(
            proposed: target.rect.minY, start: context.originalTarget.rect.minY,
            height: context.containerSize.height, contentHeight: context.contentSize.height)
    }

    // Native paging can skip several screens on a fast flick. Bound its destination
    // to the pages adjacent to the page where this gesture began.
    static func singlePageOffset(proposed: CGFloat, start: CGFloat,
                                 height: CGFloat, contentHeight: CGFloat) -> CGFloat {
        guard height > 0 else { return 0 }
        let last = max(0, ceil(contentHeight / height) - 1)
        let current = min(last, max(0, (start / height).rounded()))
        let requested = (proposed / height).rounded()
        let next = min(last, max(0, min(current + 1, max(current - 1, requested))))
        return next * height
    }
}

struct StoryContainerView<Section: View>: View {
    let model: StoryJourneyViewModel
    @ViewBuilder let section: (StorySectionID) -> Section
    @State private var readingAnchor: StorySectionID?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.sections) { id in
                        section(id)
                            .padding(.horizontal, 24)
                            .padding(.top, geometry.safeAreaInsets.top + 20)
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: geometry.size.height, maxHeight: typeSize.isAccessibilitySize ? nil : geometry.size.height)
                            .background { background(for: id) }
                            .foregroundStyle(.white)
                            .tint(.white)
                            .background {
                                GeometryReader { sectionGeometry in
                                    Color.clear.preference(key: StoryFramesKey.self,
                                        value: StoryLayout(frames: [id: sectionGeometry.frame(in: .named("storyViewport"))]))
                                }
                            }
                            .id(id)
                    }
                }
                .scrollTargetLayout()
                .background {
                    GeometryReader { stackGeometry in
                        Color.clear.preference(key: StoryFramesKey.self,
                            value: StoryLayout(origin: stackGeometry.frame(in: .named("storyViewport")).minY))
                    }
                }
            }
            .scrollPosition(id: $readingAnchor)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(StorySnapBehavior(enabled: !typeSize.isAccessibilitySize))
            .onPreferenceChange(StoryFramesKey.self) { layout in
                model.updateVisibility(frames: layout.frames, viewport: CGRect(origin: .zero, size: geometry.size))
            }
        }
        .ignoresSafeArea()
        .coordinateSpace(name: "storyViewport")
        .background(AppTheme.background)
        .onChange(of: model.ngaseuk.session.event) { _, _ in model.acceptOutcome() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.suspend() } }
        .onDisappear { model.setActivityVisible(false) }
    }
    private func background(for id: StorySectionID) -> some View {
        let state: LandscapeState = switch id {
        case .ngaseukIntroduction, .ngaseukActivity: NgaseukContent.value.before
        case .ngaseukExplanation: NgaseukContent.value.after
        case .ngoredIntroduction: NgoredContent.value.before
        }
        return GeometryReader { page in
            Image(state.assetName)
                .resizable().scaledToFill()
                .frame(width: page.size.width, height: page.size.height)
                .clipped()
                .overlay {
                    LinearGradient(colors: [.black.opacity(0.22), .black.opacity(0.55), .black.opacity(0.82)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
    }

}
