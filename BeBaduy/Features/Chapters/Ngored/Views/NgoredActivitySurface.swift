import SwiftUI
struct NgoredActivitySurface: View {
    let model: NgoredViewModel
    @Environment(\.activitySceneInsets) private var sceneInsets
    @Environment(ActivityCardState.self) private var card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var showsTouchTargets = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var swingCount = 0
    @State private var struckWeed: Int?

    private var isWeeding: Bool {
        model.step == .weeding || model.step == .secondWeeding
    }

    private var currentWeedTargets: Range<Int> {
        model.step == .secondWeeding ? 4..<7 : 0..<4
    }

    private func swipeWeed(from start: CGPoint, to end: CGPoint) -> Bool {
        guard isWeeding, card.mode == .hidden, !model.isDemonstrating else { return false }
        var closest: (index: Int, distance: CGFloat)?
        for index in currentWeedTargets where !model.removed.contains(index) {
            guard let area = model.scene.ngoredWeedHitArea(at: index),
                  let distance = KoredStrokeTracker.hitDistance(from: start, to: end, in: area) else { continue }
            if distance < (closest?.distance ?? .infinity) { closest = (index, distance) }
        }
        guard let closest else { return false }
        strike(closest.index)
        return true
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
                TimelineView(.animation(minimumInterval: 0.05, paused: scenePhase != .active || !isWeeding)) { _ in
                    ForEach(Array(currentWeedTargets), id: \.self) { index in
                        let cut = model.removed.contains(index)
                        if isWeeding, !cut, let pt = model.scene.projectedNgoredWeedPoint(at: index),
                           CGRect(origin: .zero, size: geometry.size).contains(pt) {
                            Text("Gulma")
                                .font(.caption.monospacedDigit().bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.black.opacity(0.62), in: Capsule())
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Gulma \(index + 1)")
                                .accessibilityHint("Usap sekali untuk mencabut")
                                .accessibilityIdentifier("field.weed.\(index)")
                                .accessibilityAction(named: "Sapukan kored") { strike(index) }
                                .position(pt)
                                .allowsHitTesting(false)
                        }
                    }
                }
                if isWeeding && card.mode == .hidden {
                    KoredDragHandle { start, end in
                        swipeWeed(from: start, to: end)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                if isWeeding && card.mode == .hidden {
                    ActivityCardLayout(placement: .bottom, sceneInsets: sceneInsets) {
                        ActivityCardPanel(passesTouchesThrough: true) {
                            Text("Usap sekali untuk mencabut gulma")
                            let removedCount = currentWeedTargets.filter { model.removed.contains($0) }.count
                            Text("Rumput dicabut: \(removedCount)/\(currentWeedTargets.count)").font(.subheadline)
                            if model.session.feedback.hasPrefix("Ini padi") {
                                Text(model.session.feedback).font(.subheadline.bold())
                                    .accessibilityIdentifier("ngored.rice.feedback")
                            }
                        }
                        if model.needsTouchTargets || voiceOverEnabled || showsTouchTargets {
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    ForEach(Array(currentWeedTargets), id: \.self) { index in
                                        Button("Sapukan gulma \(index + 1)") { strike(index) }
                                            .disabled(model.removed.contains(index))
                                            .font(.caption.weight(.semibold))
                                            .padding(9)
                                            .background(.brown.opacity(0.85), in: Capsule())
                                    }
                                }
                            }
                        } else {
                            Button("Gunakan tombol target") { showsTouchTargets = true }
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
                if !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: struckWeed == nil || scenePhase != .active)) { _ in
                        let point = struckWeed.flatMap { model.scene.projectedNgoredWeedPoint(at: $0) }
                        let visible = point != nil && scenePhase == .active
                        Kored3DView(isVisible: visible, swingCount: swingCount, bladeCentered: true)
                            .frame(width: 300, height: 300)
                            .scaleEffect(x: 1, y: -1)
                            .position(x: point?.x ?? 0, y: (point?.y ?? 0) - 24)
                            .opacity(visible ? 1 : 0)
                    }
                    .allowsHitTesting(false)
                }
                if model.scene.loadingAssets {
                    ReusableLoadingView(
                        message: "Menyiapkan lahan…",
                        style: .fullscreen(backdrop: "LaunchLandscape"),
                        identifier: "ngored.loading"
                    )
                } else if let error = model.scene.assetError {
                    LessonBackdrop(asset: "LaunchLandscape")
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        Text(error)
                        Button("Coba lagi") {
                            Task { await model.scene.prepareAssets() }
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(24)
                    .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 20))
                    .padding(24)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .disabled(model.isDemonstrating)

        }
        .task {
            model.configureLookMotion(reduceMotion: reduceMotion)
            await model.scene.prepareAssets()
        }
        .onChange(of: reduceMotion) { _, value in model.configureLookMotion(reduceMotion: value) }
        .task(id: swingCount) {
            guard struckWeed != nil else { return }
            do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
            struckWeed = nil
        }
        .onChange(of: model.step) { _, step in
            if step == .rain || step == .finalRain { card.dismiss() }
        }
        .onChange(of: card.mode) { _, mode in
            if mode == .hidden { model.beginInitialRainAfterCard() }
        }
        .task(id: model.removed) {
            if model.step == .cleared || model.step == .secondCleared {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                model.observeRain()
            }
        }
    }
}
