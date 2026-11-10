import SwiftUI
struct NgaleuitkeunPareActivityView: View {
    let model: NgaleuitkeunPareViewModel
    @Environment(ActivityCardState.self) private var card
    var body: some View {
        VStack(spacing: 18) {
            if model.interiorVisible {
                InstructionCard(title: "Di dalam leuit", message: "Padi disimpan bersama tangkainya sebagai cadangan pangan.", identifier: "leuit.interior", action: model.finish)
            } else {
                Text("Seret ikatan ke leuit").font(.headline)
                Text("Atau ketuk ikatan, lalu ketuk leuit yang kosong.")
                if card.mode == .instruction && model.storage.count < 3 {
                    LessonButton(title: "Mulai", identifier: "activity.card.start") { card.dismiss() }
                }
                if card.mode == .help {
                ForEach(0..<3) { index in
                    ActivityChoice(title: "Ikatan padi \(index + 1)", symbol: model.selected == index ? "checkmark.circle" : "laurel.leading", done: model.storage.values.contains(index), identifier: "bundle_\(index)") { model.select(index) }
                        .draggable("bundle-\(index)")
                }
                ForEach(0..<3) { index in
                    VStack(spacing: 4) {
                        ActivityChoice(title: "Leuit \(index + 1)", symbol: "house", done: model.storage[index] != nil, identifier: "space_\(index)") { model.place(at: index) }
                        ProgressView(value: model.storage[index] == nil ? 0 : 1).accessibilityLabel("Isi leuit \(index + 1)")
                    }.dropDestination(for: String.self) { items, _ in
                        guard !model.isDemonstrating, let item = items.first, item.hasPrefix("bundle-"), let bundle = Int(item.dropFirst(7)) else { return false }
                        return model.drop(bundle, at: index)
                    }
                }
                }
                if model.storage.count == 3 {
                    LessonButton(title: "Lihat ke dalam leuit", identifier: "leuit.inspect", action: model.inspectInterior)
                }
            }
        }.disabled(model.isDemonstrating)
    }
}
