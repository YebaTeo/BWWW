import SwiftUI
struct NarawasActivityView: View {
    let model: NarawasViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Peta contoh · batas untuk latihan").font(.headline)
            Text("Kiri: A, kawasan lindung. Tengah: B, lahan tersedia menurut adat. Kanan: C, zona mata air yang dilindungi.")
            ActivityChoice(title: "Petak A · kawasan lindung", symbol: "tree", identifier: "plot_0") { model.choose(0) }
            ActivityChoice(title: "Petak B · lahan yang diizinkan", symbol: "square.dashed", identifier: "plot_1") { model.choose(1) }
            ActivityChoice(title: "Petak C · zona mata air", symbol: "drop", identifier: "plot_2") { model.choose(2) }
        }
    }
}
