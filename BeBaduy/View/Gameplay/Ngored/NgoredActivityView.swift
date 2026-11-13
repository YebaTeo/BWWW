import SwiftUI
struct NgoredActivityView: View {
    let model: NgoredViewModel
    @Environment(ActivityCardState.self) private var card
    var body: some View {
        Group {
            if card.mode == .hidden {
                ActivityCardPanel { content }
            } else {
                content
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
        VStack(spacing: 16) {
            switch model.step {
            case .initialRain:
                Text("Hujan awal membasahi huma")
                    .font(.headline)
                    .foregroundStyle(AppTheme.heading)
                Text("Padi dan gulma mulai tumbuh di bawah hujan.")
                if card.mode == .instruction {
                    LessonButton(title: "Lihat pertumbuhan", identifier: "ngored.growth.begin") { card.dismiss() }
                }
            case .weeding:
                Text("Pare mulai tumbuh!")
                    .font(.headline)
                    .foregroundStyle(AppTheme.heading)
                Text("Binih yang kamu tanam mulai tumbuh menjadi tanaman padi. Namun, rumput liar juga ikut tumbuh di sekitarnya.\n\nMari kita mulai bersihkan!\n\nUsap setiap gulma tiga kali untuk menyapukan kored.")
                if card.mode == .instruction {
                    LessonButton(title: "Coba di lahan", identifier: "ngored.field.begin") { card.dismiss() }
                }
            case .cleared:
                Text("Hebat!").font(.headline).foregroundStyle(AppTheme.heading)
                Text("Berkat bantuanmu membersihkan gulma, pare kini bisa tumbuh lebih baik. Sekarang, kita menunggu hujan datang!")
            case .rain:
                Text("Hujan telah membasahi huma. Lihatlah semua pare yang ditanam semakin bertumbuh!")
                    .font(.headline)
                    .foregroundStyle(AppTheme.heading)
            case .cycles:
                Text("Pagi dan malam berlalu")
                    .font(.headline)
                    .foregroundStyle(AppTheme.heading)
                Text("Padi tumbuh setengah dan gulma tumbuh kembali.")
            case .secondWeeding:
                Text("Gulma tumbuh kembali")
                    .font(.headline)
                    .foregroundStyle(AppTheme.heading)
                Text("Bersihkan tiga gulma yang tumbuh di antara padi.")
            case .secondCleared:
                Text("Hujan kembali turun")
                    .font(.headline)
                    .foregroundStyle(AppTheme.heading)
                Text("Hujan akan menghanyutkan bekas gulma sebelum padi tumbuh penuh.")
            case .finalRain:
                Text("Hujan menghanyutkan bekas gulma…")
                    .font(.headline)
                    .foregroundStyle(AppTheme.heading)
            case .finalCycles:
                Text("Padi tumbuh penuh")
                    .font(.headline)
                    .foregroundStyle(AppTheme.heading)
            case .complete:
                Text("Pare huma tumbuh sempurna")
                    .font(.headline)
                    .foregroundStyle(AppTheme.heading)
                Text("Perjalanan menanam dan merawat padi telah selesai.")
            }
        }
    }
}
