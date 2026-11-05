import SwiftUI
struct NgubaranPareActivityView: View {
    let model: NgubaranPareViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kenali tumbuhannya").font(.headline)
            ForEach(0..<3) { index in
                HStack(alignment: .center, spacing: 16) {
                    Image("care_plant_\(index)").resizable().scaledToFit().frame(width: 48, height: 72).accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text(model.names[index]).font(.headline)
                        Text(model.details[index]).font(.subheadline)
                    }
                }
            }
            Text("1. Pilih ilustrasi").font(.headline)
            ForEach(0..<3) { index in
                Button { model.select(index) } label: {
                    HStack {
                        Image("care_plant_\(index)").resizable().scaledToFit().frame(width: 40, height: 64).accessibilityHidden(true)
                        Text("Ilustrasi \(index + 1): \(model.details[index])")
                        if model.matched.contains(index) { Image(systemName: "checkmark.circle") }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.bordered).disabled(model.matched.contains(index))
                .accessibilityValue(model.selected == index ? "Dipilih" : model.matched.contains(index) ? "Cocok" : "Belum dipilih")
                .accessibilityIdentifier("plantcard_\(index)")
            }
            Text("2. Pilih nama").font(.headline)
            ForEach([2, 0, 1], id: \.self) { index in
                ActivityChoice(title: model.names[index], symbol: "textformat", done: model.matched.contains(index), identifier: "plantname_\(index)") { model.match(index) }
                    .disabled(model.selected == nil)
            }
        }
    }
}
