import SwiftUI
struct NyacarActivityView: View {
    let model: NyacarViewModel
    private let names = ["Semak kiri", "Semak tengah", "Cabang bertanda", "Semak kanan"]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(model.cleared.count) dari 4 bagian disiapkan").font(.headline)
            ForEach(0..<4) { target in
                ActivityChoice(title: names[target] + " · tebas", symbol: "leaf", done: model.cleared.contains(target), identifier: "clear_\(target)") { model.clear(target) }
            }
            ActivityChoice(title: "Pohon berguna · pertahankan", symbol: "tree", identifier: "retain_tree") { model.clear(4) }
        }
    }
}
