import SwiftUI
struct NgoredActivityView: View {
    let model: NgoredViewModel
    @Environment(ActivitySheetState.self) private var sheet
    var body: some View {
        VStack(spacing: 16) {
            switch model.step {
            case .weeding:
                Text("Singkirkan gulma, pertahankan padi").font(.headline)
                KoredTool().frame(width: 70, height: 120)
                Text("Kored adalah alat seperti cangkul kecil untuk membersihkan gulma di sekitar padi. Sentuh gagang kored, lalu geser ke gulma. Sapukan ke bawah tiga kali pada setiap gulma; angkat kembali sebelum sapuan berikutnya. Tombol di bawah menjalankan satu sapuan.")
                LessonButton(title: "Coba di lahan", identifier: "ngored.field.begin") { sheet.collapse() }
                Text("Delapan gulma berikut adalah contoh untuk latihan.").font(.footnote)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(0..<8) { index in
                        ActivityChoice(title: "Gulma \(index + 1) · \(model.strokes[index] ?? 0)/3", symbol: "leaf.fill", done: model.removed.contains(index), identifier: "weed_\(index)") { model.remove(index) }
                    }
                }
                Button("Padi muda · pertahankan") { model.remove(8) }.frame(minHeight: 44)
            case .cleared:
                InstructionCard(title: "Padi telah bersih dari rumput liar", message: "Penyiangan diulangi selama padi tumbuh. Selanjutnya, kita melihat waktu berlalu dan hujan membasahi lahan.", identifier: "ngored.rain", action: model.observeRain)
            case .rain:
                Text("Waktu berlalu… Hujan membasahi lahan, dan padi terus tumbuh. Hujan mengikuti cuaca, bukan akibat penyiangan.")
                LessonButton(title: "Lanjut", identifier: "ngored.finishRain", action: model.finishRain)
            }
        }.disabled(model.isDemonstrating)
            .onChange(of: ActivityAudio.shared.enabled) { _, enabled in
                if enabled && model.step == .rain { ActivityAudio.shared.play(.rain) }
            }
    }
}
