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
    private var stageStep: CGFloat { dynamicTypeSize.isAccessibilitySize ? 210 : 160 }

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
        .onScrollPhaseChange { _, newPhase in
            isUserScrolling = newPhase == .interacting
        }
        .onScrollPhaseChange { old, new, context in
            let offset = context.geometry.contentOffset.y + context.geometry.contentInsets.top
            if old == .interacting, new != .interacting, offset < -65 { onPullToLanding?() }
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
                    var path = Path()
                    for index in 0..<(PhaseID.allCases.count - 1) {
                        let start = CGPoint(x: index.isMultiple(of: 2) ? left : right,
                                            y: 103 + CGFloat(index) * stageStep)
                        let end = CGPoint(x: index.isMultiple(of: 2) ? right : left,
                                          y: 103 + CGFloat(index + 1) * stageStep)
                        path.move(to: start)
                        path.addCurve(to: end,
                                      control1: CGPoint(x: end.x, y: start.y),
                                      control2: CGPoint(x: start.x, y: end.y))
                    }
                    context.stroke(path, with: .color(.white.opacity(0.94)),
                                   style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 8]))
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                ForEach(PhaseID.allCases) { phase in
                    let unlocked = journey.progress.isUnlocked(phase)
                    Button { open(phase) } label: {
                        stageMarker(phase, unlocked: unlocked)
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                    .accessibilityIdentifier("phase_\(phase.rawValue)")
                    .accessibilityLabel("\(PhaseContent.content(for: phase).title), \(unlocked ? "tersedia" : "terkunci")")
                    .position(x: phase.index.isMultiple(of: 2) ? left : right,
                              y: 103 + CGFloat(phase.index) * stageStep)
                }
            }
        }
        .frame(height: 230 + stageStep * 5)
    }

    private func stageMarker(_ phase: PhaseID, unlocked: Bool) -> some View {
        VStack(spacing: -25) {
            HomeStageMenuObjectView(phase: phase)
                .frame(width: 94, height: 92)
                .opacity(unlocked ? 1 : 0.8)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 3)
            stagePedestal(unlocked: unlocked)
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

    private func stagePedestal(unlocked: Bool) -> some View {
        Image("JourneyStagePlatform")
            .resizable()
            .interpolation(.high)
            .frame(width: 118, height: 61)
            .saturation(unlocked ? 1 : 0.7)
            .brightness(unlocked ? 0 : -0.35)
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
