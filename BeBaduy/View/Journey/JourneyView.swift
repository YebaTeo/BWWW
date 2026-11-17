import SwiftUI

struct JourneyView: View {
    let journey: JourneyViewModel
    var showsRecap = false
    var onPrologue: (() -> Void)? = nil
    let open: (PhaseID) -> Void
    private let thumbnailStore = StageThumbnailStore.shared

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

            if let onPrologue {
                Button(action: onPrologue) {
                    prologueCard
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("journey.prologue")
            }

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
        .task { thumbnailStore.ensureLoaded() }
    }

    private var prologueCard: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.28, green: 0.17, blue: 0.11))
            if let texture = UIImage(named: "HumaTerrainTexture") {
                Image(uiImage: texture)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.32)
            }
            LinearGradient(colors: [.black.opacity(0.38), .clear], startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 4) {
                Text("PROLOGUE")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(gold)
                Text("Kisah awal")
                    .font(.subheadline)
                    .foregroundStyle(ivory)
            }
            .padding(22)
        }
        .frame(height: 98)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(ivory.opacity(0.28), lineWidth: 0.6))
    }

    private func phaseCard(_ phase: PhaseContent, unlocked: Bool) -> some View {
        let stage = GrowthStage.allStages[phase.id.index]
        return ZStack(alignment: .leading) {
            StageCardScene(
                progress: stage.targetProgress,
                phase: phase.id,
                thumbnail: thumbnailStore.thumbnails[phase.id]
            )
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.15, green: 0.09, blue: 0.06).opacity(0.96), location: 0),
                    .init(color: Color(red: 0.19, green: 0.11, blue: 0.07).opacity(0.82), location: 0.46),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            if !unlocked { Color.black.opacity(0.58) }
            VStack(alignment: .leading, spacing: 4) {
                Text(phase.id == .ngaleuitkeunPare ? "NGALEUITKEUN" : phase.title.uppercased())
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(unlocked ? gold : gold.opacity(0.48))
                Text(showsRecap ? recap[phase.id.index] : unlocked ? phase.introduction : "Selesaikan \(PhaseContent.content(for: PhaseID.allCases[phase.id.index - 1]).title) untuk lanjut ke tahap ini.")
                    .font(.system(size: 13.5))
                    .lineLimit(3)
                    .foregroundStyle(ivory.opacity(unlocked ? 1 : 0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 218, alignment: .leading)
            .padding(.leading, 22)
            .padding(.trailing, 8)
        }
        .frame(height: 116)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(ivory.opacity(unlocked ? 0.38 : 0.14), lineWidth: 0.6))
    }
}

private struct StageCardScene: View {
    let progress: CGFloat
    let phase: PhaseID
    let thumbnail: UIImage?

    private var scale: CGFloat {
        switch phase {
        case .narawas: 1.25
        case .ngaseuk, .ngored: 2.0
        case .mipit: 1.6
        case .ngalantai, .ngaleuitkeunPare: 1.25
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CinematicAtmosphereView(progress: progress, isActive: false)
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width * scale, height: geometry.size.height * scale)
                        .offset(x: geometry.size.width * 0.28)
                        .transition(.opacity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
