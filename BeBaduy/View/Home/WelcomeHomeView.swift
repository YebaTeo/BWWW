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
                CinematicSpeedLinesOverlay(
                    progress: progress,
                    isScrolling: preview.isTransitioning && (
                        (displayedStage < 5 && selectedStage < 5) ||
                        (displayedStage == 5 && selectedStage == 6) ||
                        (displayedStage == 6 && selectedStage == 5)
                    )
                )
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
            #if DEBUG
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--preview-stage=") }),
               let index = Int(argument.dropFirst("--preview-stage=".count)),
               GrowthStage.allStages.indices.contains(index) {
                preview.selectStage(index, reduceMotion: true)
                displayedStage = index
                return
            }
            #endif
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
            Text(stage.isConclusion ? "Lihat Rangkuman" : "Mulai Tahapan")
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
        if stage.isConclusion {
            onCompletion()
        } else {
            onOpen(journey.progress.isUnlocked(stage.phase) ? stage.phase : journey.progress.currentPhase)
        }
    }

}

/// High-motion-blur speed lines effect rendering dynamic horizontal streaks during the whip-pan to Leuit.
private struct CinematicSpeedLinesOverlay: View {
    let progress: CGFloat
    let isScrolling: Bool

    var body: some View {
        let panT = min(1.0, max(0.0, (progress - 0.932) / (0.985 - 0.932)))
        let velocity = sin(panT * .pi)

        if isScrolling && velocity > 0.01 {
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // 1. Broad horizontal motion blur smears (soft whoosh bands rushing across)
                for j in 0..<5 {
                    let seedJ = Double(j) * 2.17
                    let smearY = h * CGFloat(0.18 + fmod(seedJ * 0.28, 0.64))
                    let smearH = CGFloat(24 + j * 14)
                    let smearX = (CGFloat(panT * 2.2) - 1.1) * w * 0.5
                    let smearRect = CGRect(x: smearX, y: smearY - smearH * 0.5, width: w * 1.3, height: smearH)
                    let smearColor = Color(red: 1.0, green: 0.94, blue: 0.82, opacity: 0.12 * velocity)
                    context.fill(Path(smearRect), with: .color(smearColor))
                }

                // 2. 48 Sharp, high-speed streaming horizontal streaks (garis-garis kecepatan melesat cepat)
                for i in 0..<48 {
                    let seed = Double(i) * 1.6180339
                    let y = h * CGFloat(fmod(seed * 7.31, 0.90) + 0.05)
                    let lineW = w * CGFloat(0.24 + fmod(seed * 3.14, 0.52)) * (0.90 + 0.40 * velocity)
                    // Streaks fly rapidly from right to left across screen
                    let rawX = fmod(seed * 5.73 - Double(panT) * 4.5 * (1.0 + fmod(seed, 0.5)), 1.0)
                    let normX = (rawX < 0 ? rawX + 1.0 : rawX)
                    let x = CGFloat(normX) * w - lineW * 0.5
                    let alpha = Double(0.28 + fmod(seed * 2.91, 0.45)) * velocity
                    let lineThickness: CGFloat = (i % 4 == 0) ? 2.6 : ((i % 2 == 0) ? 1.6 : 0.9)

                    let rect = CGRect(
                        x: x,
                        y: y - lineThickness * 0.5,
                        width: lineW,
                        height: lineThickness
                    )
                    let color = Color(
                        red: 1.0,
                        green: 0.93 + 0.07 * sin(seed),
                        blue: 0.76 + 0.20 * cos(seed),
                        opacity: alpha
                    )
                    context.fill(Path(roundedRect: rect, cornerRadius: lineThickness * 0.5), with: .color(color))
                }
            }
            .allowsHitTesting(false)
            .opacity(velocity)
            .blendMode(.screen)
        }
    }
}
