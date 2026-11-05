import SwiftUI

enum HarvestPalette {
    static let ivory = Color(red: 0.99, green: 0.97, blue: 0.92)
    static let gold = Color(red: 0.98, green: 0.84, blue: 0.44)
    static let card = Color(red: 0.12, green: 0.08, blue: 0.05)
}

struct GrowthOverlayView: View {
    let stage: GrowthStage
    let journey: JourneyViewModel
    let onResume: () -> Void
    let onExplore: () -> Void
    let onCompletion: () -> Void
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Capsule().fill(HarvestPalette.ivory.opacity(0.35))
                    .frame(width: 38, height: 4)
                    .accessibilityHidden(true)
                Text(stage.culturalContext.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(HarvestPalette.gold)
                Text(stage.name)
                    .font(.largeTitle.weight(.black))
                    .fontWidth(.condensed)
                    .tracking(2.2)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("home.stage.title")
                Text(stage.subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(HarvestPalette.gold)
                Text(stage.narrative)
                    .font(.subheadline)
                    .lineSpacing(3)
                Button(action: onResume) {
                    HStack {
                        Text(journey.completedCount == 0 ? "Mulai belajar" : "Lanjutkan belajar")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .foregroundStyle(HarvestPalette.card)
                    .background(HarvestPalette.gold, in: Capsule())
                }
                .accessibilityIdentifier("resume")
                Text("\(journey.completedCount) dari 11 tahap telah dijelajahi")
                    .font(.caption)
                    .accessibilityIdentifier("home.progress")
                if let message = journey.storageMessage {
                    Text(message).font(.footnote)
                }
                if journey.progress.journeyCompleted {
                    Button("Lihat perjalanan selesai", action: onCompletion)
                        .frame(minHeight: 44)
                }
                Button(action: onNext) {
                    Label(stage.id == 3 ? "Ulangi pratinjau" : "Pratinjau berikutnya", systemImage: stage.id == 3 ? "arrow.counterclockwise" : "chevron.up.2")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("home.preview.next")
                Button("Jelajahi huma 3D", action: onExplore)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("ngahuma.open")
            }
            .multilineTextAlignment(.center)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(HarvestPalette.ivory)
        .tint(HarvestPalette.gold)
        .background(HarvestPalette.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 28))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(HarvestPalette.gold.opacity(0.35)))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
    }
}
