import SwiftUI
struct NgoredActivityView: View {
    let model: NgoredViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Image("ngored_after").resizable().scaledToFill().frame(height: 240).clipped()
                if model.step == .rain {
                    TimelineView(.animation(minimumInterval: 0.05, paused: reduceMotion || scenePhase != .active)) { timeline in
                        Canvas { context, size in
                            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                            for i in 0..<45 {
                                let x = CGFloat((i * 73) % 313) / 313 * size.width
                                let y = CGFloat((Double(i * 19) + time * 180).truncatingRemainder(dividingBy: 260))
                                var path = Path(); path.move(to: CGPoint(x: x, y: y)); path.addLine(to: CGPoint(x: x - 4, y: y + 18))
                                context.stroke(path, with: .color(.white.opacity(0.65)), lineWidth: 1)
                            }
                        }
                    }.accessibilityHidden(true)
                }
            }.frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 20))
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
