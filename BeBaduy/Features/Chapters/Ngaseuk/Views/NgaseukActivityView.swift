import SwiftUI

struct NgaseukActivityView: View {
    let model: NgaseukViewModel
    @Environment(ActivityCardState.self) private var card

    var body: some View {
        Group {
            if model.step == .seeding {
                Text("\(model.seeds.count) / 3 lubang berisi benih").activityCounterStyle()
            }
            ActivityCardPanel {
                switch model.step {
                case .instructions, .digging:
                    Text("Tusukkan aseuk tiga kali pada setiap titik. Lubang akan membesar sampai siap ditanami.")
                case .holesReady:
                    ActivityCardHeading("Keren!")
                    Text("Nah, sekarang waktunya menabur binih ke setiap lubang agar pare huma bisa mulai tumbuh.")
                case .seeding:
                    Text("Seret benih dari wadah ke lubang, lalu arahkan ke pusat lubang di tampilan dekat dan lepaskan untuk menanam 4 benih sekaligus.")
                }
            }
            if model.step == .holesReady && card.mode == .instruction {
                ActivityAcknowledgement(title: "Lanjut menanam benih", identifier: "ngaseuk.seeds.continue") {
                    guard model.step == .holesReady, card.mode == .instruction else { return }
                    model.proceed()
                }
            }
            if model.step == .seeding && card.mode == .help {
                ViewThatFits(in: .vertical) {
                    seedControls.fixedSize(horizontal: false, vertical: true)
                    ScrollView { seedControls }
                }
            }
        }
        .disabled(model.isDemonstrating)
    }

    private var seedControls: some View {
        VStack(spacing: 8) {
            ForEach(0..<3) { index in
                ActivityChoice(title: "Isi lubang \(index + 1)", symbol: "leaf", done: model.seeds.contains(index),
                               identifier: "seed_\(index)") { model.seed(index) }
            }
        }
    }
}
