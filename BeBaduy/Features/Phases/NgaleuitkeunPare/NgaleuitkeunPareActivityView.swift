import SwiftUI
struct NgaleuitkeunPareActivityView: View {
    let model: NgaleuitkeunPareViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Potongan leuit · latihan penempatan").font(.headline)
            Text("Posisi ilustrasi ini bukan pola penyusunan adat.").font(.footnote)
            ForEach(0..<3) { index in
                ActivityChoice(title: "Ikatan padi kering \(index + 1)", symbol: model.selected == index ? "circle.inset.filled" : "laurel.leading", done: model.storage.values.contains(index), identifier: "bundle_\(index)") { model.select(index) }
                    .accessibilityValue(model.selected == index ? "Dipilih" : "")
            }
            Divider()
            ForEach(0..<3) { index in
                ActivityChoice(title: "Ruang ilustrasi \(index + 1) · " + (model.storage[index].map { "ikatan \($0 + 1)" } ?? "kosong"), symbol: "house", done: model.storage[index] != nil, identifier: "space_\(index)") { model.place(at: index) }
                    .disabled(model.selected == nil)
            }
        }
    }
}
