import SwiftUI
struct NgoredActivitySurface: View {
    let model: NgoredViewModel
    @Environment(ActivityCardState.self) private var card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isHoldingKored = false
    @State private var holdTask: Task<Void, Never>?
    @State private var koredSwingCount = 0
    private func spot(_ index: Int, _ size: CGSize) -> CGPoint {
        CGPoint(x: size.width * (0.17 + CGFloat(index % 4) * 0.22),
                y: size.height * (index < 4 ? 0.57 : 0.72))
    }

    private func cutAtKoredTip(in size: CGSize) {
        guard model.step == .weeding || model.step == .secondWeeding else { return }
        let points = model.scene.projectedNgoredWeedPoints()
        let range = model.step == .secondWeeding ? 4..<7 : 0..<4
        let koredCenterY = size.height * 0.33 + (size.height * 0.66 + 16) / 2
        let tip = CGPoint(x: size.width - 110, y: koredCenterY - size.height * 0.24)
        koredSwingCount &+= 1
        func distance(_ point: CGPoint) -> CGFloat {
            hypot(point.x - tip.x, point.y - tip.y)
        }
        guard let target = range
            .filter({ !model.removed.contains($0) && points.indices.contains($0) })
            .min(by: { distance(points[$0]) < distance(points[$1]) }),
              distance(points[target]) < 108 else {
            model.session.feedback = "Arahkan mata kored ke gulma, lalu tap atau tahan."
            return
        }
        model.remove(target)
    }

    private func beginKoredHold(in size: CGSize) {
        guard !isHoldingKored else { return }
        isHoldingKored = true
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            while !Task.isCancelled && isHoldingKored {
                cutAtKoredTip(in: size)
                do { try await Task.sleep(for: .milliseconds(560)) } catch { return }
            }
        }
    }

    private func endKoredHold() {
        isHoldingKored = false
        holdTask?.cancel()
        holdTask = nil
    }

    private func shouldDismissCard(for step: NgoredViewModel.Step) -> Bool {
        switch step {
        case .rain, .cycles, .finalRain, .finalCycles, .secondWeeding:
            true
        case .initialRain, .weeding, .cleared, .secondCleared, .complete:
            false
        }
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                NarawasSurface(scene: model.scene)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                TimelineView(.animation(minimumInterval: 0.05, paused: scenePhase != .active)) { _ in
                    let points = model.scene.projectedNgoredWeedPoints()
                ForEach(0..<7) { index in
                        let activeRange = model.step == .secondWeeding ? 4..<7 : 0..<4
                        let cut = model.removed.contains(index)
                        let hits = model.strokes[index] ?? 0
                        if activeRange.contains(index), !cut, points.indices.contains(index) {
                            let pt = points[index]
                            if pt.x > 0 && pt.y > 0 && pt.x < geometry.size.width && pt.y < geometry.size.height {
                                Text("\(hits)/3")
                                    .font(.caption.monospacedDigit().bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(.black.opacity(0.62), in: Capsule())
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Gulma \(index + 1)")
                                    .accessibilityValue("\(hits) dari 3 sapuan")
                                    .accessibilityIdentifier("field.weed.\(index)")
                                    .accessibilityAction(named: "Sapukan kored") { model.remove(index) }
                                    .position(pt)
                            }
                        }
                    }
                }
                if model.step == .weeding || model.step == .secondWeeding {
                    let roundCount = model.step == .secondWeeding
                        ? (4..<7).filter { model.removed.contains($0) }.count
                        : (0..<4).filter { model.removed.contains($0) }.count
                    Button { model.remove(8) } label: {
                        Label("Padi · pertahankan", systemImage: "leaf")
                            .font(.subheadline.weight(.semibold)).padding(12)
                            .foregroundStyle(.white).background(.black.opacity(0.7), in: Capsule())
                    }.accessibilityIdentifier("field.rice")
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.43)
                    VStack(spacing: 6) {
                        Text("Pegang dan geser kored").font(.headline)
                        Text("Tiga sapuan ke bawah per gulma · \(roundCount)/\(model.step == .secondWeeding ? 3 : 4) bersih").font(.subheadline)
                        if model.session.feedback.hasPrefix("Ini padi") {
                            Text(model.session.feedback).font(.subheadline.bold())
                                .accessibilityIdentifier("ngored.rice.feedback")
                        }
                    }.multilineTextAlignment(.center).padding(16)
                        .foregroundStyle(.white).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 24).frame(maxHeight: .infinity, alignment: .top).padding(.top, 65)
                        .allowsHitTesting(false)
                }
                if (model.step == .weeding || model.step == .secondWeeding), card.mode == .hidden {
                    ZStack {
                        KoredTool(isDragging: isHoldingKored, swingCount: koredSwingCount)
                            // The render surface includes space for the entire swing;
                            // the enclosing frame still anchors input at the right edge.
                            .frame(width: geometry.size.width, height: geometry.size.height * 0.66)
                            .scaleEffect(x: 1, y: -1)
                            .allowsHitTesting(false)
                        Circle()
                            .stroke(.white.opacity(isHoldingKored ? 0.78 : 0.32), lineWidth: isHoldingKored ? 2 : 1)
                            .frame(width: isHoldingKored ? 34 : 26, height: isHoldingKored ? 34 : 26)
                            .shadow(color: .white.opacity(isHoldingKored ? 0.5 : 0.15), radius: isHoldingKored ? 8 : 3)
                            .offset(x: -28, y: -geometry.size.height * 0.24)
                    }
                    .frame(width: 164, height: geometry.size.height * 0.66 + 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !model.isDemonstrating else { return }
                        cutAtKoredTip(in: geometry.size)
                    }
                    .onLongPressGesture(minimumDuration: 0.35, pressing: { pressing in
                        if !pressing { endKoredHold() }
                    }, perform: {
                        guard !model.isDemonstrating else { return }
                        beginKoredHold(in: geometry.size)
                    })
                    .position(x: geometry.size.width - 82,
                              y: geometry.size.height * 0.33 + (geometry.size.height * 0.66 + 16) / 2)
                    .accessibilityElement()
                    .accessibilityLabel("Kored")
                    .accessibilityHint("Tap atau tahan untuk memotong gulma yang berada di ujung mata kored")
                    .accessibilityIdentifier("field.kored")
                }
            }.contentShape(Rectangle()).coordinateSpace(name: "ngored.field").disabled(model.isDemonstrating)

        }
        .task {
            model.configureLookMotion(reduceMotion: reduceMotion)
            await model.scene.prepareAssets()
            model.scene.showNgoredField()
        }
        .onChange(of: reduceMotion) { _, value in model.configureLookMotion(reduceMotion: value) }
        .onChange(of: scenePhase) { _, value in model.setVisible(value == .active) }
        .onChange(of: card.mode) { _, mode in
            if mode != .hidden { endKoredHold() }
        }
        .onDisappear { endKoredHold() }
        .onChange(of: model.step) { _, step in
            if shouldDismissCard(for: step) { card.dismiss() }
        }
        .task(id: model.removed) {
            if model.step == .cleared || model.step == .secondCleared {
                do { try await Task.sleep(for: .milliseconds(900)) } catch { return }
                card.showInstruction()
            }
        }
    }
}
