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
    private var canScrollUp: Bool { preview.canMove(direction: -1, journey: journey.progress) }
    private var canScrollDown: Bool { preview.canMove(direction: 1, journey: journey.progress) }

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
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(stageSwipe)
                        .accessibilityHidden(true)
                    VStack(spacing: 0) {
                        stageCard
                            .frame(maxWidth: 440)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .gesture(stageSwipe)
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
                if isActive && !openingChapter && (canScrollUp || canScrollDown) {
                    scrollCueButtons(viewport: viewport)
                        .ignoresSafeArea()
                }
                if isActive && !openingChapter {
                    VStack {
                        HStack {
                            Button(action: onJourney) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(width: 42, height: 42)
                                    .background(.black.opacity(0.30), in: Circle())
                                    .overlay(Circle().strokeBorder(ivory.opacity(0.45), lineWidth: 0.7))
                            }
                            .accessibilityLabel("Perjalanan Ngahuma")
                            .accessibilityIdentifier("home.journey")
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.top, 8)
                }
            }
        }
        .foregroundStyle(ivory)
        .tint(gold)
        .preferredColorScheme(.dark)
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
               GrowthStage.allStages.indices.contains(index),
               GrowthStage.allStages[index].isAvailable(in: journey.progress) {
                preview.selectStage(index, journey: journey.progress, reduceMotion: true)
                displayedStage = index
                scheduleScrollCue()
                return
            }
            #endif
            if let stage = GrowthStage.allStages.first(where: { $0.phase == journey.progress.currentPhase }) {
                preview.selectStage(stage.id, journey: journey.progress, reduceMotion: true)
                displayedStage = stage.id
            }
            scheduleScrollCue()
        }
        .onChange(of: journey.progress.currentPhase) { previous, phase in
            guard pendingTransitionFrom == nil, !preview.isPlayingHarvestTransition else { return }
            if let saved = GrowthStage.allStages.first(where: { $0.phase == phase }) {
                let shouldGrow = previous == .ngaseuk && phase == .ngored
                preview.selectStage(saved.id, journey: journey.progress, reduceMotion: reduceMotion || !shouldGrow)
                if !preview.isTransitioning { displayedStage = saved.id }
            }
        }
        .onChange(of: canScrollDown) { _, _ in scheduleScrollCue() }
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

    private func scrollCueButtons(viewport: GeometryProxy) -> some View {
        let cueWidth = min(220, viewport.size.width * 0.56)
        return VStack(spacing: 0) {
            if canScrollUp {
                Button {
                    moveStage(direction: -1)
                } label: {
                    Color.clear
                        .frame(width: cueWidth, height: 82)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tahap sebelumnya")
                .accessibilityIdentifier("home.stage.previous")
                .padding(.top, max(54, viewport.safeAreaInsets.top + 4))
            }
            Spacer(minLength: 0)
            if canScrollDown {
                Button {
                    moveStage(direction: 1)
                } label: {
                    Color.clear
                        .frame(width: cueWidth, height: 76)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tahap berikutnya")
                .accessibilityIdentifier("home.stage.next")
                .padding(.bottom, max(20, viewport.safeAreaInsets.bottom))
            }
        }
        .frame(maxWidth: .infinity)
    }

    @discardableResult
    private func playPendingStageTransition() -> Bool {
        guard let from = pendingTransitionFrom, scenePhase == .active else { return false }
        pendingTransitionFrom = nil
        let stages = GrowthStage.allStages
        guard stages.indices.contains(from), from < stages.count - 1,
              stages[from].isAvailable(in: journey.progress),
              stages[from + 1].isAvailable(in: journey.progress) else { return false }
        preview.selectStage(from, journey: journey.progress, reduceMotion: true)
        displayedStage = from
        preview.selectStage(from + 1, journey: journey.progress, reduceMotion: reduceMotion)
        if !preview.isTransitioning { displayedStage = from + 1 }
        return true
    }

    private var stageCard: some View {
        VStack(spacing: 8) {
            Text(stage.name)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .fontWidth(.condensed)
                .tracking(1)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(gold)
                .shadow(color: .black.opacity(0.78), radius: 10, y: 3)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home.stage.title")
                .accessibilityActions {
                    if isActive && !openingChapter && canScrollDown {
                        Button("Tahap berikutnya") { moveStage(direction: 1) }
                    }
                    if isActive && !openingChapter && canScrollUp {
                        Button("Tahap sebelumnya") { moveStage(direction: -1) }
                    }
                }
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
            Text(stage.isConclusion ? "Lihat Rangkuman" : "Ikut \(PhaseContent.content(for: stage.phase).title)")
                .font(.body)
                .foregroundStyle(ivory)
                .padding(.horizontal, 28)
                .frame(minHeight: 44)
                .background(Color(red: 0.30, green: 0.23, blue: 0.17).opacity(0.9), in: Capsule())
                .overlay(Capsule().strokeBorder(Color(red: 0.77, green: 0.63, blue: 0.43), lineWidth: 0.75))
        }
        .accessibilityIdentifier("resume")
        .fixedSize(horizontal: false, vertical: true)
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
                moveStage(direction: value.translation.height < 0 ? 1 : -1)
            }
    }

    private func moveStage(direction: Int) {
        guard isActive, !openingChapter,
              preview.canMove(direction: direction, journey: journey.progress) else { return }
        cancelScrollCue()
        preview.swipe(direction: direction, journey: journey.progress, reduceMotion: reduceMotion)
    }

    private func openSelectedChapter() {
        guard isActive, !openingChapter, !preview.isTransitioning,
              stage.isAvailable(in: journey.progress) else { return }
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
            let pulseScale = reduceMotion ? CGFloat(1) : ScrollCueMotion.scale(elapsed: elapsed)
            ZStack {
                if showsDown {
                    LightCueField(pointsUp: false)
                        .scaleEffect(y: pulseScale, anchor: .bottom)
                        .opacity(cueAmount)
                }
                if showsUp {
                    LightCueField(pointsUp: true)
                        .scaleEffect(y: pulseScale, anchor: .top)
                        .opacity(cueAmount)
                }

                Canvas { context, size in
                    guard cueAmount > 0, showsUp else { return }
                    let positionAmount = reduceMotion ? CGFloat(1) : CGFloat(cueAmount)
                    let cueHeight = min(155, size.height * 0.19)
                    let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

                    for index in 0..<28 {
                        // Gather rising sky particles into the top scroll cue.
                        let slot = index
                        let lastSlot = 27
                        let seed = Double(index)
                        let t = CGFloat(slot) / CGFloat(lastSlot)
                        let speed = 0.04 + seed.truncatingRemainder(dividingBy: 5) * 0.012
                        let cycle = (time * speed + seed * 0.15).truncatingRemainder(dividingBy: 1)
                        let sourceY = size.height * CGFloat(1 - cycle)
                        let sourceX = size.width * CGFloat((seed * 17).truncatingRemainder(dividingBy: 100) / 100)
                            + CGFloat(sin(time * 0.8 + seed * 2) * 18)
                        let targetX = size.width * (0.25 + 0.50 * t)
                        let curve = sin(t * .pi)
                        let edgeDistance = cueHeight * (0.78 - 0.34 * curve)
                        let targetY = edgeDistance + CGFloat((index * 11) % 7 - 3) * 1.3
                        let x = sourceX + (targetX - sourceX) * positionAmount
                        let y = sourceY + (targetY - sourceY) * positionAmount
                        let blend = cueAmount * (1 - Double(positionAmount))
                        let coreRadius = 1.2 + CGFloat(index % 3) * 0.8
                        let haloRadius = coreRadius * (3.2 + positionAmount * 3.0)
                        let yellowMix = Double(positionAmount)
                        let haloColor = Color(red: 1.0, green: 1.0 - 0.14 * yellowMix, blue: 1.0 - 0.58 * yellowMix)
                        let coreColor = Color(red: 1.0, green: 1.0 - 0.08 * yellowMix, blue: 1.0 - 0.42 * yellowMix)

                        context.fill(
                            Path(ellipseIn: CGRect(x: x - haloRadius, y: y - haloRadius,
                                                   width: haloRadius * 2, height: haloRadius * 2)),
                            with: .radialGradient(
                                Gradient(colors: [haloColor.opacity(blend * 0.38), .clear]),
                                center: CGPoint(x: x, y: y),
                                startRadius: 0,
                                endRadius: haloRadius
                            )
                        )
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - coreRadius, y: y - coreRadius,
                                                   width: coreRadius * 2, height: coreRadius * 2)),
                            with: .color(coreColor.opacity(blend * 0.72))
                        )
                    }
                }
            }
        }
    }
}

private struct LightCueField: View {
    let pointsUp: Bool

    var body: some View {
        let light = pointsUp ? Color(red: 1, green: 0.88, blue: 0.56) : Color(red: 0.62, green: 0.44, blue: 0.27)
        let strength = 1.45
        let verticalStops: [Gradient.Stop] = pointsUp
            ? [
                .init(color: .clear, location: 0.78),
                .init(color: light.opacity(0.24 * strength), location: 0.84),
                .init(color: light.opacity(0.38 * strength), location: 0.88),
                .init(color: light.opacity(0.22 * strength), location: 0.915),
                .init(color: .clear, location: 0.942)
            ]
            : [
                .init(color: .clear, location: 0.80),
                .init(color: light.opacity(0.24 * strength), location: 0.87),
                .init(color: light.opacity(0.38 * strength), location: 0.91),
                .init(color: light.opacity(0.22 * strength), location: 0.945),
                .init(color: .clear, location: 0.972)
            ]
        LinearGradient(
            stops: verticalStops,
            startPoint: .top,
            endPoint: .bottom
        )
        .mask {
            ZStack {
                LightBowlShape(pointsUp: pointsUp)
                    .fill(.white)
                    .blur(radius: 10)
                LightChevronGap(pointsUp: pointsUp)
                    .stroke(.white, style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                    .blur(radius: 5)
                    .opacity(0.78)
                    .offset(y: pointsUp ? -2 : 2)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.22),
                    .init(color: .white.opacity(0.25), location: 0.29),
                    .init(color: .white.opacity(0.72), location: 0.36),
                    .init(color: .white, location: 0.44),
                    .init(color: .white, location: 0.56),
                    .init(color: .white.opacity(0.72), location: 0.64),
                    .init(color: .white.opacity(0.25), location: 0.71),
                    .init(color: .clear, location: 0.78)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .opacity(0.92)
        .scaleEffect(y: pointsUp ? -1 : 1)
    }
}

/// A transparent cut through the centered light field, revealing the landscape beneath.
private struct LightChevronGap: Shape {
    let pointsUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let halfSpan = min(105, rect.width * 0.25)
        let leftX = rect.midX - halfSpan
        let rightX = rect.midX + halfSpan
        let edgeY = rect.height * (pointsUp ? 0.848 : 0.888)
        let centerY = edgeY + rect.height * 0.044
        path.move(to: CGPoint(x: leftX, y: edgeY))
        path.addLine(to: CGPoint(x: rect.midX, y: centerY))
        path.addLine(to: CGPoint(x: rightX, y: edgeY))
        return path
    }
}

private struct LightBowlShape: Shape {
    let pointsUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let halfSpan = min(105, width * 0.25)
        let leftX = rect.midX - halfSpan
        let rightX = rect.midX + halfSpan
        let edgeY = height * (pointsUp ? 0.815 : 0.855)
        let centerY = edgeY + height * 0.044
        let bandHeight = height * 0.064
        path.move(to: CGPoint(x: leftX, y: edgeY))
        path.addLine(to: CGPoint(x: rect.midX, y: centerY))
        path.addLine(to: CGPoint(x: rightX, y: edgeY))
        path.addLine(to: CGPoint(x: rightX, y: edgeY + bandHeight))
        path.addLine(to: CGPoint(x: rect.midX, y: centerY + bandHeight))
        path.addLine(to: CGPoint(x: leftX, y: edgeY + bandHeight))
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
