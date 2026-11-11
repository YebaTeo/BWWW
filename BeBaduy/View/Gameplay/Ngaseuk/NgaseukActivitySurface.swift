import SwiftUI

struct NgaseukActivitySurface: View {
    let model: NgaseukViewModel
    @Environment(ActivityCardState.self) private var card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleHoles: Set<Int> = []
    @State private var workingTarget: Int?
    @State private var toolDepth: CGFloat = -70
    @State private var isStroking = false

    private func target(_ index: Int, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * CGFloat(index + 1) / 4,
                y: size.height * (index == 1 ? 0.66 : 0.61))
    }

    var body: some View {
        GeometryReader { geometry in
            let toolTarget = workingTarget ?? model.selectedTarget
            let point = target(toolTarget, in: geometry.size)
            let toolHeight = geometry.size.height * 0.38
            ZStack {
                if model.step != .instructions {
                    ForEach(0..<3) { index in
                        Group {
                            if model.step == .seeding {
                                Button { model.peek(index) } label: {
                                    soilMark(index, toolTarget: toolTarget)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Lubang \(index + 1)")
                                .accessibilityValue(model.seeds.contains(index) ? "Berisi benih" : "Sudah dibuat")
                                .accessibilityIdentifier("field.hole.\(index)")
                                .dropDestination(for: String.self) { items, _ in
                                    guard !model.isDemonstrating, items.contains("rice-seed") else { return false }
                                    return model.seed(index)
                                }
                            } else if model.step == .digging {
                                Button {
                                    model.dig(index)
                                } label: {
                                    soilMark(index, toolTarget: toolTarget)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Lubang \(index + 1)")
                                .accessibilityIdentifier("field.hole.\(index)")
                            } else {
                                soilMark(index, toolTarget: toolTarget)
                                    .accessibilityHidden(true)
                            }
                        }
                        .position(target(index, in: geometry.size))
                    }
                }
                if model.step == .digging || isStroking {
                    // Dynamic ground contact shadow connecting the 3D tool to the huma soil
                    let penetration = max(0.0, min(1.0, (toolDepth + 70.0) / 70.0))
                    let shadowW: CGFloat = 46.0 * (0.75 + 0.35 * (1.0 - penetration))
                    let shadowH: CGFloat = 20.0 * (0.75 + 0.35 * (1.0 - penetration))
                    let shadowAlpha: Double = 0.22 + 0.48 * penetration

                    Ellipse()
                        .fill(RadialGradient(
                            colors: [
                                Color(red: 0.12, green: 0.08, blue: 0.05).opacity(shadowAlpha),
                                Color(red: 0.12, green: 0.08, blue: 0.05).opacity(shadowAlpha * 0.35),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: shadowW * 0.5
                        ))
                        .frame(width: shadowW, height: shadowH)
                        .offset(x: 6.0 * (1.0 - penetration), y: 3.0 * (1.0 - penetration))
                        .position(point)
                        .allowsHitTesting(false)
                        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: toolTarget)

                    AseukTool().frame(width: 110, height: toolHeight)
                        .position(x: point.x, y: point.y - toolHeight / 2 + toolDepth)
                        .allowsHitTesting(false)
                        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: toolTarget)
                }
                if model.step == .instructions {
                    tutorial
                }
                if model.step == .digging {
                    VStack(spacing: 6) {
                        Text(model.motionActive ? "Gerakkan ponsel ke bawah atau ketuk lubang" : model.session.feedback)
                            .font(.headline)
                        Text("\(visibleHoles.count) / 3 lubang").font(.subheadline.monospacedDigit())
                    }.multilineTextAlignment(.center).padding(16)
                        .foregroundStyle(.white).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 24).frame(maxHeight: .infinity, alignment: .top).padding(.top, 65)
                        .allowsHitTesting(false)
                }
                if model.step == .seeding {
                    RiceSeed3DView()
                        .draggable("rice-seed")
                        .accessibilityIdentifier("field.seed")
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.30)
                }
                if let target = model.peekTarget {
                    NgaseukSeedPeekView(model: model, target: target)
                        .transition(.opacity)
                }
            }.disabled(model.isDemonstrating)
        }
        .onChange(of: model.step) { _, step in
            switch step {
            case .digging, .seeding:
                card.dismiss()
            case .instructions: card.dismiss()
            case .holesReady: break // Reveal planting instructions after the last stick withdraws.
            }
        }
        .onChange(of: model.peekTarget) { _, target in
            if target != nil { card.dismiss() }
        }
        .task(id: model.holes) { await showStroke() }
    }

    private func soilMark(_ index: Int, toolTarget: Int) -> some View {
        NgaseukSoilMark(dug: visibleHoles.contains(index), seeded: model.seeds.contains(index),
                       focused: model.step == .digging && toolTarget == index)
    }

    private var tutorial: some View {
        VStack(spacing: 36) {
            ZStack {
                Image(systemName: "iphone")
                    .rotationEffect(.degrees(12))
                    .offset(x: 14, y: -16)
                    .opacity(0.28)
                Image(systemName: "iphone")
            }
            .font(.system(size: 58, weight: .semibold))
            .foregroundStyle(.white)
            .accessibilityHidden(true)

            Text("Gerakkan ponselmu dari atas ke bawah untuk menggunakan aseuk.")
                .font(.title3)
                .foregroundStyle(AppTheme.cream)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("ngaseuk.motion.tutorial")
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, 32)
        .padding(.bottom, 135)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(.black.opacity(0.24))
    }

    @MainActor private func showStroke() async {
        let added = model.holes.subtracting(visibleHoles)
        guard let index = added.contains(model.lastDug) ? model.lastDug : added.first else {
            visibleHoles = model.holes
            if model.holes.isEmpty { workingTarget = nil; isStroking = false; toolDepth = -70 }
            return
        }
        visibleHoles = model.holes.subtracting([index])
        workingTarget = index
        isStroking = true
        toolDepth = -70
        if !reduceMotion {
            // Windup: slight backward raise
            withAnimation(.easeOut(duration: 0.12)) { toolDepth = -92 }
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }

            // Powerful downward strike into soil
            withAnimation(.easeIn(duration: 0.16)) { toolDepth = 22 }
            do { try await Task.sleep(for: .milliseconds(160)) } catch { return }
        }
        visibleHoles = model.holes
        if !reduceMotion {
            // Dwell in soil
            do { try await Task.sleep(for: .milliseconds(130)) } catch { return }

            // Spring recoil retraction
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) { toolDepth = -70 }
            do { try await Task.sleep(for: .milliseconds(320)) } catch { return }
        }
        isStroking = false
        workingTarget = nil
        toolDepth = -70
        if model.step == .holesReady { card.showInstruction() }
    }
}
