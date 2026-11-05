import SwiftUI
struct NgoredActivityView: View {
    let model: NgoredViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Acuan ilustrasi").font(.headline)
            Label("Padi · daun ramping dan tegak", systemImage: "leaf.arrow.triangle.circlepath")
            Label("Gulma contoh · daun lebar bercabang", systemImage: "leaf.fill")
            Text("Gambar disederhanakan untuk belajar, bukan panduan identifikasi semua gulma.").font(.footnote)
            ForEach(0..<4) { index in
                ActivityChoice(title: "Gulma berdaun lebar \(index + 1)", symbol: "leaf.fill", done: model.removed.contains(index), identifier: "weed_\(index)") { model.remove(index) }
            }
            ActivityChoice(title: "Padi muda · pertahankan", symbol: "leaf.arrow.triangle.circlepath", identifier: "retain_rice") { model.remove(4) }
        }
    }
}
