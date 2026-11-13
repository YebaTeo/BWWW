import SwiftUI

/// Full-screen stage preview with a minimal title, narrative, and primary action.
struct WelcomeHomeView: View {
    let journey: JourneyViewModel
    var onFirstFrame: (() -> Void)? = nil
    @Binding var pendingTransitionFrom: Int?
    let onOpen: (PhaseID) -> Void
    let onJourney: () -> Void
    let onCompletion: () -> Void
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var preview = HomePreviewViewModel()
    @State private var initializedPreview = false
    @State private var openingChapter = false
    @State private var displayedStage = 0
    @State private var scrollCueStart: Date?
    @State private var scrollCueTask: Task<Void, Never>?
    private var progress: CGFloat { preview.progress }
    private var selectedStage: Int { preview.selectedStage }
    private var canScrollUp: Bool { selectedStage > 0 }
    private var canScrollDown: Bool { selectedStage < GrowthStage.allStages.count - 1 }

    private let ivory = Color(red: 0.99, green: 0.97, blue: 0.92)
    private let gold = Color(red: 1, green: 0.62, blue: 0.14)
    private var stage: GrowthStage { GrowthStage.allStages[displayedStage] }

    var body: some View {
        GeometryReader { viewport in
            ZStack {
                CinematicAtmosphereView(progress: progress, isActive: isActive, scrollCueStart: scrollCueStart)
                    .accessibilityHidden(true)
                SceneKitCropView(progress: progress, isActive: isActive, onFirstFrame: onFirstFrame)
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
                if let scrollCueStart {
                    LightScrollCue(
                        startDate: scrollCueStart,
                        reduceMotion: reduceMotion,
                        showsUp: canScrollUp,
                        showsDown: canScrollDown
                    )
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: 0) {
                        stageCard
                            .frame(maxWidth: 440)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .simultaneousGesture(stageSwipe)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, viewport.size.height * 0.09)
                if scrollCueStart != nil {
                    VStack(spacing: 0) {
                        if canScrollUp {
                            Button {
                                cancelScrollCue()
                                preview.swipe(direction: -1, reduceMotion: reduceMotion)
                            } label: {
                                Color.clear
                                    .frame(height: min(70, viewport.size.height * 0.085))
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Tahap sebelumnya")
                            .padding(.top, max(44, viewport.safeAreaInsets.top + 8))
                        }
                        Spacer(minLength: 0)
                        if canScrollDown {
                            Button {
                                cancelScrollCue()
                                preview.swipe(direction: 1, reduceMotion: reduceMotion)
                            } label: {
                                Color.clear
                                    .frame(height: min(70, viewport.size.height * 0.085))
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Tahap berikutnya")
                            .padding(.bottom, max(4, viewport.safeAreaInsets.bottom))
                        }
                    }
                }
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
            scheduleScrollCue()
        }
        .onChange(of: preview.isTransitioning) { _, transitioning in
            if !transitioning { displayedStage = selectedStage }
            scheduleScrollCue()
        }
        .sensoryFeedback(.selection, trigger: selectedStage)
        .onChange(of: reduceMotion) { _, enabled in
            if enabled { preview.stop() }
            scheduleScrollCue()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { preview.stop() }
            else if isActive { playPendingStageTransition() }
            scheduleScrollCue()
        }
        .onAppear {
            if isActive && playPendingStageTransition() {
                initializedPreview = true
                scheduleScrollCue()
                return
            }
            guard !initializedPreview else {
                scheduleScrollCue()
                return
            }
            initializedPreview = true
            #if DEBUG
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--preview-stage=") }),
               let index = Int(argument.dropFirst("--preview-stage=".count)),
               GrowthStage.allStages.indices.contains(index) {
                preview.selectStage(index, reduceMotion: true)
                displayedStage = index
                scheduleScrollCue()
                return
            }
            #endif
            if let stage = GrowthStage.allStages.first(where: { $0.phase == journey.progress.currentPhase }) {
                preview.selectStage(stage.id, reduceMotion: true)
                displayedStage = stage.id
            }
            scheduleScrollCue()
        }
        .onChange(of: journey.progress.currentPhase) { previous, phase in
            guard pendingTransitionFrom == nil, !preview.isPlayingHarvestTransition else { return }
            if let saved = GrowthStage.allStages.first(where: { $0.phase == phase }) {
                let shouldGrow = previous == .ngaseuk && phase == .ngored
                preview.selectStage(saved.id, reduceMotion: reduceMotion || !shouldGrow)
                if !preview.isTransitioning { displayedStage = saved.id }
            }
        }
        .onDisappear {
            preview.stop()
            cancelScrollCue()
        }
        .onChange(of: isActive) { _, active in
            if !active {
                preview.stop()
            } else {
                openingChapter = false
                playPendingStageTransition()
            }
            scheduleScrollCue()
        }
    }

    @discardableResult
    private func playPendingStageTransition() -> Bool {
        guard let from = pendingTransitionFrom,
              GrowthStage.allStages.indices.contains(from),
              from + 1 < GrowthStage.allStages.count,
              scenePhase == .active else { return false }
        pendingTransitionFrom = nil
        preview.selectStage(from, reduceMotion: true)
        displayedStage = from
        preview.selectStage(from + 1, reduceMotion: reduceMotion)
        if !preview.isTransitioning { displayedStage = from + 1 }
        return true
    }

    private var stageCard: some View {
        VStack(spacing: 8) {
            Text(stage.isConclusion ? "MENGELOLA PARE\nHUMA" : stage.name)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .fontWidth(.condensed)
                .tracking(1)
                .lineLimit(stage.isConclusion ? 2 : 1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(gold)
                .shadow(color: .black.opacity(0.78), radius: 10, y: 3)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(stage.name)
                .accessibilityIdentifier("home.stage.title")
            Text(stage.narrative)
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.9), radius: 7, y: 2)
            if let message = journey.storageMessage {
                Text(message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.9), radius: 7, y: 2)
            }

        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
    }

    private var actions: some View {
        Button(action: openSelectedChapter) {
            Text(stage.isConclusion ? "Lihat Rangkuman" : "Ikut \(PhaseContent.content(for: stage.phase).title)")
                .font(.body)
                .foregroundStyle(ivory)
                .padding(.horizontal, 28)
                .frame(minHeight: 44)
                .background(Color(red: 0.30, green: 0.23, blue: 0.17).opacity(0.9), in: Capsule())
                .overlay(Capsule().strokeBorder(Color(red: 0.77, green: 0.63, blue: 0.43), lineWidth: 0.75))
        }
        .accessibilityIdentifier("resume")
        .disabled(!isActive || openingChapter)
        .accessibilityHidden(!isActive || openingChapter)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    private var stageSwipe: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { _ in cancelScrollCue() }
            .onEnded { value in
                defer { scheduleScrollCue() }
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
        cancelScrollCue()
        openingChapter = true
        preview.stop()
        if stage.isConclusion {
            onCompletion()
        } else {
            onOpen(stage.phase)
        }
    }

    private func cancelScrollCue() {
        scrollCueTask?.cancel()
        scrollCueTask = nil
        scrollCueStart = nil
    }

    private func scheduleScrollCue() {
        cancelScrollCue()
        guard isActive, scenePhase == .active, !openingChapter,
              !preview.isTransitioning,
              (canScrollUp || canScrollDown) else { return }
        scrollCueTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard !Task.isCancelled, isActive, !preview.isTransitioning else { return }
            scrollCueStart = .now
            do { try await Task.sleep(for: .seconds(ScrollCueMotion.duration)) } catch { return }
            guard !Task.isCancelled else { return }
            scrollCueStart = nil
            scrollCueTask = nil
        }
    }

}

/// The Home's rising light orbs gather into soft cues at the available scroll edges.
private struct LightScrollCue: View {
    let startDate: Date
    let reduceMotion: Bool
    let showsUp: Bool
    let showsDown: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(startDate))
            let cueAmount = ScrollCueMotion.amount(elapsed: elapsed)
            ZStack {
                if showsDown {
                    LightCueField(pointsUp: false)
                        .opacity(cueAmount)
                }
                if showsUp {
                    LightCueField(pointsUp: true)
                        .opacity(cueAmount)
                }

                Canvas { context, size in
                    guard cueAmount > 0 else { return }
                    let positionAmount = reduceMotion ? CGFloat(1) : CGFloat(cueAmount)
                    let cueHeight = min(155, size.height * 0.19)
                    let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

                    for index in 0..<28 {
                        // Reuse the rising orbs, then let each one dissolve into the white field.
                        let pointsUp = showsUp && (!showsDown || index.isMultiple(of: 2))
                        let slot = showsUp && showsDown ? index / 2 : index
                        let lastSlot = showsUp && showsDown ? 13 : 27
                        let seed = Double(index)
                        let speed = 0.04 + seed.truncatingRemainder(dividingBy: 5) * 0.012
                        let cycle = (time * speed + seed * 0.15).truncatingRemainder(dividingBy: 1)
                        let sourceY = size.height * CGFloat(1 - cycle)
                        let sourceX = size.width * CGFloat((seed * 17).truncatingRemainder(dividingBy: 100) / 100)
                            + CGFloat(sin(time * 0.8 + seed * 2) * 18)
                        let t = CGFloat(slot) / CGFloat(lastSlot)
                        let targetX = size.width * (0.015 + 0.97 * t)
                        let curve = sin(t * .pi)
                        let edgeDistance = cueHeight * (0.94 - 0.82 * curve)
                        let targetY = (pointsUp ? edgeDistance : size.height - edgeDistance)
                            + CGFloat((index * 11) % 7 - 3) * 1.3
                        let x = sourceX + (targetX - sourceX) * positionAmount
                        let y = sourceY + (targetY - sourceY) * positionAmount
                        let blend = cueAmount * (1 - Double(positionAmount))
                        let coreRadius = 1.2 + CGFloat(index % 3) * 0.8
                        let haloRadius = coreRadius * (3.2 + positionAmount * 3.0)
                        let haloColor = pointsUp
                            ? Color(red: 1, green: 0.86, blue: 0.52)
                            : Color.white
                        let coreColor = pointsUp
                            ? Color(red: 1, green: 0.96, blue: 0.76)
                            : Color.white

                        context.fill(
                            Path(ellipseIn: CGRect(x: x - haloRadius, y: y - haloRadius,
                                                   width: haloRadius * 2, height: haloRadius * 2)),
                            with: .radialGradient(
                                Gradient(colors: [haloColor.opacity(blend * 0.26), .clear]),
                                center: CGPoint(x: x, y: y),
                                startRadius: 0,
                                endRadius: haloRadius
                            )
                        )
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - coreRadius, y: y - coreRadius,
                                                   width: coreRadius * 2, height: coreRadius * 2)),
                            with: .color(coreColor.opacity(blend * 0.52))
                        )
                    }
                }
                .blendMode(.screen)
            }
        }
    }
}

private struct LightCueField: View {
    let pointsUp: Bool

    var body: some View {
        let light = pointsUp ? Color(red: 1, green: 0.88, blue: 0.56) : Color.white
        let strength = pointsUp ? 1.55 : 1.0
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: light.opacity(0.025 * strength), location: 0.38),
                .init(color: light.opacity(0.08 * strength), location: 0.62),
                .init(color: light.opacity(0.17 * strength), location: 0.82),
                .init(color: light.opacity(0.26 * strength), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .mask {
            LightBowlShape()
                .fill(.white)
                .blur(radius: 30)
        }
        .scaleEffect(y: pointsUp ? -1 : 1)
    }
}

private struct LightBowlShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        path.move(to: CGPoint(x: -40, y: height * 0.79))
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.93),
            control1: CGPoint(x: width * 0.18, y: height * 0.90),
            control2: CGPoint(x: width * 0.36, y: height * 0.94)
        )
        path.addCurve(
            to: CGPoint(x: width + 40, y: height * 0.79),
            control1: CGPoint(x: width * 0.64, y: height * 0.94),
            control2: CGPoint(x: width * 0.82, y: height * 0.90)
        )
        path.addLine(to: CGPoint(x: width + 40, y: height + 40))
        path.addLine(to: CGPoint(x: -40, y: height + 40))
        path.closeSubpath()
        return path
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
