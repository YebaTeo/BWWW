import SwiftUI
struct NgoredActivitySurface: View {
    let model: NgoredViewModel
    @Environment(ActivityCardState.self) private var card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var swingCount = 0
    @State private var struckWeed: Int?

    private var isWeeding: Bool {
        model.step == .weeding
    }

    private func swipeWeed(along path: [CGPoint], in size: CGSize) {
        guard isWeeding, card.mode == .hidden, !model.isDemonstrating else { return }
        let points = model.scene.projectedNgoredWeedPoints()
        let range = 0..<4
        var closest: (index: Int, distance: CGFloat)?
        for index in range where points.indices.contains(index) && !model.removed.contains(index) {
            let point = points[index]
            guard CGRect(origin: .zero, size: size).contains(point) else { continue }
            // Include the leaves above the projected root when testing a swipe.
            let center = CGPoint(x: point.x, y: point.y - 24)
            for (start, end) in zip(path, path.dropFirst()) {
                let dx = end.x - start.x
                let dy = end.y - start.y
                let lengthSquared = dx * dx + dy * dy
                guard lengthSquared > 0 else { continue }
                let t = min(1, max(0, ((center.x - start.x) * dx + (center.y - start.y) * dy) / lengthSquared))
                let distance = hypot(center.x - start.x - t * dx, center.y - start.y - t * dy)
                if distance < (closest?.distance ?? 42) { closest = (index, distance) }
            }
        }
        if let closest { strike(closest.index) }
    }

    private func strike(_ index: Int) {
        guard isWeeding, !model.removed.contains(index), !model.isDemonstrating else { return }
        struckWeed = index
        swingCount += 1
        model.remove(index)
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
                ForEach(0..<4) { index in
                        let cut = model.removed.contains(index)
                        let hits = model.strokes[index] ?? 0
                        if isWeeding, !cut, points.indices.contains(index) {
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
                                    .accessibilityAction(named: "Sapukan kored") { strike(index) }
                                    .position(pt)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
                if isWeeding && card.mode == .hidden {
                    KoredDragHandle { start, end in
                        swipeWeed(along: [start, end], in: geometry.size)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                if model.step == .weeding {
                    Button { model.remove(8) } label: {
                        Label("Padi · pertahankan", systemImage: "leaf")
                            .font(.subheadline.weight(.semibold)).padding(12)
                            .foregroundStyle(.white).background(.black.opacity(0.7), in: Capsule())
                    }.accessibilityIdentifier("field.rice")
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.43)
                    VStack(spacing: 6) {
                        Text("Usap gulma untuk menyapukan kored").font(.headline)
                        Text("Rumput dicabut: \(model.removed.count)/4").font(.subheadline)
                        if model.session.feedback.hasPrefix("Ini padi") {
                            Text(model.session.feedback).font(.subheadline.bold())
                                .accessibilityIdentifier("ngored.rice.feedback")
                        }
                    }.multilineTextAlignment(.center).padding(16)
                        .foregroundStyle(.white).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 24).frame(maxHeight: .infinity, alignment: .top).padding(.top, 65)
                        .allowsHitTesting(false)
                }
                if let struckWeed, !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: scenePhase != .active)) { _ in
                        let roots = model.scene.projectedNgoredWeedPoints(height: 0)
                        if roots.indices.contains(struckWeed), roots[struckWeed].x >= 0 {
                            let root = roots[struckWeed]
                            KoredTool(swingCount: swingCount)
                                .frame(width: 210, height: 240)
                                .scaleEffect(x: 1, y: -1)
                                .position(x: root.x + 32, y: root.y - 20)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .disabled(model.isDemonstrating)

        }
        .task {
            model.configureLookMotion(reduceMotion: reduceMotion)
            await model.scene.prepareAssets()
            model.scene.showNgoredField()
        }
        .onChange(of: reduceMotion) { _, value in model.configureLookMotion(reduceMotion: value) }
        .task(id: swingCount) {
            guard struckWeed != nil else { return }
            do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
            struckWeed = nil
        }
        .onChange(of: model.step) { _, step in
            if step == .rain { card.dismiss() }
        }
        .task(id: model.removed) {
            if model.step == .cleared {
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                model.observeRain()
            }
        }
    }
}
