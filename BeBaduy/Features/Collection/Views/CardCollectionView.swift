import SwiftUI

/// Items are earned when the corresponding phase is completed and persisted.
struct CardCollectionView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let journey: JourneyViewModel
    var showsBackground = true
    var isActive = true
    let onSelect: (ChapterCard) -> Void
    let onScroll: (CGFloat, CGFloat) -> Void
    @State private var isUserScrolling = false
    @State private var isArranging = false
    @State private var arrangedCards: Set<ChapterCard> = []
    @State private var highlightedCards: Set<ChapterCard> = []
    @State private var arrangementRunID = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Koleksi Kartu")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                    Text("Selesaikan tahapan Ngahuma dan lengkapi kartumu.")
                        .font(.system(size: 16))
                        .italic()
                        .lineSpacing(3)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 4, y: 2)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 20),
                                    GridItem(.flexible(), spacing: 20)], spacing: 24) {
                    ForEach(Array(ChapterCard.all.enumerated()), id: \.element.id) { index, card in
                        let isEarned = card.isEarned(in: journey.progress)
                        if isEarned {
                            let isRevealed = !isArranging || arrangedCards.contains(card)
                            let isHighlighted = highlightedCards.contains(card)
                            let column = index % 2
                            let row = index / 2
                            Button { onSelect(card) } label: {
                                collectionTile(for: card, isHighlighted: isHighlighted)
                            }
                            .buttonStyle(.plain)
                            .offset(
                                x: isRevealed ? 0 : (column == 0 ? 44 : -44),
                                y: isRevealed ? 0 : 48 + CGFloat(row) * 18
                            )
                            .rotationEffect(isRevealed ? .zero : .degrees(column == 0 ? -7 : 7))
                            .scaleEffect(isRevealed ? 1 : 0.80)
                            .opacity(isRevealed ? 1 : 0)
                            .accessibilityIdentifier("collection.card.\(card.imageName)")
                            .accessibilityLabel(card.title)
                        } else {
                            lockedTile
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Kartu terkunci")
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 24)
            .padding(.bottom, 100)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .onScrollGeometryChange(for: Int.self) { geometry in
            Int((geometry.contentOffset.y + geometry.contentInsets.top) / 12)
        } action: { oldOffset, newOffset in
            guard isUserScrolling else { return }
            onScroll(CGFloat(oldOffset * 12), CGFloat(newOffset * 12))
        }
        .onScrollPhaseChange { _, newPhase in
            isUserScrolling = newPhase == .interacting
        }
        .background {
            if showsBackground { CollectionSoilBackground() }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: isActive, initial: true) { _, active in
            guard active else {
                isArranging = false
                arrangedCards.removeAll()
                highlightedCards.removeAll()
                return
            }
            guard journey.hasPendingCollectionArrangement else { return }
            let pending = Set(journey.pendingCollectionCards)
            journey.markCollectionArrangementSeen()
            guard !reduceMotion else { return }
            highlightedCards = pending
            arrangedCards = []
            isArranging = true
            arrangementRunID = UUID()
        }
        .task(id: arrangementRunID) {
            guard isArranging, isActive else { return }
            let earned = ChapterCard.all.filter { $0.isEarned(in: journey.progress) }
            guard !earned.isEmpty else {
                isArranging = false
                return
            }
            // Wait one beat for the tab switch to settle before dealing all earned cards.
            do { try await Task.sleep(for: .milliseconds(110)) } catch { return }
            let stepDelaysMs: [Int] = [0, 75, 60, 50, 40, 35, 30]
            for (index, card) in earned.enumerated() {
                let stepMs = stepDelaysMs[min(index, stepDelaysMs.count - 1)]
                if stepMs > 0 {
                    do { try await Task.sleep(for: .milliseconds(stepMs)) } catch { return }
                }
                withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                    _ = arrangedCards.insert(card)
                }
            }
            do { try await Task.sleep(for: .milliseconds(520)) } catch { return }
            withAnimation(.easeOut(duration: 0.35)) {
                highlightedCards.removeAll()
            }
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            isArranging = false
        }
    }

    private func collectionTile(for card: ChapterCard, isHighlighted: Bool) -> some View {
        GeometryReader { geometry in
            CollectionCardDetails(card: card, size: geometry.size, preview: true)
                .overlay {
                    if isHighlighted {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(.yellow, lineWidth: 2)
                    }
                }
            .shadow(color: isHighlighted ? AppTheme.orange.opacity(0.65) : .clear, radius: isHighlighted ? 12 : 0)
        }
        .aspectRatio(0.75, contentMode: .fit)
    }

    private var lockedTile: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(red: 0.66, green: 0.38, blue: 0.15).opacity(0.12))
            .overlay {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.orange)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppTheme.orange.opacity(0.75), lineWidth: 1)
            }
            .aspectRatio(0.75, contentMode: .fit)
    }
}

private struct CollectionSoilBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Image("JourneySoil")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                Image("JourneyLandscapeSoil")
                    .resizable()
                    .frame(width: geometry.size.width, height: geometry.size.height * 1.9)
                    .offset(y: -geometry.size.height)
                    .frame(width: geometry.size.width, height: 100, alignment: .top)
                    .clipped()
                    .mask {
                        LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct CollectionCardPresentation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let card: ChapterCard
    let dismiss: () -> Void
    @State private var isFaceUp = false

    var body: some View {
        GeometryReader { geometry in
            let width = min(350, geometry.size.width - 52,
                            max(180, (geometry.size.height - 150) * 0.75))
            ZStack {
                Color.black.opacity(0.76)
                    .ignoresSafeArea()
                    .onTapGesture(perform: dismiss)

                WovenRevealFaces(angle: isFaceUp ? 180 : 0) { size in
                    CollectionCardDetails(card: card, size: size)
                }
                .frame(width: width, height: width * 4 / 3)
                .shadow(color: .black.opacity(0.65), radius: 20, y: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.8), in: Circle())
                }
                .accessibilityLabel("Tutup kartu")
                .accessibilityIdentifier("collection.card.close")
                .padding(.top, max(geometry.safeAreaInsets.top, 20) + 14)
                .padding(.trailing, 24)
            }
        }
        .ignoresSafeArea()
        .task(id: card) {
            if reduceMotion {
                ActivityAudio.shared.play(.cardFlip)
                isFaceUp = true
                return
            }
            do { try await Task.sleep(for: .milliseconds(420)) } catch { return }
            ActivityAudio.shared.play(.cardFlip)
            withAnimation(.easeInOut(duration: 0.62)) { isFaceUp = true }
        }
    }
}

private struct CollectionCardDetails: View {
    let card: ChapterCard
    let size: CGSize

    var preview = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if card.isTool {
            toolCardBody
        } else {
            standardCardBody
        }
    }

    @ViewBuilder private var toolCardBody: some View {
        let scale = size.width / 336
        let shape = RoundedRectangle(cornerRadius: preview ? 10 : 18, style: .continuous)
        ZStack {
            Color(red: 0.17, green: 0.13, blue: 0.12)
            if preview {
                VStack(spacing: 8 * scale) {
                    Text(card.title)
                        .font(typeSize.isAccessibilitySize ? .headline : .system(size: max(15, size.width * 0.115), weight: .bold))
                        .foregroundStyle(AppTheme.heading)
                        .accessibilityAddTraits(.isHeader)

                    toolArtwork
                        .frame(maxWidth: .infinity)
                        .frame(height: size.height * 0.56)
                        .accessibilityHidden(true)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12 * scale)
                .padding(.vertical, 14 * scale)
            } else {
                let illustrationHeight = size.height * 0.46
                ViewThatFits(in: .vertical) {
                    toolDetails(illustrationHeight: illustrationHeight)
                    ScrollView { toolDetails(illustrationHeight: illustrationHeight) }
                        .scrollEdgeEffectHidden()
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay {
            if preview {
                shape.strokeBorder(AppTheme.heading.opacity(0.6), lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
        }
    }

    private func toolDetails(illustrationHeight: CGFloat) -> some View {
        VStack(spacing: 16) {
            Text(card.title)
                .font(.title.bold())
                .foregroundStyle(AppTheme.heading)
                .accessibilityAddTraits(.isHeader)

            toolArtwork
                .frame(maxWidth: .infinity)
                .frame(height: illustrationHeight)
                .accessibilityHidden(true)

            Text(card.description)
                .font(.body)
                .foregroundStyle(AppTheme.cream)
                .accessibilityIdentifier("collection.card.explanation")
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var toolArtwork: some View {
        let scale = size.width / 336
        switch card {
        case .aseuk:
            AseukTool(interactive: !preview, autoRotate: !preview)
                .frame(width: preview ? size.width * 0.26 : 68 * scale)
        case .kored:
            KoredTool()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .etem:
            Image("mipit_etem")
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: preview ? size.width * 0.72 : 160 * scale,
                    maxHeight: preview ? size.height * 0.50 : 140 * scale
                )
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var standardCardBody: some View {
        let scale = size.width / 336
        ZStack(alignment: .topLeading) {
            Image(card.level == .epic ? "CardBaseEpic" : "CardBaseNormal")
                .resizable()
                .accessibilityHidden(true)
            artwork
                .frame(width: size.width, height: size.height, alignment: .top)
                .mask {
                    CardIllustrationWindow()
                        .padding(.horizontal, 3 * scale)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6 * scale) {
                if preview {
                    title
                } else {
                    ViewThatFits(in: .vertical) {
                        detailText.fixedSize(horizontal: false, vertical: true)
                        ScrollView { detailText }
                            .scrollEdgeEffectHidden()
                    }
                }
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 18 * scale)
            .padding(.top, size.height * 0.645)
            .padding(.bottom, 12 * scale)
        }
        .frame(width: size.width, height: size.height)
        .mask {
            Image(card.level == .epic ? "CardBaseEpic" : "CardBaseNormal")
                .resizable()
        }
    }

    private var detailText: some View {
        VStack(alignment: .leading, spacing: 6 * size.width / 336) {
            title
            Text(card.description)
                .font(typeSize.isAccessibilitySize ? .body : .system(size: 16 * size.width / 336))
                .accessibilityIdentifier("collection.card.explanation")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: some View {
        Text(card.title)
            .font(typeSize.isAccessibilitySize ? .headline : .system(size: max(13, size.width * 0.074), weight: .bold))
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var artwork: some View {
        switch card {
        case .lebu, .ngubaran, .pungpuhunan, .garu:
            Image(card.artwork).resizable().scaledToFit()
                .frame(width: size.width * (card == .lebu ? 0.87 : 0.67), height: size.height * 0.46)
                .padding(.top, size.height * 0.10)
        default:
            Image(card.artwork).resizable().scaledToFill()
                .frame(width: size.width, height: size.height * 0.61, alignment: .top)
                .clipped()
        }
    }
}

// The window follows the two wavy edges of the supplied 336 × 447 base.
private struct CardIllustrationWindow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 1, y: 108))
        func curve(_ x: CGFloat, _ y: CGFloat, _ a: CGPoint, _ b: CGPoint) {
            path.addCurve(to: CGPoint(x: x, y: y), control1: a, control2: b)
        }
        curve(77, 47, .init(x: 24,y: 117), .init(x: 29,y: 48))
        curve(148, 17, .init(x: 117,y: 47), .init(x: 132,y: 34))
        curve(241, 36, .init(x: 178,y: 34), .init(x: 204,y: 48))
        curve(335, 58, .init(x: 292,y: 22), .init(x: 308,y: 29))
        path.addLine(to: CGPoint(x: 335,y: 212))
        curve(245, 249, .init(x: 307,y: 217), .init(x: 295,y: 255))
        curve(146, 268, .init(x: 204,y: 245), .init(x: 184,y: 269))
        curve(54, 243, .init(x: 112,y: 267), .init(x: 79,y: 245))
        curve(1, 257, .init(x: 34,y: 240), .init(x: 10,y: 245))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: rect.width / 336, y: rect.height / 447))
    }
}

struct ChapterCardFace: View {
    let card: ChapterCard
    let width: CGFloat
    var front = true

    var body: some View {
        Group {
            if front {
                CollectionCardDetails(card: card, size: CGSize(width: width, height: width * 4 / 3))
            } else {
                let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                Image("ToolRevealWeave")
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: width * 4 / 3)
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.75)
                            .allowsHitTesting(false)
                    }
                    .accessibilityHidden(true)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
    }
}
