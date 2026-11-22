import SwiftUI

struct NgaleuitkeunPareView: View {
    let journey: JourneyViewModel
    let advance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = NgaleuitkeunPareViewModel()
    @State private var completion = CompletionViewModel()
    @State private var finaleStep: FinaleStep = .result
    @State private var lightVisible = false

    var body: some View {
        ZStack {
            PhaseContainerView(content: PhaseContent.content(for: .ngaleuitkeunPare),
                               session: model.session, journey: journey,
                               start: model.start,
                               restore: { model.session.restore($0) }, advance: advance,
                               showsInitialActivityCard: false,
                               leuitActivity: model.sceneState,
                               surface: { NgaleuitkeunPareActivitySurface(model: model) },
                               activity: { NgaleuitkeunPareActivityView() },
                               description: { NgaleuitkeunPareDescriptionView() })

            if model.session.outcome != nil {
                Color.black.opacity(finaleStep == .result ? 0.40 : 0.48)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                if finaleStep == .result {
                    ActivityCardLayout(placement: .middle) {
                        ActivityCardPanel {
                            ActivityCardHeading("Keren!")
                            Text("Kita sudah menyimpan hasil Ngahuma kali ini.")
                                .multilineTextAlignment(.center)
                        }
                        .accessibilityIdentifier("ngaleuitkeun.activity.completed")
                    }
                    .transition(.opacity)
                }

                if finaleStep == .summary {
                    summaryOverlay
                        .transition(.opacity)
                }

                if lightVisible && !reduceMotion {
                    LeuitLightBurst()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }

                // The epic card is laid out while the summary is visible. The
                // same SceneKit renderer continues under every finale state.
                if finaleStep != .result {
                    let reward = ChapterCard.chapter(.ngaleuitkeunPare, secondCycle: journey.progress.secondCycle)
                    ChapterRewardCard(card: reward,
                                      alreadyOwned: !journey.newlyEarnedCards.contains(reward),
                                      isPresented: finaleStep == .card) {
                        journey.completeCycleAndReturnToMenu()
                        advance()
                    }
                    .opacity(finaleStep == .card ? 1 : 0)
                    .allowsHitTesting(finaleStep == .card)
                    .accessibilityHidden(finaleStep != .card)
                }
            }
        }
        .onChange(of: model.session.event) { _, _ in
            guard model.session.outcome != nil else { return }
            finaleStep = .result
            lightVisible = false
        }
        .task(id: model.session.outcome != nil) {
            guard model.session.outcome != nil else { return }
            do { try await Task.sleep(for: .seconds(2.2)) } catch { return }
            guard !Task.isCancelled, finaleStep == .result else { return }
            withAnimation(.easeInOut(duration: 0.32)) { finaleStep = .summary }
        }
        .task(id: finaleStep == .opening && scenePhase == .active) {
            guard finaleStep == .opening, scenePhase == .active else { return }
            if reduceMotion {
                model.setDoorOpening(1)
                finaleStep = .card
                return
            }
            let start = model.sceneState.doorOpening
            do {
                for frame in 0...42 {
                    let t = Float(frame) / 42
                    let eased = t * t * (3 - 2 * t)
                    model.setDoorOpening(start + (1 - start) * eased)
                    if frame == 14 {
                        withAnimation(.easeOut(duration: 0.65)) { lightVisible = true }
                    }
                    try await Task.sleep(for: .milliseconds(16))
                }
                try await Task.sleep(for: .milliseconds(450))
            } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { finaleStep = .card }
        }
    }

    private var summaryOverlay: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: 48)
                Text(completion.title)
                    .font(.system(size: 23, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.72))
                    .padding(.horizontal, 28)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("journey.completed")
                Spacer(minLength: 24)
                ScrollView {
                    Text(completion.message)
                        .font(.system(size: 18))
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: 0.23, green: 0.12, blue: 0.06))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 38)
                }
                .frame(maxWidth: 340, maxHeight: min(500, geometry.size.height * 0.58))
                .background {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(red: 1, green: 0.96, blue: 0.89).opacity(0.94))
                        .overlay {
                            Image("HumaTenunPattern")
                                .resizable()
                                .scaledToFill()
                                .opacity(0.12)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color(red: 0.92, green: 0.56, blue: 0.20), lineWidth: 1.5)
                }
                .padding(.horizontal, 30)
                Spacer(minLength: 24)
                Button { withAnimation(.easeOut(duration: 0.22)) { finaleStep = .opening } } label: {
                    Text("Selesai")
                        .font(.system(size: 17, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(.white)
                        .background(Color(red: 0.86, green: 0.35, blue: 0.01), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color(red: 1, green: 0.62, blue: 0.24)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("journey.finish")
                .padding(.horizontal, 44)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private enum FinaleStep {
    case result
    case summary
    case opening
    case card
}

private struct LeuitLightBurst: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let origin = CGPoint(x: size.width * 0.5, y: size.height * 0.49)
            Canvas { context, _ in
                for ray in 0..<12 {
                    let angle = Double(ray) * .pi / 6
                    let far = max(size.width, size.height) * 0.9
                    let inner = min(size.width, size.height) * 0.08
                    var path = Path()
                    path.move(to: CGPoint(x: origin.x + cos(angle - 0.08) * inner,
                                          y: origin.y + sin(angle - 0.08) * inner))
                    path.addLine(to: CGPoint(x: origin.x + cos(angle - 0.18) * far,
                                             y: origin.y + sin(angle - 0.18) * far))
                    path.addLine(to: CGPoint(x: origin.x + cos(angle + 0.18) * far,
                                             y: origin.y + sin(angle + 0.18) * far))
                    path.addLine(to: CGPoint(x: origin.x + cos(angle + 0.08) * inner,
                                             y: origin.y + sin(angle + 0.08) * inner))
                    path.closeSubpath()
                    context.fill(path, with: .color(Color(red: 1, green: 0.82, blue: 0.61).opacity(0.24)))
                }
            }
            RadialGradient(colors: [.white.opacity(0.85), Color(red: 1, green: 0.80, blue: 0.49).opacity(0.5), .clear],
                           center: UnitPoint(x: 0.5, y: 0.49), startRadius: 0, endRadius: size.width * 0.8)
        }
        .ignoresSafeArea()
    }
}
