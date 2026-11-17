import SwiftUI

struct LeuitDiscoveryView: View {
    struct CardCopy {
        let birth: String
        let marriage: String
        let death: String

        func description(for topic: LeuitDiscoveryViewModel.Topic) -> String {
            switch topic {
            case .birth: birth
            case .marriage: marriage
            case .death: death
            }
        }
    }

    let copy: CardCopy
    let onFinish: () -> Void

    @State private var model = LeuitDiscoveryViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var focus: Focus?

    private enum Focus: Hashable { case reveal, topic }

    private var instruction: String {
        switch model.step {
        case .choosing: "Pilih satu kartu."
        case .awaitingReveal: "Ketuk layar untuk membuka kartu."
        default: ""
        }
    }

    var body: some View {
        ZStack {
            LessonBackdrop(asset: LandscapeState(phase: .ngaleuitkeunPare, isResult: true).assetName)
                .allowsHitTesting(false)
            VStack(spacing: 12) {
                Text(instruction)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(.black.opacity(instruction.isEmpty ? 0 : 0.62), in: Capsule())
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .accessibilityHidden(model.step != .choosing)

                GeometryReader { geometry in
                    cards(in: geometry.size)
                }

                if model.step == .revealed {
                    LessonButton(title: "Selesai", identifier: "leuit.discovery.finish") {
                        if model.finish() { onFinish() }
                    }
                    .frame(maxWidth: 330)
                    .padding(.horizontal, 24)
                } else {
                    Color.clear.frame(height: 48)
                        .accessibilityHidden(true)
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
        .onDisappear { model.reset() }
    }

    private func cards(in size: CGSize) -> some View {
        let spacing: CGFloat = 10
        let smallWidth = max(1, min(110, (size.width - 48 - 2 * spacing) / 3, size.height * 0.27))
        let smallHeight = smallWidth * 4 / 3
        let largeWidth = max(1, min(330, size.width - 48, size.height * 0.82))
        let largeHeight = max(1, min(largeWidth * 1.16, size.height - smallHeight * 0.48))
        let rowY = max(smallHeight / 2, size.height - smallHeight / 2 - 4)

        return ZStack {
            ForEach(LeuitDiscoveryViewModel.Topic.allCases, id: \.self) { topic in
                let isSelected = model.selected == topic
                let isFront = isSelected && [.revealing, .revealed, .finished].contains(model.step)
                let width = isSelected ? largeWidth : smallWidth
                let height = isSelected ? largeHeight : smallHeight

                ZStack {
                    WovenRevealFaces(angle: isFront ? 180 : 0) { _ in
                        ViewThatFits(in: .vertical) {
                            details(for: topic)
                            ScrollView { details(for: topic) }
                        }
                        .padding(20)
                    }
                    .accessibilityHidden(!isFront || model.step != .revealed)
                    .allowsHitTesting(model.step == .revealed)

                    if model.step == .choosing {
                        Button {
                            choose(topic)
                        } label: {
                            Color.clear.contentShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(topic.choiceLabel)
                        .accessibilityIdentifier("leuit.discovery.card.\(topic.rawValue)")
                    }
                }
                .frame(width: width, height: height)
                .position(
                    x: isSelected ? size.width / 2 : size.width / 2 + CGFloat(topic.rawValue - 1) * (smallWidth + spacing),
                    y: isSelected ? largeHeight / 2 : rowY
                )
                .zIndex(isSelected ? 1 : 0)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func details(for topic: LeuitDiscoveryViewModel.Topic) -> some View {
        VStack(spacing: 14) {
            Text(topic.title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.heading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focus, equals: .topic)
            Text(copy.description(for: topic))
                .font(.body)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    private func choose(_ topic: LeuitDiscoveryViewModel.Topic) {
        guard model.step == .choosing else { return }
        let visit = model.visit
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            model.choose(topic)
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

#Preview("Leuit · pilih dan buka satu kartu") {
    LeuitDiscoveryPreview()
}

private struct LeuitDiscoveryPreview: View {
    @State private var visit = 0

    var body: some View {
        let placeholder = "Teks untuk pratinjau. Isi kartu menunggu persetujuan."
        LeuitDiscoveryView(
            copy: .init(birth: placeholder, marriage: placeholder, death: placeholder)
        ) {
            visit += 1
        }
        .id(visit)
    }
}
