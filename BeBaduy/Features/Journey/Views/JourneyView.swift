import SwiftUI

struct JourneyView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let journey: JourneyViewModel
    var showsRecap = false
    let open: (PhaseID) -> Void

    private let ivory = Color(red: 0.99, green: 0.95, blue: 0.87)
    private let gold = Color(red: 1, green: 0.69, blue: 0.40)

    private let recap = [
        "Persiapkan dan bersihkan lahan dari tanaman liar dan bakar.",
        "Melubangi tanah untuk menanam benih pare huma yang telah diberkati secara adat.",
        "Menyiangi lahan dari rumput liar.",
        "Memanen pare huma.",
        "Menggantung pare huma yang telah dipocong.",
        "Menyimpan hasil panen ke dalam leuit."
    ]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Perjalanan Ngahuma")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(ivory)
                    .accessibilityAddTraits(.isHeader)
                Text("Ikuti setiap tahapan Ngahuma dan temukan cerita di balik tradisi kami.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            ForEach(PhaseCatalog.all) { phase in
                let unlocked = journey.progress.isUnlocked(phase.id)
                let completed = journey.progress.record(for: phase.id).explanationAvailable
                Button { open(phase.id) } label: {
                    phaseCard(phase, unlocked: unlocked)
                }
                .buttonStyle(.plain)
                .disabled(!unlocked)
                .accessibilityIdentifier("phase_\(phase.id.rawValue)")
                .accessibilityLabel("\(phase.title), \(unlocked ? completed ? "selesai" : "tersedia" : "terkunci")")
            }
        }
        .padding(.horizontal, 20)
    }

    private func phaseCard(_ phase: PhaseContent, unlocked: Bool) -> some View {
        return ZStack(alignment: .leading) {
            StageCardScene(thumbnail: UIImage(named: "Journey-\(phase.id.rawValue)"))
                .saturation(unlocked ? 1 : 0)
            if unlocked {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.15, green: 0.09, blue: 0.06).opacity(0.96), location: 0),
                        .init(color: Color(red: 0.19, green: 0.11, blue: 0.07).opacity(0.82), location: 0.46),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                Color(red: 0.34, green: 0.33, blue: 0.32).opacity(0.8)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(phase.id == .ngaleuitkeunPare ? "NGALEUITKEUN" : phase.title.uppercased())
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(unlocked ? gold : Color(red: 0.74, green: 0.69, blue: 0.63))
                Text(showsRecap ? recap[phase.id.index] : unlocked ? phase.introduction : "Selesaikan \(PhaseContent.content(for: PhaseID.allCases[phase.id.index - 1]).title) untuk lanjut ke tahap ini.")
                    .font(.subheadline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .foregroundStyle(ivory.opacity(unlocked ? 1 : 0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 218, alignment: .leading)
            .padding(.leading, 22)
            .padding(.trailing, 8)
        }
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 150 : 116)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(ivory.opacity(unlocked ? 0.38 : 0.3), lineWidth: 0.6))
    }
}

private struct StageCardScene: View {
    let thumbnail: UIImage?

    var body: some View {
        ZStack {
            Color(red: 0.22, green: 0.14, blue: 0.09)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                ReusableLoadingView(message: "Memuat tahap…", style: .compact)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
