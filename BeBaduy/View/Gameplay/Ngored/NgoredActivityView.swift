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
            if enabled && model.step == .rain { ActivityAudio.shared.play(.rain) }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 12) {
            switch model.step {
            case .weeding:
                Text("Pare mulai tumbuh!")
                    .font(.system(.title3, design: .rounded).bold())
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
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(AppTheme.heading)
            case .complete:
                Text("Hujan telah reda")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(AppTheme.heading)
            }
        }
    }
}
