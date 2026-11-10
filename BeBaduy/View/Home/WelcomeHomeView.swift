import SwiftUI

/// Full-screen stage preview with a minimal title, narrative, and primary action.
struct WelcomeHomeView: View {
    let journey: JourneyViewModel
    let onOpen: (PhaseID) -> Void
    let onJourney: () -> Void
    let onCompletion: () -> Void
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    private var largeText: Bool { typeSize.isAccessibilitySize }
    @State private var preview = HomePreviewViewModel()
    @State private var initializedPreview = false
    @State private var openingChapter = false
    @State private var displayedStage = 0
    private var progress: CGFloat { preview.progress }
    private var selectedStage: Int { preview.selectedStage }

    private let ivory = Color(red: 0.99, green: 0.97, blue: 0.92)
    private let gold = Color(red: 1, green: 0.62, blue: 0.14)
    private var stage: GrowthStage { GrowthStage.allStages[displayedStage] }

    var body: some View {
        GeometryReader { viewport in
            ZStack {
                CinematicAtmosphereView(progress: progress, isActive: isActive)
                    .accessibilityHidden(true)
                SceneKitCropView(progress: progress, isActive: isActive)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(stageSwipe)
                        .accessibilityHidden(true)
                    VStack(spacing: 0) {
                        ScrollView {
                            stageCard
                                .frame(maxWidth: 440)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxHeight: viewport.size.height * (largeText ? 0.42 : 0.23))
                        actions
                            .frame(maxWidth: 440)
                    }
                    .opacity(preview.isTransitioning ? 0 : 1)
                    .offset(y: preview.isTransitioning && !reduceMotion ? 48 : 0)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: preview.isTransitioning ? 0.2 : 0.35),
                        value: preview.isTransitioning
                    )
                    .allowsHitTesting(!preview.isTransitioning)
                    .accessibilityHidden(preview.isTransitioning)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, viewport.size.height * 0.09)
            }
        }
        .foregroundStyle(ivory)
        .tint(gold)
        .preferredColorScheme(.dark)
        .accessibilityAction(named: "Tahap berikutnya") {
            preview.swipe(direction: 1, reduceMotion: reduceMotion)
        }
        .accessibilityAction(named: "Tahap sebelumnya") {
            preview.swipe(direction: -1, reduceMotion: reduceMotion)
        }
        .onChange(of: selectedStage) { _, index in
            if !preview.isTransitioning { displayedStage = index }
        }
        .onChange(of: preview.isTransitioning) { _, transitioning in
            if !transitioning { displayedStage = selectedStage }
        }
        .sensoryFeedback(.selection, trigger: selectedStage)
        .onChange(of: reduceMotion) { _, enabled in if enabled { preview.stop() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { preview.stop() } }
        .onAppear {
            guard !initializedPreview else { return }
            initializedPreview = true
            if let stage = GrowthStage.allStages.first(where: { $0.phase == journey.progress.currentPhase }) {
                preview.selectStage(stage.id, reduceMotion: true)
            }
        }
        .onChange(of: journey.progress.currentPhase) { _, phase in
            if let saved = GrowthStage.allStages.first(where: { $0.phase == phase }) {
                preview.selectStage(saved.id, reduceMotion: true)
            }
        }
        .onDisappear {
            preview.stop()
        }
        .onChange(of: isActive) { _, active in
            if !active {
                preview.stop()
            } else {
                openingChapter = false
            }
        }
    }

    private var stageCard: some View {
        VStack(spacing: 8) {
            Text(stage.name)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .fontWidth(.condensed)
                .tracking(1)
                .foregroundStyle(gold)
                .shadow(color: .black.opacity(0.78), radius: 10, y: 3)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home.stage.title")
            Text(stage.narrative)
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.9), radius: 7, y: 2)
            if let message = journey.storageMessage {
                Text(message)
                    .font(.footnote)
                    .shadow(color: .black.opacity(0.9), radius: 7, y: 2)
            }

        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
    }

    private var actions: some View {
        Button(action: openSelectedChapter) {
            Text("Mulai Tahapan")
                .font(.body)
                .foregroundStyle(ivory)
                .padding(.horizontal, 28)
                .frame(minHeight: 44)
                .background(Color(red: 0.30, green: 0.23, blue: 0.17).opacity(0.9), in: Capsule())
                .overlay(Capsule().strokeBorder(Color(red: 0.77, green: 0.63, blue: 0.43), lineWidth: 0.75))
        }
        .accessibilityIdentifier("resume")
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    private var stageSwipe: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                guard abs(value.translation.height) > 45,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                if value.translation.height < 0 {
                    preview.swipe(direction: 1, reduceMotion: reduceMotion)
                } else {
                    preview.swipe(direction: -1, reduceMotion: reduceMotion)
                }
            }
    }

    private func openSelectedChapter() {
        guard isActive, !openingChapter, !preview.isTransitioning else { return }
        openingChapter = true
        preview.stop()
        onOpen(journey.progress.isUnlocked(stage.phase) ? stage.phase : journey.progress.currentPhase)
    }


}
