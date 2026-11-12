import SwiftUI
struct NgoredActivityView: View {
    let model: NgoredViewModel
    @Environment(ActivityCardState.self) private var card
    var body: some View {
        VStack(spacing: 16) {
            switch model.step {
            case .initialRain:
                Text("Hujan awal membasahi huma").font(.headline)
                Text("Padi dan gulma mulai tumbuh di bawah hujan.")
            case .weeding:
                Text("Singkirkan gulma, pertahankan padi").font(.headline)
                Text("Pegang kored di lahan. Sapukan ke bawah tiga kali pada setiap gulma, lalu angkat sebelum sapuan berikutnya.")
                if card.mode == .instruction {
                    LessonButton(title: "Coba di lahan", identifier: "ngored.field.begin") { card.dismiss() }
                } else {
                Text("Kored adalah alat seperti cangkul kecil untuk membersihkan gulma di sekitar padi. Jika lebih nyaman, gunakan tombol di bawah untuk satu sapuan.").font(.subheadline)
                Text("Singkirkan empat gulma di sekitar padi.").font(.footnote)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(0..<4) { index in
                        ActivityChoice(title: "Gulma \(index + 1) · \(model.strokes[index] ?? 0)/3", symbol: "leaf.fill", done: model.removed.contains(index), identifier: "weed_\(index)") { model.remove(index) }
                    }
                }
                }
            case .cleared:
                InstructionCard(title: "Hujan menghanyutkan bekas kored", message: "Hujan membasahi lahan. Setelah reda, empat siklus pagi dan malam berlalu; padi tumbuh setengah dan gulma tumbuh kembali.", identifier: "ngored.rain.first", action: model.observeRain)
            case .rain:
                Text("Hujan membasuh sisa gulma…").font(.headline)
            case .cycles:
                Text("Empat siklus pagi dan malam berlalu…").font(.headline)
            case .secondWeeding:
                Text("Padi tumbuh setengah; gulma tumbuh kembali").font(.headline)
                Text("Potong tiga gulma yang tumbuh di antara padi.")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(4..<7) { index in
                        ActivityChoice(title: "Gulma \(index - 3) · \(model.strokes[index] ?? 0)/3", symbol: "leaf.fill", done: model.removed.contains(index), identifier: "weed_\(index)") { model.remove(index) }
                    }
                }
            case .secondCleared:
                InstructionCard(title: "Hujan kembali turun", message: "Hujan menghanyutkan bekas gulma. Setelah reda, siklus malam dan pagi berlanjut sampai padi tumbuh penuh.", identifier: "ngored.rain.final", action: model.observeRain)
            case .finalRain:
                Text("Hujan menghanyutkan bekas gulma…").font(.headline)
            case .finalCycles:
                Text("Malam dan pagi berlalu; padi tumbuh penuh…").font(.headline)
            case .complete:
                Text("Padi tumbuh penuh").font(.headline)
            }
        }.disabled(model.isDemonstrating)
            .onChange(of: ActivityAudio.shared.enabled) { _, enabled in
                if enabled && (model.step == .rain || model.step == .finalRain || model.step == .initialRain) { ActivityAudio.shared.play(.rain) }
            }
    }
}
