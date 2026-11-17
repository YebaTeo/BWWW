import SwiftUI
struct NgoredActivityView: View {
    let model: NgoredViewModel
    @Environment(ActivityCardState.self) private var card
    var body: some View {
        Group {
            ActivityCardPanel { content }
            if card.mode == .instruction {
                switch model.step {
                case .initialRain:
                    ActivityAcknowledgement(title: "Lihat pertumbuhan", identifier: "ngored.growth.begin") {
                        guard card.mode == .instruction else { return }
                        card.dismiss()
                        model.beginInitialRainAfterCard()
                    }
                case .weeding:
                    ActivityAcknowledgement(title: "Coba di lahan", identifier: "ngored.field.begin") {
                        guard card.mode == .instruction else { return }
                        card.dismiss()
                    }
                default:
                    EmptyView()
                }
            }
        }
        .disabled(model.isDemonstrating)
        .onChange(of: ActivityAudio.shared.enabled) { _, enabled in
            if enabled && (model.step == .initialRain || model.step == .rain || model.step == .finalRain) {
                ActivityAudio.shared.play(.rain)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .initialRain:
            ActivityCardHeading("Hujan awal membasahi huma")
            Text("Padi dan gulma mulai tumbuh di bawah hujan.")
        case .weeding:
            ActivityCardHeading("Pare mulai tumbuh!")
            Text("Binih yang kamu tanam mulai tumbuh menjadi tanaman padi. Namun, rumput liar juga ikut tumbuh di sekitarnya.\n\nMari kita mulai bersihkan!\n\nUsap setiap gulma tiga kali untuk menyapukan kored.")
        case .cleared:
            ActivityCardHeading("Hebat!")
            Text("Berkat bantuanmu membersihkan gulma, pare kini bisa tumbuh lebih baik. Sekarang, kita menunggu hujan datang!")
        case .rain:
            Text("Hujan telah membasahi huma. Lihatlah semua pare yang ditanam semakin bertumbuh!")
        case .cycles:
            ActivityCardHeading("Pagi dan malam berlalu")
            Text("Padi tumbuh setengah dan gulma tumbuh kembali.")
        case .secondWeeding:
            ActivityCardHeading("Gulma tumbuh kembali")
            Text("Bersihkan tiga gulma yang tumbuh di antara padi.")
        case .secondCleared:
            ActivityCardHeading("Hujan kembali turun")
            Text("Hujan akan menghanyutkan bekas gulma sebelum padi tumbuh penuh.")
        case .finalRain:
            Text("Hujan menghanyutkan bekas gulma…")
        case .finalCycles:
            ActivityCardHeading("Padi tumbuh penuh")
        case .complete:
            ActivityCardHeading("Pare huma tumbuh sempurna")
            Text("Perjalanan menanam dan merawat padi telah selesai.")
        }
    }
}
