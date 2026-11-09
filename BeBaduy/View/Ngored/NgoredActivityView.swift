import SwiftUI
struct NgoredActivityView: View {
    let model: NgoredViewModel
    var body: some View {
        VStack(spacing: 16) {
            switch model.step {
            case .weeding:
                Text("Singkirkan gulma, pertahankan padi").font(.headline)
                Text("Delapan pilihan daun lebar berikut adalah contoh gulma untuk latihan.")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(0..<8) { index in
                        ActivityChoice(title: "Gulma \(index + 1)", symbol: "leaf.fill", done: model.removed.contains(index), identifier: "weed_\(index)") { model.remove(index) }
                    }
                }
                Button("Padi muda · pertahankan") { model.remove(8) }.frame(minHeight: 44)
            case .cleared:
                InstructionCard(title: "Padi telah bersih dari rumput liar", message: "Selanjutnya, amati hujan yang membantu padi huma tumbuh.", identifier: "ngored.rain", action: model.observeRain)
            case .rain:
                Text("Hujan membasahi lahan. Pertumbuhan padi berlangsung seiring waktu.")
                LessonButton(title: "Lanjut", identifier: "ngored.finishRain", action: model.finishRain)
            }
        }.disabled(model.isDemonstrating)
            .onChange(of: ActivityAudio.shared.enabled) { _, enabled in
                if enabled && model.step == .rain { ActivityAudio.shared.play(.rain) }
            }
    }
}
