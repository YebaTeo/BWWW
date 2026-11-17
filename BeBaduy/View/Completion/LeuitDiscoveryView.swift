import SwiftUI

struct LeuitDiscoveryView: View {
    struct CardCopy {
        let title: String
        let description: String
    }

    let cards: [CardCopy]
    let onFinish: () -> Void

    @State private var model: LeuitDiscoveryViewModel
    @State private var turn = 0.0
    @State private var dragOrigin: Double?
    @GestureState private var isDragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var focus: Focus?

    private enum Focus: Hashable { case reveal, topic }

    init(cards: [CardCopy], onFinish: @escaping () -> Void) {
        self.cards = cards
        self.onFinish = onFinish
        _model = State(initialValue: LeuitDiscoveryViewModel(cardCount: cards.count))
    }

    private var instruction: String {
        switch model.step {
        case .choosing: "Geser ke samping, lalu pilih satu kartu."
        case .awaitingReveal: "Ketuk layar untuk membuka kartu."
        default: ""
        }
    }

    var body: some View {
        ZStack {
            LessonBackdrop(asset: LandscapeState(phase: .ngaleuitkeunPare, isResult: true).assetName)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(instruction.isEmpty ? "Ketuk layar untuk membuka kartu." : instruction)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(.black.opacity(0.62), in: Capsule())
                    .padding(.horizontal, 16)
                    .opacity(instruction.isEmpty ? 0 : 1)
                    .accessibilityHidden(model.step != .choosing)

                GeometryReader { geometry in
                    cardCarousel(in: geometry.size)
                }
                .clipped()

                if model.step == .revealed {
                    LessonButton(title: "Selesai", identifier: "leuit.discovery.finish") {
                        if model.finish() { onFinish() }
                    }
                    .frame(maxWidth: 330)
                    .padding(.horizontal, 24)
                } else {
                    browsingControls
                }
            }
            .padding(.vertical, 12)

            if model.step == .awaitingReveal {
                Button(action: reveal) {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Buka kartu pilihan")
                .accessibilityIdentifier("leuit.discovery.reveal")
                .accessibilityFocused($focus, equals: .reveal)
                .onAppear { focus = .reveal }
            }
        }
        .foregroundStyle(AppTheme.cream)
        .preferredColorScheme(.dark)
        .onChange(of: model.step) { _, step in
            if step == .revealed { focus = .topic }
        }
        .onChange(of: isDragging) { _, dragging in
            if !dragging, dragOrigin != nil { settle(at: turn.rounded()) }
        }
        .onDisappear {
            model.reset()
            dragOrigin = nil
            turn = 0
        }
    }

    private var browsingControls: some View {
        HStack(spacing: 24) {
            browseButton(direction: -1, icon: "chevron.left", label: "Kartu sebelumnya")
            browseButton(direction: 1, icon: "chevron.right", label: "Kartu berikutnya")
        }
        .frame(height: 48)
        .opacity(model.step == .choosing && cards.count > 1 ? 1 : 0)
        .allowsHitTesting(model.step == .choosing && cards.count > 1)
        .accessibilityHidden(model.step != .choosing || cards.count < 2)
    }

    private func browseButton(direction: Double, icon: String, label: String) -> some View {
        Button { settle(at: turn.rounded() + direction) } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.56), in: Circle())
                .overlay(Circle().strokeBorder(AppTheme.heading.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func cardCarousel(in size: CGSize) -> some View {
        let focusedWidth = max(1, min(size.width * 0.75, (size.height - 20) / 1.48, 330))
        let cardTravel = focusedWidth + min(14, size.width * 0.035)
        return LeuitCardCarousel(count: cards.count, turn: turn, size: size,
                                 focusedWidth: focusedWidth, cardTravel: cardTravel) { index, pose in
            card(at: index, pose: pose, in: size)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(carouselDrag(cardTravel: cardTravel),
                             isEnabled: model.step == .choosing && cards.count > 1)
    }

    private func card(at index: Int, pose: LeuitCardPose, in size: CGSize) -> some View {
        let isSelected = model.selected == index
        let isFront = isSelected && [.revealing, .revealed, .finished].contains(model.step)
        let canChoose = model.step == .choosing && pose.distance <= 1.05
        let hidesBehindSelection = model.selected != nil && !isSelected && pose.distance < 0.5

        return ZStack {
            WovenRevealFaces(angle: isFront ? 180 : 0) { _ in
                ViewThatFits(in: .vertical) {
                    details(for: cards[index])
                    ScrollView { details(for: cards[index]) }
                }
                .padding(20)
            }
            .accessibilityHidden(!isFront || model.step != .revealed)
            .allowsHitTesting(model.step == .revealed && isSelected)

            if canChoose {
                Button { choose(index) } label: {
                    Color.clear.contentShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pilih kartu \(index + 1)")
                .accessibilityIdentifier("leuit.discovery.card.\(index)")
            }
        }
        .frame(width: isSelected ? min(330, max(1, size.width - 48)) : pose.width,
               height: isSelected ? min(475, max(1, size.height - 16)) : pose.height)
        .position(x: isSelected ? size.width / 2 : pose.x,
                  y: isSelected ? size.height / 2 : pose.y + (model.selected == nil ? 0 : 24))
        .opacity(hidesBehindSelection ? 0 : (isSelected || model.selected == nil ? 1 : 0.30))
        .zIndex(isSelected ? 2 : 1 - pose.distance)
    }

    private func carouselDrag(cardTravel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($isDragging) { value, active, _ in
                if abs(value.translation.width) > abs(value.translation.height) { active = true }
            }
            .onChanged { value in
                guard model.step == .choosing,
                      dragOrigin != nil || abs(value.translation.width) > abs(value.translation.height) else { return }
                if dragOrigin == nil { dragOrigin = turn }
                if !reduceMotion, let dragOrigin { turn = dragOrigin - value.translation.width / cardTravel }
            }
            .onEnded { value in
                guard let dragOrigin, model.step == .choosing else { return }
                let distance = value.translation.width
                let projected = value.predictedEndTranslation.width
                let delta = abs(distance) >= cardTravel / 2 ? distance : projected
                let steps = max(-2, min(2, (delta / cardTravel).rounded()))
                settle(at: dragOrigin.rounded() - steps)
            }
    }

    private func settle(at destination: Double) {
        dragOrigin = nil
        withAnimation(reduceMotion ? nil : .spring(duration: 0.30, bounce: 0.10)) {
            turn = destination
        }
    }

    private func details(for card: CardCopy) -> some View {
        VStack(spacing: 14) {
            Text(card.title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.heading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focus, equals: .topic)
            Text(card.description)
                .font(.body)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    private func choose(_ index: Int) {
        guard model.step == .choosing, dragOrigin == nil else { return }
        let visit = model.visit
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            model.choose(index)
        } completion: {
            model.finishMoving(visit: visit)
        }
    }

    private func reveal() {
        guard model.step == .awaitingReveal else { return }
        let visit = model.visit
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
            model.reveal()
        } completion: {
            model.finishRevealing(visit: visit)
        }
    }
}

private struct LeuitCardPose {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let distance: Double
}

/// Wraps positions outside the visible row so swipes can continue in either direction.
private struct LeuitCardCarousel<Content: View>: View, Animatable {
    let count: Int
    nonisolated var turn: Double
    let size: CGSize
    let focusedWidth: CGFloat
    let cardTravel: CGFloat
    @ViewBuilder var content: (Int, LeuitCardPose) -> Content

    nonisolated var animatableData: Double {
        get { turn }
        set { turn = newValue }
    }

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let offset = (Double(index) - turn).remainder(dividingBy: Double(count))
                let distance = abs(offset)
                let width = focusedWidth * (1 - 0.07 * min(distance, 1))
                content(index, LeuitCardPose(
                    x: size.width / 2 + cardTravel * offset,
                    y: size.height / 2,
                    width: width,
                    height: width * 1.48,
                    distance: distance
                ))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

#Preview("Leuit · pilih kartu") {
    LeuitDiscoveryPreview()
}

private struct LeuitDiscoveryPreview: View {
    @State private var visit = 0

    var body: some View {
        let titles = ["Kelahiran", "Pernikahan", "Kematian", "Kartu 4", "Kartu 5", "Kartu 6", "Kartu 7"]
        LeuitDiscoveryView(cards: titles.map {
            .init(title: $0, description: "Isi kartu akan ditambahkan.")
        }) {
            visit += 1
        }
        .id(visit)
    }
}
