import SwiftUI
struct NgaseukActivitySurface: View {
    let model: NgaseukViewModel
    @Environment(ActivitySheetState.self) private var sheet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ActivityPhoto(asset: "ngaseuk_before")
                if model.step == .digging {
                    Capsule().fill(Color(red: 0.62, green: 0.42, blue: 0.22))
                        .frame(width: 12, height: geometry.size.height * 0.24)
                        .rotationEffect(.degrees(12))
                        .position(x: geometry.size.width * CGFloat(model.lastDug + 1) / 4 + 15, y: geometry.size.height * 0.29)
                        .allowsHitTesting(false).accessibilityHidden(true)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.lastDug)
                }
                if model.step != .instructions {
                    ForEach(0..<3) { index in
                        Button {
                            if model.step == .digging { model.dig(index) }
                            else if model.step == .seeding { model.seed(index) }
                        } label: {
                            ZStack {
                                Ellipse().fill(model.holes.contains(index) ? Color.black.opacity(0.85) : Color.brown.opacity(0.7))
                                Ellipse().strokeBorder(.white, style: StrokeStyle(lineWidth: 2, dash: model.holes.contains(index) ? [] : [4, 4]))
                                if model.seeds.contains(index) {
                                    HStack(spacing: 3) {
                                        Capsule().fill(.yellow).frame(width: 12, height: 5)
                                        Capsule().fill(.yellow).frame(width: 12, height: 5).rotationEffect(.degrees(25))
                                    }
                                } else { Text("\(index + 1)").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white) }
                            }.frame(width: 72, height: 56)
                        }.buttonStyle(.plain)
                            .accessibilityLabel("Lubang \(index + 1)")
                            .accessibilityIdentifier("field.hole.\(index)")
                            .dropDestination(for: String.self) { items, _ in
                                guard !model.isDemonstrating, items.contains("rice-seed") else { return false }
                                return model.seed(index)
                            }
                            .position(x: geometry.size.width * CGFloat(index + 1) / 4, y: geometry.size.height * 0.43)
                    }
                }
                if model.step == .seeding {
                    Label("Benih", systemImage: "leaf.fill").font(.headline).padding(16)
                        .foregroundStyle(.white).background(.black.opacity(0.75), in: Capsule())
                        .draggable("rice-seed").accessibilityIdentifier("field.seed")
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.25)
                }
            }.disabled(model.isDemonstrating)
        }.onChange(of: model.step) { _, step in
            sheet.expand()
        }
    }
}
