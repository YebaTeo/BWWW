import SwiftUI
struct NgaseukActivityView: View {
    let model: NgaseukViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 20) {
            switch model.step {
            case .instructions:
                InstructionCard(title: "Buat tempat untuk benih", message: "Pegang ponsel dengan nyaman. Gerakkan sedikit ke bawah lalu kembali tenang, atau ketuk tanah. Tidak perlu mengguncang ponsel.", identifier: "ngaseuk.instructions", action: model.proceed)
            case .digging:
                Text("\(model.holes.count) / 3 lubang").font(.headline)
                soilScene
                Button(model.motionActive ? "Gunakan sentuhan" : "Gunakan gerakan lembut") {
                    if model.motionActive { model.pauseMotion() } else { model.startMotion() }
                }.frame(minHeight: 44)
            case .holesReady:
                InstructionCard(title: "Tanah berhasil dilubangi", message: "Sekarang seret benih ke setiap lubang. Kamu juga bisa mengetuk lubang untuk mengisinya.", identifier: "ngaseuk.seeds", action: model.proceed)
            case .seeding:
                Label("Benih padi · seret ke lubang", systemImage: "leaf.fill")
                    .padding(20).background(.white.opacity(0.15), in: Capsule()).draggable("rice-seed")
                soilScene
                Text("\(model.seeds.count) / 3 lubang berisi benih")
            }
        }.disabled(model.isDemonstrating)
    }
    private var soilScene: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(Color.brown.opacity(0.55))
                if model.step == .digging {
                    Capsule().fill(Color(red: 0.62, green: 0.42, blue: 0.22))
                        .frame(width: 10, height: 110).rotationEffect(.degrees(12))
                        .position(x: geometry.size.width * CGFloat(model.lastDug + 1) / 4 + 12, y: 80)
                        .allowsHitTesting(false).accessibilityHidden(true)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.lastDug)
                }
                ForEach(0..<3) { index in
                    let done = model.step == .digging ? model.holes.contains(index) : model.seeds.contains(index)
                    Button {
                        if model.step == .digging { model.dig(index) } else { model.seed(index) }
                    } label: {
                        ZStack {
                            Ellipse().fill(model.holes.contains(index) ? Color.black.opacity(0.8) : Color.clear)
                            Ellipse().strokeBorder(.white, style: StrokeStyle(lineWidth: 2, dash: model.holes.contains(index) ? [] : [4, 4]))
                            if model.seeds.contains(index) {
                                HStack(spacing: 3) {
                                    Capsule().fill(.yellow).frame(width: 12, height: 5)
                                    Capsule().fill(.yellow).frame(width: 12, height: 5).rotationEffect(.degrees(25))
                                }
                            } else { Text("\(index + 1)").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white) }
                        }.frame(width: 70, height: 54).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(done)
                        .accessibilityLabel(model.step == .digging ? "Buat lubang \(index + 1)" : "Isi lubang \(index + 1)")
                        .accessibilityValue(done ? "Selesai" : "Belum")
                        .accessibilityIdentifier("\(model.step == .digging ? "dig" : "seed")_\(index)")
                        .dropDestination(for: String.self) { items, _ in
                            guard items.contains("rice-seed"), !model.isDemonstrating else { return false }
                            return model.seed(index)
                        }
                        .position(x: geometry.size.width * CGFloat(index + 1) / 4, y: 155)
                }
            }
        }.frame(height: 210)
    }

}
