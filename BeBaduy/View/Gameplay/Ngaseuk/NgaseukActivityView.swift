import SwiftUI
struct NgaseukActivityView: View {
    let model: NgaseukViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch model.step {
            case .instructions, .digging:
                Text("Gerakkan ponselmu dari atas ke bawah untuk menggunakan aseuk. Ulangi sampai tiga lubang terbentuk.")
            case .holesReady:
                InstructionCard(title: "Tanah berhasil dilubangi", message: "Ketuk lubang untuk melihat ke dalam. Gerakkan ponsel perlahan bolak-balik untuk menuang benih, atau ketuk Tuang benih.", identifier: "ngaseuk.seeds", action: model.proceed)
            case .seeding:
                Text("Ketuk lubang di lahan untuk melihat ke dalam dan menuang benih. Pilihan di bawah juga dapat langsung mengisi lubang.")
                Text("\(model.seeds.count) / 3 lubang berisi benih").font(.headline)
                ForEach(0..<3) { index in
                    ActivityChoice(title: "Isi lubang \(index + 1)", symbol: "leaf", done: model.seeds.contains(index), identifier: "seed_\(index)") { model.seed(index) }
                }
            }
        }.disabled(model.isDemonstrating)
    }
}
