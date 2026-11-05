import SwiftUI
struct NgunjalActivityView: View {
    let model: NgunjalViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ikatan panen menempuh jalan pulang").font(.headline)
            ForEach(0..<3) { index in
                ActivityChoice(title: "Titik \(index + 1) · \(model.checkpoints[index])", symbol: index == 2 ? "house" : "figure.walk", done: index < model.reached, identifier: "waypoint_\(index)") { model.visit(index) }
                if index < 2 { Image(systemName: "arrow.down").padding(.leading).accessibilityHidden(true) }
            }
        }
    }
}
