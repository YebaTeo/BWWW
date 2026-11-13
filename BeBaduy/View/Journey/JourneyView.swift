import SwiftUI
struct JourneyView: View {
    let journey: JourneyViewModel
    var showsRecap = false
    let open: (PhaseID) -> Void
    private let recap = [
        "Persiapkan dan bersihkan lahan dari tanaman liar dan bakar.",
        "Melubangi tanah untuk menanam benih pare huma yang telah diberkati secara adat.",
        "Menyiangi lahan dari rumput liar.",
        "Memanen pare huma.",
        "Menggantung pare huma yang telah dipocong.",
        "Menyimpan hasil panen ke dalam leuit.",
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Perjalanan belajar").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            ForEach(PhaseCatalog.all) { phase in
                let unlocked = journey.progress.isUnlocked(phase.id)
                let completed = journey.progress.record(for: phase.id).explanationAvailable
                Button { open(phase.id) } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Text(String(format: "%02d", phase.id.index + 1)).monospacedDigit().foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(phase.title).font(.headline)
                            Text(showsRecap ? recap[phase.id.index] : completed ? "Selesai · bisa dikunjungi lagi" : unlocked ? phase.subtitle : "Selesaikan tahap sebelumnya").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: completed ? "checkmark.circle" : unlocked ? "chevron.right" : "lock")
                    }.padding(.vertical, 12).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(!unlocked)
                .accessibilityIdentifier("phase_\(phase.id.rawValue)")
                if phase.id != .ngaleuitkeunPare { Divider() }
            }
        }
    }
}
