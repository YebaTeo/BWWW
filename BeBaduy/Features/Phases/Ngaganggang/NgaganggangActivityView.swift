import SwiftUI
struct NgaganggangActivityView: View {
    let model: NgaganggangViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.states[Int(model.position)]).font(.headline)
            Image(systemName: ["cloud.rain", "cloud.sun", "sun.max"][Int(model.position)])
                .font(.system(size: 52)).frame(maxWidth: .infinity).padding().accessibilityHidden(true)
            Text("Ranting dan daun " + ["masih lembap.", "berangsur kehilangan kelembapan.", "telah mengering setelah menunggu."][Int(model.position)])
            Slider(value: Binding(get: { model.position }, set: { model.visit($0) }), in: 0...2, step: 1)
                .accessibilityLabel("Waktu pengeringan").accessibilityValue(model.states[Int(model.position)])
                .accessibilityIdentifier("drying_timeline")
            ForEach(0..<3) { index in
                ActivityChoice(title: model.states[index], symbol: "clock", done: model.visited.contains(index), identifier: "time_\(index)") { model.visit(Double(index)) }
            }
        }
    }
}
