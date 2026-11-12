import SwiftUI
struct NgaseukActivityView: View {
    let model: NgaseukViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch model.step {
            case .instructions, .digging:
                Text("Tusukkan aseuk tiga kali pada setiap titik. Lubang akan membesar sampai siap ditanami.")
            case .holesReady:
                InstructionCard(title: "Tanah berhasil dilubangi", message: "Seret benih ke lubang. Di tampilan dekat, arahkan ke pusat lubang lalu lepaskan untuk menanam 4 benih sekaligus. Kamu juga bisa menuang dengan tombol.", identifier: "ngaseuk.seeds", action: model.proceed)
            case .seeding:
                Text("Seret benih dari wadah ke lubang, lalu arahkan ke pusat lubang di tampilan dekat dan lepaskan untuk menanam 4 benih sekaligus.")
                Text("\(model.seeds.count) / 3 lubang berisi benih").font(.headline)
                ForEach(0..<3) { index in
                    ActivityChoice(title: "Isi lubang \(index + 1)", symbol: "leaf", done: model.seeds.contains(index), identifier: "seed_\(index)") { model.seed(index) }
                }
            }
        }.disabled(model.isDemonstrating)
    }
}
