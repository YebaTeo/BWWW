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
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            VStack(alignment: .leading, spacing: 0) {
                Image(card.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width - 12, height: geometry.size.height * 0.63)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .padding(6)
                    .accessibilityHidden(true)
                Text(card.title)
                    .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 16 : 14,
                                  weight: .bold, design: .rounded))
                    .foregroundStyle(CollectionCardPalette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                Spacer(minLength: 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(CollectionCardPalette.paper, in: shape)
            .overlay(alignment: .bottomTrailing) {
                UnevenRoundedRectangle(topLeadingRadius: 15, bottomTrailingRadius: 10)
                    .fill(AppTheme.orange)
                    .frame(width: 39, height: 16)
                    .allowsHitTesting(false)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    isHighlighted ? Color(red: 1, green: 0.86, blue: 0.45) : AppTheme.orange,
                    lineWidth: isHighlighted ? 2.5 : 1.5
                )
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

private enum CollectionCardPalette {
    static let paper = Color(red: 1, green: 0.95, blue: 0.87)
    static let ink = Color(red: 0.26, green: 0.14, blue: 0.08)
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
                isFaceUp = true
                return
            }
            do { try await Task.sleep(for: .milliseconds(420)) } catch { return }
            withAnimation(.easeInOut(duration: 0.62)) { isFaceUp = true }
        }
    }
}

private struct CollectionCardDetails: View {
    let card: ChapterCard
    let size: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(card.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: size.width - 18, height: size.height * 0.53)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(9)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text(card.title)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(CollectionCardPalette.ink)
                    .accessibilityAddTraits(.isHeader)
                ViewThatFits(in: .vertical) {
                    explanationText
                        .fixedSize(horizontal: false, vertical: true)
                    ScrollView {
                        explanationText
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .frame(width: size.width, height: size.height)
        .background(CollectionCardPalette.paper)
        .overlay(alignment: .bottomTrailing) {
            UnevenRoundedRectangle(topLeadingRadius: 24, bottomTrailingRadius: 18)
                .fill(AppTheme.orange)
                .frame(width: 74, height: 27)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var explanationText: some View {
        Text(card.explanation)
            .font(.system(size: 15))
            .foregroundStyle(Color(red: 0.25, green: 0.17, blue: 0.11))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("collection.card.explanation")
    }
}

struct ChapterCardFace: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let card: ChapterCard
    let width: CGFloat
    var front = true
    var compact = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(.linearGradient(colors: card == .epic ? [.indigo, .black, .purple] : [.brown, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
            if front {
                VStack(spacing: 8) {
                    Image(card.imageName)
                        .resizable().scaledToFill()
                        .frame(width: width - 24, height: width * (compact ? 0.65 : 0.32)).clipped()
                        .accessibilityHidden(true)
                    Text(card.title)
                        .font(compact ? .headline : .title2.bold()).accessibilityAddTraits(.isHeader)
                    if !compact {
                        ScrollView {
                            Text(card.explanation)
                                .multilineTextAlignment(.center).padding(.horizontal)
                        }
                        .accessibilityIdentifier("lesson.explanation.page")
                    }
                }
                .padding(.vertical)
            } else {
                Image(systemName: "leaf.fill").font(.largeTitle).foregroundStyle(.yellow)
            }
        }
        .frame(width: width, height: width / (compact && dynamicTypeSize.isAccessibilitySize ? 0.58 : 0.7))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(
            .linearGradient(colors: card == .epic ? [.cyan, .white, .purple, .yellow] : [.yellow, .white, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3) }
        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
        .foregroundStyle(.white)
    }
}
