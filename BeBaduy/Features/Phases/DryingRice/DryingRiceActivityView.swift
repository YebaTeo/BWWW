import SwiftUI
struct DryingRiceActivityView: View {
    let model: DryingRiceViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("1. Pilih kelompok padi").font(.headline)
            ForEach(0..<3) { index in
                ActivityChoice(title: "Kelompok padi \(index + 1)", symbol: model.selected == index ? "circle.inset.filled" : "laurel.leading", done: model.rack.values.contains(index), identifier: "ricegroup_\(index)") { model.select(index) }
                    .accessibilityValue(model.selected == index ? "Dipilih" : "")
            }
            Text("2. Letakkan pada rak bambu").font(.headline)
            ForEach(0..<3) { slot in
                ActivityChoice(title: "Rak \(slot + 1) · " + (model.rack[slot].map { "kelompok \($0 + 1)" } ?? "kosong"), symbol: "rectangle.split.3x1", done: model.rack[slot] != nil, identifier: "rack_\(slot)") { model.place(at: slot) }
                    .disabled(model.selected == nil)
            }
        }
    }
}
