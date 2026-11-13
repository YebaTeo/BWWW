import SwiftUI

struct NgaseukActivitySurface: View {
    let model: NgaseukViewModel
    @Environment(ActivityCardState.self) private var card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleDigCounts: [Int: Int] = [:]
    @State private var workingTarget: Int?
    @State private var toolDepth: CGFloat = -65
    @State private var isStroking = false
    @State private var isSoilDisplacing = false
    @State private var seedDragLocation: CGPoint?
    @State private var seedDragOffset: CGSize = .zero

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
                if model.step != .instructions && model.peekTarget == nil {
                    ForEach(0..<3) { index in
                        Group {
                            if model.step == .seeding {
                                soilMark(index, toolTarget: toolTarget)
                                    .allowsHitTesting(false)
                                .accessibilityLabel("Lubang \(index + 1)")
                                    .accessibilityValue(model.seeds.contains(index) ? "Berisi benih" : "Sudah dibuat")
                            } else if model.step == .digging {
                                Button {
                                    model.dig(index)
                                } label: {
                                    VStack(spacing: 2) {
                                        soilMark(index, toolTarget: toolTarget)
                                        Text("\(model.digCounts[index, default: 0])/3")
                                            .font(.caption2.monospacedDigit().bold())
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(index != model.selectedTarget || model.isDemonstrating)
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
                    let penetration = max(0.0, min(1.0, (toolDepth + 65.0) / 67.0))
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

                    // While idle, the stick follows the phone live (down = dips, up = lifts).
                    let follow: CGFloat = isStroking ? 0 : CGFloat(-model.toolFollow) * 28
                    AseukTool(autoRotate: isStroking && !reduceMotion, rotationSpeed: 4.5,
                              pitch: 0, yaw: 0, roll: 0)
                        .frame(width: 110, height: toolHeight)
                        // Align the rendered 3D tip precisely so that at maximum stroke it stops inside the hole cavity
                        .position(x: point.x, y: point.y - toolHeight * 0.50 + toolDepth + follow)
                        .allowsHitTesting(false)
                        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: toolTarget)
                        .animation(.interactiveSpring(response: 0.08, dampingFraction: 0.9), value: follow)

                    if isSoilDisplacing {
                        SoilStrikeSplashEffect()
                            .position(point)
                            .allowsHitTesting(false)
                            .zIndex(3)
                    }
                }
                if model.step == .instructions {
                    tutorial
                }
                if model.step == .digging {
                    VStack(spacing: 6) {
                        Text(model.motionActive ? "Gerakkan ponsel ke bawah atau ketuk lubang" : model.session.feedback)
                            .font(.headline)
                        Text("\(model.holes.count) / 3 lubang").font(.subheadline.monospacedDigit())
                    }.font(.subheadline).multilineTextAlignment(.center).padding(24)
                        .activityCardStyle()
                        .padding(.horizontal, 24).frame(maxHeight: .infinity, alignment: .top).padding(.top, 65)
                        .allowsHitTesting(false)
                }
                if model.step == .seeding && model.peekTarget == nil && !model.isDraggingSeed {
                    VStack(spacing: 6) {
                        Text("Goyangkan ponsel perlahan atau seret wadah benih ke lubang")
                            .font(.headline)
                        Text("\(model.seeds.count) / 3 lubang berisi benih")
                            .font(.subheadline.monospacedDigit())
                    }
                    .font(.subheadline).multilineTextAlignment(.center).padding(24)
                    .activityCardStyle()
                    .padding(.horizontal, 24).frame(maxHeight: .infinity, alignment: .top).padding(.top, 65)
                    .allowsHitTesting(false)
                }
                if model.step == .seeding && (
                    model.isDraggingSeed ||
                    !(model.isBasketEntering || model.isBasketTilting || model.isPouring)
                ) {
                    RiceSeed3DView(isDragging: model.isDraggingSeed,
                                   isInteractable: true,
                                   isPouring: model.isBasketTilting || model.isPouring)
                        .accessibilityIdentifier("field.seed")
                        .position(seedDragLocation ?? homeSeedBowlPosition(in: geometry.size))
                        .contentShape(Rectangle())
                        .gesture(seedDragGesture(in: geometry.size))
                        .zIndex(model.isDraggingSeed ? 2 : 0)
                }
                if let target = model.peekTarget {
                    NgaseukSeedPeekView(model: model, target: target, dragActive: model.isDraggingSeed,
                                        canPlant: model.isSeedInPlantingRange)
                        .transition(.opacity)
                }
            }
            .coordinateSpace(name: "ngaseukField")
            .disabled(model.isDemonstrating)
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
            if target != nil {
                card.dismiss()
            } else if !model.isDraggingSeed {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                    seedDragLocation = nil
                }
                seedDragOffset = .zero
            }
        }
        .task(id: model.digCounts) { await showStroke() }
    }

    private func soilMark(_ index: Int, toolTarget: Int) -> some View {
        NgaseukSoilMark(digCount: visibleDigCounts[index, default: 0], seeded: model.seeds.contains(index),
                       focused: model.step == .digging && toolTarget == index)
    }

    private func seedDragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("ngaseukField"))
            .onChanged { value in
                if !model.isDraggingSeed {
                    let home = homeSeedBowlPosition(in: size)
                    seedDragOffset = CGSize(width: home.x - value.startLocation.x,
                                            height: home.y - value.startLocation.y)
                    model.beginSeedDrag()
                }
                seedDragLocation = CGPoint(x: value.location.x + seedDragOffset.width,
                                           y: value.location.y + seedDragOffset.height)
                updateSeedDrag(at: value.location, in: size)
            }
            .onEnded { value in
                updateSeedDrag(at: value.location, in: size)
                let isPouring = model.endSeedDrag()
                if !isPouring {
                    seedDragLocation = nil
                    seedDragOffset = .zero
                }
            }
    }

    private func homeSeedBowlPosition(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height * 0.49)
    }

    private func updateSeedDrag(at location: CGPoint, in size: CGSize) {
        // Once a hole is zoomed in, keep that detail view open for the duration
        // of this drag. The second, smaller target is the opening at its center.
        if let activeTarget = model.peekTarget {
            let holeCenter = CGPoint(x: size.width / 2, y: size.height / 2)
            let distance = hypot(location.x - holeCenter.x, location.y - holeCenter.y)
            model.updateSeedDrag(near: activeTarget, canPlant: distance < 78)
            return
        }

        let nearest = (0..<3).map { index -> (index: Int, distance: CGFloat) in
            let point = target(index, in: size)
            return (index, hypot(location.x - point.x, location.y - point.y))
        }.min { $0.distance < $1.distance }
        guard let nearest, nearest.distance < 100 else {
            model.updateSeedDrag(near: nil, canPlant: false)
            return
        }
        model.updateSeedDrag(near: nearest.index, canPlant: false)
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
        let count = model.digCounts[model.lastDug, default: 0]
        guard count > visibleDigCounts[model.lastDug, default: 0] else {
            if model.digCounts.isEmpty { workingTarget = nil; isStroking = false; toolDepth = -65 }
            return
        }
        let index = model.lastDug
        workingTarget = index
        // Start the strike from wherever the live-follow stick currently is, so there is no jump.
        toolDepth = -65 + CGFloat(-model.toolFollow) * 28
        isStroking = true
        if !reduceMotion {
            // Immediate downward strike into the hole cavity (55ms, synced with audio + 3-pulse haptics)
            withAnimation(.easeIn(duration: 0.055)) { toolDepth = 2 }
            do { try await Task.sleep(for: .milliseconds(55)) } catch { return }
        } else {
            toolDepth = 2
        }

        // Impact moment: soil heaves upward around the piercing tip inside the hole
        isSoilDisplacing = true
        withAnimation(.easeOut(duration: 0.22)) { visibleDigCounts[index] = count }

        if !reduceMotion {
            // Dwell momentarily inside hole as displaced earth settles
            do { try await Task.sleep(for: .milliseconds(160)) } catch { return }

            // Spring recoil retraction back above hole
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                toolDepth = -65
                isSoilDisplacing = false
            }
            do { try await Task.sleep(for: .milliseconds(280)) } catch { return }
        } else {
            isSoilDisplacing = false
            toolDepth = -65
        }
        isStroking = false
        workingTarget = nil
        toolDepth = -65
        if model.step == .holesReady { card.showInstruction() }
    }
}

/// Pure soil splash particle effect ("percikan tanah") when the Aseuk stabs the ground.
private struct SoilStrikeSplashEffect: View {
    @State private var splashing = false

    // Randomized but deterministic directions for natural organic dirt splash
    private let particles: [(angle: Double, distance: CGFloat, lift: CGFloat, size: CGFloat, isDark: Bool)] = [
        (-2.2, 18.0, -16.0, 2.5, false),
        (-1.6, 24.0, -22.0, 3.2, true),
        (-1.1, 19.0, -18.0, 2.0, false),
        (-0.5, 26.0, -20.0, 3.0, true),
        (-2.8, 14.0, -11.0, 2.2, false),
        (-0.2, 17.0, -12.0, 2.6, true),
        (-1.9, 28.0, -24.0, 2.8, false),
        (-1.3, 30.0, -25.0, 3.5, true),
        (-0.8, 22.0, -17.0, 2.4, false),
        (-2.5, 21.0, -14.0, 2.0, true)
    ]

    var body: some View {
        ZStack {
            ForEach(0..<particles.count, id: \.self) { i in
                let p = particles[i]
                let color = p.isDark
                    ? Color(red: 0.22, green: 0.13, blue: 0.07)
                    : Color(red: 0.36, green: 0.23, blue: 0.14)

                Circle()
                    .fill(color)
                    .frame(width: p.size, height: p.size)
                    .offset(
                        x: splashing ? cos(p.angle) * p.distance : 0,
                        y: splashing ? sin(p.angle) * (p.distance * 0.4) + p.lift : 0
                    )
                    .scaleEffect(splashing ? 0.70 : 1.25)
                    .opacity(splashing ? 0.0 : 0.95)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.30)) {
                splashing = true
            }
        }
    }
}
