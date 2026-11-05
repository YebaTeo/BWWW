import SwiftUI
struct DibuatActivityView: View {
    let model: DibuatViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Etem / ani-ani").font(.headline)
            Image("dibuat_etem").resizable().scaledToFit().frame(height: 80)
                .accessibilityLabel("Ilustrasi sederhana etem: bilah kecil dengan pegangan")
            Text("Ketuk malai untuk mengarahkan alat panen. Bulir tetap bersama tangkai.")
            ForEach(0..<4) { index in
                ActivityChoice(title: "Panen malai matang \(index + 1)", symbol: "laurel.leading", done: model.harvested.contains(index), identifier: "harvest_\(index)") { model.harvest(index) }
            }
            Text("\(model.harvested.count) malai terkumpul").font(.subheadline)
        }
    }
}
