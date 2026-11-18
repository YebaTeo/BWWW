import SwiftUI

/// Items are earned when the corresponding phase is completed and persisted.
struct CardCollectionView: View {
    let journey: JourneyViewModel
    let onScroll: (CGFloat, CGFloat) -> Void
    @State private var isUserScrolling = false

    private struct Item: Identifiable {
        let id: PhaseID
        let name: String
        let symbol: String
        let description: String
    }

    private let items: [Item] = [
        Item(id: .narawas, name: "Golok", symbol: "leaf.fill", description: "Alat untuk membersihkan lahan pada tahap Narawas."),
        Item(id: .ngaseuk, name: "Aseuk", symbol: "leaf.arrow.triangle.circlepath", description: "Tongkat kayu untuk membuat lubang tanam benih pare."),
        Item(id: .ngored, name: "Kored", symbol: "leaf.circle.fill", description: "Alat untuk membersihkan gulma di sekitar pare."),
        Item(id: .mipit, name: "Etem", symbol: "scissors", description: "Alat kecil untuk memanen tangkai pare."),
        Item(id: .ngalantai, name: "Lantayan", symbol: "sun.max.fill", description: "Tempat menggantung dan mengeringkan hasil panen."),
        Item(id: .ngaleuitkeunPare, name: "Leuit", symbol: "house.fill", description: "Lumbung untuk menyimpan pare hasil perjalanan Ngahuma.")
    ]

    private var earned: [Item] {
        items.filter { journey.progress.record(for: $0.id).explanationAvailable }
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
                Text("\(earned.count) dari \(items.count) item terkumpul")
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
                        Text("Selesaikan tahapan Ngahuma untuk mendapatkan item koleksi.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.cream.opacity(0.82))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 230)
                    .padding(18)
                    .background { cardSurface }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                        ForEach(earned) { item in
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 38))
                                    .foregroundStyle(AppTheme.heading)
                                    .frame(maxWidth: .infinity, minHeight: 80)
                                    .background(AppTheme.heading.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                                    .accessibilityHidden(true)
                                Text(item.name)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.cream)
                                Text(item.description)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.cream.opacity(0.82))
                                Spacer(minLength: 0)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
                            .background { cardSurface }
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
        .background { MenuBackground(progress: journey.progress) }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Koleksi Item")
    }
}
