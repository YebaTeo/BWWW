import SwiftUI
struct NgahuruActivityView: View {
    let model: NgahuruViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pilih kartu, lalu posisinya").font(.headline)
            ForEach(0..<3) { index in
                Button { model.select(index) } label: {
                    Label(model.cards[index], systemImage: model.symbols[index]).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                }.buttonStyle(.bordered).accessibilityIdentifier("card_\(index)")
                .accessibilityValue(model.selected == index ? "Dipilih" : "Belum dipilih")
                .accessibilityAddTraits(model.selected == index ? [.isSelected] : [])
            }
            Divider()
            ForEach(0..<3) { index in
                ActivityChoice(title: "Posisi \(index + 1): " + (model.slots[index].map { model.cards[$0] } ?? "kosong"), symbol: "arrow.down.to.line", identifier: "position_\(index)") { model.place(at: index) }
                    .disabled(model.selected == nil)
            }
        }
    }
}
