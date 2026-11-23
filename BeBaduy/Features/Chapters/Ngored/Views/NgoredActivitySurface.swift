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
                NgoredWeedBadgesView(
                    scene: model.scene,
                    targets: currentWeedTargets,
                    removed: model.removed,
                    isVisible: isWeeding && scenePhase == .active,
                    onStrike: strike
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                if isWeeding && card.mode == .hidden {
                    KoredDragHandle { start, end in
                        swipeWeed(from: start, to: end)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                if isWeeding && card.mode == .hidden {
                    ActivityCardLayout(placement: .bottom, sceneInsets: sceneInsets) {
                        let removedCount = currentWeedTargets.filter { model.removed.contains($0) }.count
                        Text("Rumput dicabut: \(removedCount)/\(currentWeedTargets.count)").activityCounterStyle()
                        ActivityCardPanel(passesTouchesThrough: true) {
                            Text("Usap sekali untuk mencabut gulma")
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
                if card.mode == .hidden, model.session.isActive,
                   !model.scene.loadingAssets, model.scene.assetError == nil {
                    Button(action: model.recenterLook) {
                        Label("Pusatkan", systemImage: "scope")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(Color.brown.opacity(0.85), in: Capsule())
                    }
                    .accessibilityLabel("Pusatkan pandangan")
                    .accessibilityIdentifier("ngored.recenter")
                    .padding(.top, sceneInsets.top)
                    .padding(.trailing, sceneInsets.trailing + 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                if model.scene.loadingAssets {
                    ReusableLoadingView(
                        message: "Menyiapkan lahan…",
                        style: .fullscreen,
                        identifier: "ngored.loading"
                    )
                } else if let error = model.scene.assetError {
                    Color(red: 0.14, green: 0.09, blue: 0.06)
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

private struct NgoredWeedBadgesView: UIViewRepresentable {
    let scene: NgahumaScene
    let targets: Range<Int>
    let removed: Set<Int>
    let isVisible: Bool
    let onStrike: @MainActor (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(scene: scene) }

    func makeUIView(context: Context) -> OverlayContainerView {
        let view = OverlayContainerView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        context.coordinator.attach(to: view)
        context.coordinator.update(targets: targets, removed: removed, isVisible: isVisible, onStrike: onStrike)
        return view
    }

    func updateUIView(_ uiView: OverlayContainerView, context: Context) {
        context.coordinator.update(targets: targets, removed: removed, isVisible: isVisible, onStrike: onStrike)
    }

    static func dismantleUIView(_ uiView: OverlayContainerView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class OverlayContainerView: UIView {
        var onLayout: (() -> Void)?
        override func layoutSubviews() {
            super.layoutSubviews()
            onLayout?()
        }
    }

    @MainActor
    final class Coordinator {
        private let scene: NgahumaScene
        private weak var container: OverlayContainerView?
        private var badges: [Int: WeedBadgeView] = [:]
        private var targets: Range<Int> = 0..<0
        private var removed: Set<Int> = []
        private var isVisible = false
        private var onStrike: (@MainActor (Int) -> Void)?

        init(scene: NgahumaScene) {
            self.scene = scene
        }

        func attach(to view: OverlayContainerView) {
            container = view
            view.onLayout = { [weak self] in self?.syncPositions() }
            scene.onCameraUpdated = { [weak self] in self?.syncPositions() }
        }

        func update(targets: Range<Int>, removed: Set<Int>, isVisible: Bool, onStrike: @escaping @MainActor (Int) -> Void) {
            self.targets = targets
            self.removed = removed
            self.isVisible = isVisible
            self.onStrike = onStrike
            if scene.onCameraUpdated == nil {
                scene.onCameraUpdated = { [weak self] in self?.syncPositions() }
            }
            syncPositions()
        }

        func detach() {
            scene.onCameraUpdated = nil
            container?.onLayout = nil
            container = nil
        }

        func syncPositions() {
            guard let container else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }

            guard isVisible, container.bounds.width > 1, container.bounds.height > 1 else {
                for badge in badges.values {
                    badge.isHidden = true
                    badge.isAccessibilityElement = false
                }
                return
            }

            let activeIndices = Set(targets)
            for (index, badge) in badges where !activeIndices.contains(index) {
                badge.isHidden = true
                badge.isAccessibilityElement = false
            }

            for index in targets {
                guard !removed.contains(index),
                      let point = scene.projectedNgoredWeedPoint(at: index, in: container.bounds),
                      container.bounds.contains(point) else {
                    badges[index]?.isHidden = true
                    badges[index]?.isAccessibilityElement = false
                    continue
                }
                let badge = badgeView(for: index, in: container)
                badge.isHidden = false
                badge.isAccessibilityElement = true
                badge.center = point
            }
        }

        private func badgeView(for index: Int, in container: UIView) -> WeedBadgeView {
            if let existing = badges[index] { return existing }
            let badge = WeedBadgeView(index: index) { [weak self] weedIndex in
                self?.onStrike?(weedIndex)
            }
            container.addSubview(badge)
            badges[index] = badge
            return badge
        }
    }

    private final class WeedBadgeView: UIView {
        private let label = UILabel()

        init(index: Int, onAction: @escaping @MainActor (Int) -> Void) {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = UIColor.black.withAlphaComponent(0.62)
            layer.cornerCurve = .continuous

            let baseDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1)
            let descriptor = baseDescriptor.withSymbolicTraits(.traitBold) ?? baseDescriptor
            label.font = UIFont(descriptor: descriptor, size: 0)
            label.adjustsFontForContentSizeCategory = true
            label.text = "Gulma"
            label.textColor = .white
            label.sizeToFit()
            addSubview(label)

            let size = CGSize(width: label.bounds.width + 16, height: label.bounds.height + 8)
            bounds = CGRect(origin: .zero, size: size)
            label.center = CGPoint(x: size.width / 2, y: size.height / 2)
            layer.cornerRadius = size.height / 2

            isAccessibilityElement = true
            accessibilityLabel = "Gulma \(index + 1)"
            accessibilityHint = "Usap sekali untuk mencabut"
            accessibilityIdentifier = "field.weed.\(index)"
            accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: "Sapukan kored") { _ in
                    onAction(index)
                    return true
                }
            ]
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }
    }
}
