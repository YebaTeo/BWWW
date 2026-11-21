import SwiftUI

enum JourneyIntroCopy {
    static let title = "Perjalanan Ngahuma"
    static let description = "Tradisi berladang masyarakat Baduy yang diwariskan turun-temurun untuk menjaga keseimbangan hidup antara manusia dan alam, melalui rangkaian tahapan yang dilakukan setiap tahun."
}

struct MenuView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 29
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var markerLabelSize: CGFloat = 16
    let journey: JourneyViewModel
    var showsBackground = true
    var isActive = false
    var showsIntroText = true
    var transitionTopInset: CGFloat? = nil
    var landscapeViewportHeight: CGFloat? = nil
    let open: (PhaseID) -> Void
    let onScroll: (CGFloat, CGFloat) -> Void
    @State private var isUserScrolling = false
    @State private var visualOverrideUnlockedUpTo: Int? = nil
    @State private var recoilStageIndex: Int? = nil
    @State private var explosionStartDate: Date? = nil
    @State private var explosionRunID: UUID? = nil
    private var firstStageGap: CGFloat { dynamicTypeSize.isAccessibilitySize ? 185 : 115 }
    private var stageStep: CGFloat { dynamicTypeSize.isAccessibilitySize ? 210 : 145 }

    private func stageY(_ index: Int) -> CGFloat {
        103 + (index == 0 ? 0 : firstStageGap + CGFloat(index - 1) * stageStep)
    }

    var body: some View {
        GeometryReader { viewport in
        ScrollViewReader { scrollProxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let message = journey.storageMessage {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(message).font(.subheadline)
                        Button("Tutup") { journey.dismissStorageMessage() }
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 26)
                    .padding(.bottom, 18)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(JourneyIntroCopy.title)
                        .font(.system(size: titleSize, weight: .bold, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                        .opacity(showsIntroText ? 1 : 0)
                    Text(JourneyIntroCopy.description)
                        .font(.system(size: bodySize, weight: .medium))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(showsIntroText ? 1 : 0)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.65), radius: 5, y: 2)
                .padding(.horizontal, 27)
                .padding(.top, (transitionTopInset ?? viewport.safeAreaInsets.top) + 26)
                .id("menu_top")

                stageMap
            }
            .background { MenuScrollBoundary() }
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
            .background {
                scrollingBackground(viewportHeight: landscapeViewportHeight ?? viewport.size.height + viewport.safeAreaInsets.top)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .onScrollGeometryChange(for: Int.self) { geometry in
            Int((geometry.contentOffset.y + geometry.contentInsets.top) / 12)
        } action: { oldOffset, newOffset in
            guard isUserScrolling else { return }
            onScroll(CGFloat(oldOffset * 12), CGFloat(newOffset * 12))
        }
        .onScrollPhaseChange { _, new, _ in
            isUserScrolling = new == .interacting
        }
        .background {
            if showsBackground {
                Image("JourneySoil")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Color(red: 0.16, green: 0.17, blue: 0.08)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isActive, initial: true) { _, active in
            if active {
                startCycleResetExplosionIfNeeded()
            } else {
                cancelCycleResetExplosion()
            }
        }
        .onChange(of: journey.pendingMenuCycleReset) { _, pending in
            if pending && isActive {
                startCycleResetExplosionIfNeeded()
            }
        }
        .onDisappear {
            cancelCycleResetExplosion()
        }
        .task(id: explosionRunID) {
            guard explosionRunID != nil, isActive else { return }
            await runCycleResetExplosion(scrollProxy: scrollProxy)
        }
        }
        }
    }

    private func startCycleResetExplosionIfNeeded() {
        guard journey.consumePendingMenuCycleReset() else { return }
        visualOverrideUnlockedUpTo = PhaseID.allCases.count - 1
        recoilStageIndex = nil
        explosionStartDate = reduceMotion ? nil : Date()
        explosionRunID = UUID()
    }

    private func cancelCycleResetExplosion() {
        explosionRunID = nil
        explosionStartDate = nil
        recoilStageIndex = nil
        visualOverrideUnlockedUpTo = nil
    }

    private func runCycleResetExplosion(scrollProxy: ScrollViewProxy) async {
        if reduceMotion {
            do { try await Task.sleep(for: .milliseconds(160)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.28)) {
                visualOverrideUnlockedUpTo = nil
                scrollProxy.scrollTo("menu_top", anchor: .top)
            }
            explosionRunID = nil
            return
        }

        let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
        let lightImpact = UIImpactFeedbackGenerator(style: .light)
        mediumImpact.prepare()
        lightImpact.prepare()

        // Let the NavigationStack pop back to MenuView settle before detonating.
        var elapsedMs = 0
        for step in CycleResetSchedule.steps {
            let targetMs = Int((step.detonationTime * 1000).rounded())
            let waitMs = max(0, targetMs - elapsedMs)
            if waitMs > 0 {
                do { try await Task.sleep(for: .milliseconds(waitMs)) } catch { return }
                elapsedMs += waitMs
            }
            guard !Task.isCancelled else { return }

            let stageIdx = step.stageIndex
            if stageIdx == 5 {
                mediumImpact.impactOccurred(intensity: 0.95)
            } else {
                lightImpact.impactOccurred(intensity: 0.78)
            }

            withAnimation(.spring(response: 0.22, dampingFraction: 0.48)) {
                recoilStageIndex = stageIdx
            }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.74)) {
                visualOverrideUnlockedUpTo = stageIdx - 1
            }

            if stageIdx == 4 {
                withAnimation(.easeInOut(duration: 0.64)) {
                    scrollProxy.scrollTo("menu_top", anchor: .top)
                }
            }

            let recoilHoldMs = 75
            do { try await Task.sleep(for: .milliseconds(recoilHoldMs)) } catch { return }
            elapsedMs += recoilHoldMs
            guard !Task.isCancelled else { return }
            if recoilStageIndex == stageIdx {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.70)) {
                    recoilStageIndex = nil
                }
            }
        }

        let remainingMs = max(0, Int((CycleResetSchedule.totalDuration * 1000).rounded()) - elapsedMs)
        if remainingMs > 0 {
            do { try await Task.sleep(for: .milliseconds(remainingMs)) } catch { return }
        }
        guard !Task.isCancelled else { return }
        explosionStartDate = nil
        visualOverrideUnlockedUpTo = nil
        recoilStageIndex = nil
        explosionRunID = nil
    }

    private func visuallyUnlocked(for phase: PhaseID) -> Bool {
        if let limit = visualOverrideUnlockedUpTo {
            return phase.index <= limit
        }
        return journey.progress.isUnlocked(phase)
    }

    private func visuallyCurrent(for phase: PhaseID, unlocked: Bool) -> Bool {
        if let limit = visualOverrideUnlockedUpTo {
            return limit == 0 && phase.index == 0
        }
        return unlocked && !journey.progress.journeyCompleted && phase == journey.progress.currentPhase
    }

    private func visuallyCompletedSegment(at index: Int) -> Bool {
        if let limit = visualOverrideUnlockedUpTo {
            return index < limit
        }
        return journey.progress.record(for: PhaseID.allCases[index]).explanationAvailable
    }

    private var stageMap: some View {
        GeometryReader { geometry in
            let left = geometry.size.width * 0.29
            let right = geometry.size.width * 0.72
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for index in 0..<(PhaseID.allCases.count - 1) {
                        var path = Path()
                        let start = CGPoint(x: index.isMultiple(of: 2) ? left : right,
                                            y: stageY(index))
                        let end = CGPoint(x: index.isMultiple(of: 2) ? right : left,
                                          y: stageY(index + 1))
                        path.move(to: start)
                        if index == 0 {
                            let bend = min(78, (end.y - start.y) * 0.68)
                            path.addLine(to: CGPoint(x: end.x - bend, y: start.y))
                            path.addQuadCurve(to: CGPoint(x: end.x, y: start.y + bend),
                                              control: CGPoint(x: end.x, y: start.y))
                            path.addLine(to: end)
                        } else {
                            let middleY = (start.y + end.y) / 2
                            let direction: CGFloat = end.x > start.x ? 1 : -1
                            let bend: CGFloat = 62
                            path.addLine(to: CGPoint(x: start.x, y: middleY - bend))
                            path.addQuadCurve(to: CGPoint(x: start.x + direction * bend, y: middleY),
                                              control: CGPoint(x: start.x, y: middleY))
                            path.addLine(to: CGPoint(x: end.x - direction * bend, y: middleY))
                            path.addQuadCurve(to: CGPoint(x: end.x, y: middleY + bend),
                                              control: CGPoint(x: end.x, y: middleY))
                            path.addLine(to: end)
                        }
                        let completed = visuallyCompletedSegment(at: index)
                        context.stroke(path, with: .color(.white.opacity(0.94)),
                                       style: StrokeStyle(lineWidth: 3, lineCap: .round,
                                                          dash: completed ? [] : [8, 8]))
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                ForEach(PhaseID.allCases) { phase in
                    let unlocked = visuallyUnlocked(for: phase)
                    let isCurrent = visuallyCurrent(for: phase, unlocked: unlocked)
                    let isRecoiling = recoilStageIndex == phase.index
                    Button { open(phase) } label: {
                        stageMarker(phase, unlocked: unlocked, isCurrent: isCurrent)
                            .scaleEffect(isRecoiling ? 1.15 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(!journey.progress.isUnlocked(phase))
                    .accessibilityIdentifier("phase_\(phase.rawValue)")
                    .accessibilityLabel("\(PhaseContent.content(for: phase).title), \(journey.progress.isUnlocked(phase) ? "tersedia" : "terkunci")")
                    .position(x: phase.index.isMultiple(of: 2) ? left : right,
                              y: stageY(phase.index))
                }

                if let explosionStartDate {
                    TimelineView(.animation(paused: false)) { timeline in
                        CycleResetExplosionCanvas(
                            elapsed: timeline.date.timeIntervalSince(explosionStartDate),
                            leftX: left,
                            rightX: right,
                            stageY: stageY
                        )
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
        }
        .frame(height: stageY(PhaseID.allCases.count - 1) + 127)
    }

    private func stageMarker(_ phase: PhaseID, unlocked: Bool, isCurrent: Bool) -> some View {
        VStack(spacing: -25) {
            ZStack {
                if isCurrent {
                    Ellipse()
                        .fill(RadialGradient(
                            colors: [.white.opacity(0.30), .white.opacity(0.12), .clear],
                            center: .center,
                            startRadius: 8,
                            endRadius: 84
                        ))
                        .frame(width: 164, height: 148)
                        .blur(radius: 14)
                        .allowsHitTesting(false)
                }
                HomeStageMenuObjectView(phase: phase)
                    .frame(width: 94, height: 92)
                    .opacity(unlocked ? 1 : 0.8)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 3)
            }
            .frame(width: 94, height: 92)
            stagePedestal(unlocked: unlocked, isCurrent: isCurrent)
                .zIndex(-1)
            Text(PhaseContent.content(for: phase).title)
                .font(.system(size: markerLabelSize, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.9), radius: 4, y: 2)
                .padding(.top, 18)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .overlay(alignment: .center) {
            if !unlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 3, y: 2)
                    .offset(y: 10)
                    .transition(.scale(scale: 1.45).combined(with: .opacity))
            }
        }
        .frame(width: dynamicTypeSize.isAccessibilitySize ? 210 : 145,
               height: dynamicTypeSize.isAccessibilitySize ? 190 : 145)
        .contentShape(Rectangle())
    }

    private func stagePedestal(unlocked: Bool, isCurrent: Bool) -> some View {
        Image("JourneyStagePlatform")
            .resizable()
            .interpolation(.high)
            .frame(width: 118, height: 61)
            .saturation(unlocked ? 1 : 0.7)
            .brightness(unlocked ? 0 : -0.35)
            .shadow(color: isCurrent ? .white.opacity(0.28) : .clear, radius: 32)
            .shadow(color: isCurrent ? .white.opacity(0.14) : .clear, radius: 56)
            .shadow(color: .black.opacity(0.35), radius: 3, y: 4)
    }

    @ViewBuilder private func scrollingBackground(viewportHeight: CGFloat) -> some View {
        if showsBackground {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    Image("JourneySoil")
                        .resizable()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    Image("JourneyLandscapeSoil")
                        .resizable()
                        .frame(width: geometry.size.width, height: viewportHeight * 1.9)
                        .offset(y: -viewportHeight)
                        .frame(width: geometry.size.width, height: viewportHeight * 0.9, alignment: .top)
                        .clipped()
                        .mask {
                            LinearGradient(stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: 0.78),
                                .init(color: .clear, location: 1)
                            ], startPoint: .top, endPoint: .bottom)
                        }
                        .overlay(alignment: .top) {
                            LinearGradient(colors: [.black.opacity(0.42), .clear],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: 130)
                        }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .ignoresSafeArea()
        } else {
            Color(red: 0.25, green: 0.15, blue: 0.09)
        }
    }
}

private struct MenuScrollBoundary: UIViewRepresentable {
    func makeUIView(context: Context) -> BoundaryView { BoundaryView() }
    func updateUIView(_ view: BoundaryView, context: Context) {}

    final class BoundaryView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            var ancestor = superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView {
                    scrollView.bounces = false
                    return
                }
                ancestor = view.superview
            }
        }
    }
}

private enum CycleResetSchedule {
    struct Step {
        let stageIndex: Int
        let detonationTime: Double
    }

    static let steps: [Step] = [
        Step(stageIndex: 5, detonationTime: 0.38),
        Step(stageIndex: 4, detonationTime: 0.51),
        Step(stageIndex: 3, detonationTime: 0.62),
        Step(stageIndex: 2, detonationTime: 0.72),
        Step(stageIndex: 1, detonationTime: 0.81)
    ]
    static let awakeningTime: Double = 0.88
    static let totalDuration: Double = 1.58
}

private struct CycleResetExplosionCanvas: View {
    let elapsed: Double
    let leftX: CGFloat
    let rightX: CGFloat
    let stageY: (Int) -> CGFloat

    private struct ParticleSeed {
        let angle: Double
        let speed: Double
        let size: CGFloat
        let stretch: CGFloat
        let tone: Int
        let gravity: Double
    }

    private static let particleSeeds: [ParticleSeed] = {
        (0..<22).map { index in
            let golden = Double(index) * 2.399963229728653
            let speed = 105.0 + Double((index * 37) % 115)
            let size = CGFloat(3.0 + Double((index * 19) % 5))
            let stretch = index.isMultiple(of: 3) ? CGFloat(2.4) : CGFloat(1.0)
            let tone = index % 4
            let gravity = 32.0 + Double((index * 23) % 34)
            return ParticleSeed(
                angle: golden,
                speed: speed,
                size: size,
                stretch: stretch,
                tone: tone,
                gravity: gravity
            )
        }
    }()

    var body: some View {
        Canvas { context, _ in
            for step in CycleResetSchedule.steps {
                let t = elapsed - step.detonationTime
                guard t >= 0, t < 0.76 else { continue }
                let x = step.stageIndex.isMultiple(of: 2) ? leftX : rightX
                let center = CGPoint(x: x, y: stageY(step.stageIndex))
                let previousX = (step.stageIndex - 1).isMultiple(of: 2) ? leftX : rightX
                let previousCenter = CGPoint(x: previousX, y: stageY(step.stageIndex - 1))

                drawFlash(in: &context, at: center, localTime: t)
                drawShockwaves(in: &context, at: center, localTime: t)
                drawParticles(in: &context, at: center, stageIndex: step.stageIndex, localTime: t)
                drawPathBreakSparks(in: &context, segmentIndex: step.stageIndex - 1, from: previousCenter, to: center, localTime: t)
            }

            let wakeT = elapsed - CycleResetSchedule.awakeningTime
            if wakeT >= 0, wakeT < 0.62 {
                let stage0Center = CGPoint(x: leftX, y: stageY(0))
                let p = min(1.0, wakeT / 0.58)
                let eased = 1.0 - pow(1.0 - p, 3.0)
                let radius = CGFloat(20.0 + 76.0 * eased)
                let alpha = (1.0 - p) * 0.58
                var ring = Path()
                ring.addEllipse(in: CGRect(
                    x: stage0Center.x - radius,
                    y: stage0Center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.stroke(
                    ring,
                    with: .color(Color(red: 1.0, green: 0.88, blue: 0.55).opacity(alpha)),
                    lineWidth: CGFloat(3.0 * (1.0 - p) + 0.5)
                )
            }
        }
    }

    private func drawFlash(in context: inout GraphicsContext, at center: CGPoint, localTime t: Double) {
        guard t < 0.24 else { return }
        let p = t / 0.24
        let fade = (1.0 - p) * (1.0 - p)
        let radius = CGFloat(12.0 + 52.0 * (1.0 - (1.0 - p) * (1.0 - p)))
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.92 * fade),
                    Color(red: 1.0, green: 0.72, blue: 0.24).opacity(0.55 * fade),
                    Color.clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    private func drawShockwaves(in context: inout GraphicsContext, at center: CGPoint, localTime t: Double) {
        if t < 0.52 {
            let p = t / 0.52
            let eased = 1.0 - pow(1.0 - p, 3.0)
            let radius = CGFloat(14.0 + 84.0 * eased)
            let alpha = (1.0 - p) * 0.88
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(Color(red: 1.0, green: 0.80, blue: 0.36).opacity(alpha)),
                lineWidth: CGFloat(4.0 * (1.0 - p) + 0.6)
            )
        }
        let delayed = t - 0.05
        if delayed > 0, delayed < 0.48 {
            let p = delayed / 0.48
            let eased = 1.0 - pow(1.0 - p, 3.0)
            let radius = CGFloat(10.0 + 62.0 * eased)
            let alpha = (1.0 - p) * 0.72
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(AppTheme.orange.opacity(alpha)),
                lineWidth: CGFloat(2.8 * (1.0 - p) + 0.5)
            )
        }
    }

    private func drawParticles(in context: inout GraphicsContext, at center: CGPoint, stageIndex: Int, localTime t: Double) {
        let p = min(1.0, t / 0.74)
        let alpha = pow(1.0 - p, 1.4)
        let phaseRotation = Double(stageIndex) * 0.55
        let drag = 4.2
        let travelScale = (1.0 - exp(-drag * t)) / drag

        for seed in Self.particleSeeds {
            let angle = seed.angle + phaseRotation
            let dist = seed.speed * travelScale
            let px = center.x + CGFloat(cos(angle) * dist)
            let py = center.y + CGFloat(sin(angle) * dist + seed.gravity * t * t)
            let diameter = seed.size * CGFloat(1.0 - 0.62 * p)
            let color: Color = switch seed.tone {
            case 0: .white
            case 1: Color(red: 1.0, green: 0.78, blue: 0.28)
            case 2: AppTheme.orange
            default: Color(red: 0.30, green: 0.17, blue: 0.09)
            }

            if seed.stretch > 1.0 {
                let streakLen = diameter * seed.stretch
                let dx = CGFloat(cos(angle)) * streakLen * 0.5
                let dy = CGFloat(sin(angle)) * streakLen * 0.5
                var streak = Path()
                streak.move(to: CGPoint(x: px - dx, y: py - dy))
                streak.addLine(to: CGPoint(x: px + dx, y: py + dy))
                context.stroke(
                    streak,
                    with: .color(color.opacity(alpha)),
                    style: StrokeStyle(lineWidth: max(1.4, diameter * 0.55), lineCap: .round)
                )
            } else {
                let rect = CGRect(x: px - diameter * 0.5, y: py - diameter * 0.5, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
            }
        }
    }

    private func drawPathBreakSparks(in context: inout GraphicsContext, segmentIndex: Int, from: CGPoint, to: CGPoint, localTime t: Double) {
        guard t < 0.36 else { return }
        let p = t / 0.36
        let alpha = (1.0 - p) * 0.85
        let anchors: [CGPoint]
        if segmentIndex == 0 {
            let bend = min(78, (to.y - from.y) * 0.68)
            anchors = [
                CGPoint(x: (from.x + to.x - bend) * 0.5, y: from.y),
                CGPoint(x: to.x - bend * 0.3, y: from.y + bend * 0.3),
                CGPoint(x: to.x, y: (from.y + bend + to.y) * 0.5)
            ]
        } else {
            let middleY = (from.y + to.y) * 0.5
            anchors = [
                CGPoint(x: from.x, y: (from.y + middleY) * 0.5),
                CGPoint(x: (from.x + to.x) * 0.5, y: middleY),
                CGPoint(x: to.x, y: (middleY + to.y) * 0.5)
            ]
        }
        for anchor in anchors {
            let spread = CGFloat(18.0 * p)
            let radius = CGFloat(3.4 * (1.0 - p))
            for sign: CGFloat in [-1, 1] {
                let sparkCenter = CGPoint(x: anchor.x + sign * spread * 0.65, y: anchor.y - spread * 0.75)
                let rect = CGRect(
                    x: sparkCenter.x - radius,
                    y: sparkCenter.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color(red: 1.0, green: 0.88, blue: 0.62).opacity(alpha))
                )
            }
        }
    }
}
