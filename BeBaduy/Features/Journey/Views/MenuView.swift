import SwiftUI

enum JourneyIntroCopy {
    static let title = "Perjalanan Ngahuma"
    static let description = "Tradisi berladang masyarakat Baduy yang diwariskan turun-temurun untuk menjaga keseimbangan hidup antara manusia dan alam, melalui rangkaian tahapan yang dilakukan setiap tahun."
}

struct MenuView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 29
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var markerLabelSize: CGFloat = 16
    let journey: JourneyViewModel
    var showsBackground = true
    var showsIntroText = true
    var transitionTopInset: CGFloat? = nil
    var landscapeViewportHeight: CGFloat? = nil
    var onPullToLanding: (() -> Void)? = nil
    let open: (PhaseID) -> Void
    let onScroll: (CGFloat, CGFloat) -> Void
    @State private var isUserScrolling = false
    @State private var pullStartedAtTop = false
    @State private var isPullToLandingArmed = false
    private var firstStageGap: CGFloat { dynamicTypeSize.isAccessibilitySize ? 185 : 115 }
    private var stageStep: CGFloat { dynamicTypeSize.isAccessibilitySize ? 210 : 145 }

    private func stageY(_ index: Int) -> CGFloat {
        103 + (index == 0 ? 0 : firstStageGap + CGFloat(index - 1) * stageStep)
    }

    var body: some View {
        GeometryReader { viewport in
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

                stageMap
            }
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
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top < -65
        } action: { _, isBeyondThreshold in
            guard isUserScrolling, pullStartedAtTop else { return }
            isPullToLandingArmed = isBeyondThreshold
        }
        .onScrollPhaseChange { old, new, context in
            let offset = context.geometry.contentOffset.y + context.geometry.contentInsets.top
            if new == .interacting {
                isUserScrolling = true
                pullStartedAtTop = offset <= 12
                isPullToLandingArmed = false
            } else {
                isUserScrolling = false
                if old == .interacting {
                    let shouldReturn = pullStartedAtTop && (isPullToLandingArmed || offset < -65)
                    pullStartedAtTop = false
                    isPullToLandingArmed = false
                    if shouldReturn { onPullToLanding?() }
                }
            }
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
        }
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
                        let completed = journey.progress.record(for: PhaseID.allCases[index]).explanationAvailable
                        context.stroke(path, with: .color(.white.opacity(0.94)),
                                       style: StrokeStyle(lineWidth: 3, lineCap: .round,
                                                          dash: completed ? [] : [8, 8]))
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                ForEach(PhaseID.allCases) { phase in
                    let unlocked = journey.progress.isUnlocked(phase)
                    let isCurrent = unlocked && !journey.progress.journeyCompleted && phase == journey.progress.currentPhase
                    Button { open(phase) } label: {
                        stageMarker(phase, unlocked: unlocked, isCurrent: isCurrent)
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                    .accessibilityIdentifier("phase_\(phase.rawValue)")
                    .accessibilityLabel("\(PhaseContent.content(for: phase).title), \(unlocked ? "tersedia" : "terkunci")")
                    .position(x: phase.index.isMultiple(of: 2) ? left : right,
                              y: stageY(phase.index))
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
