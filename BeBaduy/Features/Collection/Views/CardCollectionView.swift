import SwiftUI

/// Items are earned when the corresponding phase is completed and persisted.
struct CardCollectionView: View {
    let journey: JourneyViewModel
    var showsBackground = true
    let onScroll: (CGFloat, CGFloat) -> Void
    @State private var isUserScrolling = false

    private var earned: [ChapterCard] {
        ChapterCard.all.filter { $0.isEarned(in: journey.progress) }
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(red: 0.16, green: 0.09, blue: 0.06).opacity(0.96))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(AppTheme.heading.opacity(0.6), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.38), radius: 14, y: 8)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("\(earned.count) dari \(ChapterCard.all.count) kartu terkumpul")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.cream)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.5), in: Capsule())
                if earned.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 38))
                            .foregroundStyle(AppTheme.heading)
                        Text("Koleksimu belum terisi")
                            .font(.headline)
                            .foregroundStyle(AppTheme.cream)
                        Text("Selesaikan tahapan Ngahuma untuk mendapatkan kartu koleksi.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.cream.opacity(0.82))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 230)
                    .padding(18)
                    .background { cardSurface }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                        ForEach(earned) { card in
                            NavigationLink {
                                GeometryReader { bounds in
                                    let width = min(330, bounds.size.width * 0.88, bounds.size.height * 0.65)
                                    ChapterCardFace(card: card, width: width)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .navigationTitle(card.title)
                                .navigationBarTitleDisplayMode(.inline)
                            } label: {
                                GeometryReader { bounds in
                                    ChapterCardFace(card: card, width: bounds.size.width, compact: true)
                                }
                                .aspectRatio(0.7, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(card.title)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 700)
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
        .background { if showsBackground { MenuBackground(progress: journey.progress) } }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Koleksi Kartu")
    }
}

struct ChapterCardFace: View {
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
        .frame(width: width, height: width / 0.7)
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(
            .linearGradient(colors: card == .epic ? [.cyan, .white, .purple, .yellow] : [.yellow, .white, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3) }
        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
        .foregroundStyle(.white)
    }
}
