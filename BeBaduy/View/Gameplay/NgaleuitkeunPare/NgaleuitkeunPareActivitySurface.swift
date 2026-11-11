import SwiftUI
struct NgaleuitkeunPareActivitySurface: View {
    let model: NgaleuitkeunPareViewModel
    @Environment(ActivityCardState.self) private var card
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if model.interiorVisible {
                    ActivityPhoto(asset: "ngaleuitkeun_pare_after")
                }
                if !model.interiorVisible {
                    ForEach(0..<3) { index in
                        if !model.storage.values.contains(index) {
                            FieldTarget(title: "\(index + 1)", symbol: model.selected == index ? "checkmark.circle.fill" : "laurel.leading") { model.select(index) }
                                .draggable("bundle-\(index)")
                                .accessibilityLabel("Ikatan padi \(index + 1)")
                                .accessibilityIdentifier("field.bundle.\(index)")
                                .position(x: geometry.size.width * CGFloat(index + 1) / 4, y: geometry.size.height * 0.24)
                        }
                        FieldTarget(title: "\(index + 1)", symbol: model.storage[index] == nil ? "house" : "checkmark.circle.fill") { model.place(at: index) }
                            .accessibilityLabel("Leuit \(index + 1)")
                            .accessibilityValue(model.storage[index] == nil ? "Kosong" : "Terisi")
                            .accessibilityIdentifier("field.leuit.\(index)")
                            .dropDestination(for: String.self) { items, _ in
                                guard !model.isDemonstrating, let item = items.first, item.hasPrefix("bundle-"), let bundle = Int(item.dropFirst(7)) else { return false }
                                return model.drop(bundle, at: index)
                            }
                            .position(doorPosition(index, in: geometry.size))
                    }
                }
            }.disabled(model.isDemonstrating)
        }.onChange(of: model.interiorVisible) { _, visible in
            if visible { card.showInstruction() }
        }.onChange(of: model.storage.count) { _, count in
            if count == 3 { card.showInstruction() }
        }
    }

    private func doorPosition(_ index: Int, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2 + CGFloat(index - 1) * (min(size.width, 420) * 0.24),
            y: size.height * 0.48
        )
    }
}
