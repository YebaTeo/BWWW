import SwiftUI
struct NukuhActivityView: View {
    let model: NukuhViewModel
    @Environment(\.dynamicTypeSize) private var typeSize
    private var motionLayout: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
    }
    @Environment(ActivityCardState.self) private var card
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if card.mode == .help { motionLayout {
                Button(action: model.toggleLookMotion) {
                    Text(model.motionEnabled ? "Geser saja" : "Gerakan ponsel")
                        .fixedSize(horizontal: false, vertical: true)
                }
                    .frame(minHeight: 44).accessibilityIdentifier("nukuh.motion")
                Button("Pusatkan", action: model.recenterLook)
                    .frame(minHeight: 44).accessibilityIdentifier("nukuh.recenter")
            }
            }
            if !model.motionMessage.isEmpty { Text(model.motionMessage).font(.footnote) }
            if model.scene.loadingAssets { ProgressView("Menyiapkan lahan…") }
            if let error = model.scene.assetError {
                Text(error)
                Button("Coba lagi") { Task { await model.scene.prepareAssets() } }
            }
            switch model.stage {
            case .entering: Text("Lingkungan virtual tanpa kamera")
            case .clearing:
                Text(model.motionActive
                     ? "Ketuk pohon untuk menebang. Gerakkan ponsel perlahan untuk melihat sekeliling."
                     : "Ketuk pohon untuk menebang. Geser di lahan untuk melihat sekeliling.")
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("nukuh.sceneReady")
                Text("\(model.collected.count) / 6 pohon").accessibilityIdentifier("nukuh.progress")
                if card.mode == .instruction {
                    LessonButton(title: "Mulai", identifier: "activity.card.start") { card.dismiss() }
                } else {
                ForEach(0..<6) { index in
                    ActivityChoice(title: "Tebang pohon \(index + 1)", symbol: "tree", done: model.collected.contains(index), identifier: "nukuh.cut.\(index)") { model.collect(index) }
                }.disabled(model.isDemonstrating)
                }
            case .prepared, .burning:
                Text("Ketuk setiap lahan untuk menyalakan api virtual").font(.headline)
                Text("Api hanya menyala pada lahan yang kamu ketuk. Geser untuk menemukan lahan lainnya, atau gunakan tombol di bawah.")
                Text("\(model.ignited.count) / 6 lahan dinyalakan")
                    .accessibilityIdentifier("nukuh.fire.progress")
                if card.mode == .instruction && model.ignited.count < 6 {
                    LessonButton(title: "Lanjut", identifier: "nukuh.fire.begin") { card.dismiss() }
                } else if card.mode == .help {
                ForEach(0..<6) { index in
                    ActivityChoice(title: "Nyalakan lahan \(index + 1)", symbol: "flame", done: model.ignited.contains(index), identifier: "nukuh.ignite.\(index)") {
                        model.burn(startingAt: index)
                    }
                }.disabled(model.isDemonstrating)
                }
                if model.ignited.count == 6 {
                    Text("Amati api mereda dan permukaan lahan berubah.")
                    ProgressView(value: model.scene.progress).accessibilityLabel("Perubahan lahan")
                    Button("Tampilkan kondisi setelah api reda") { model.finishBurn() }.frame(minHeight: 44)
                        .accessibilityIdentifier("nukuh.finishBurn")
                }
            case .complete: Text("Lahan sudah siap")
            }
        }
    }
}
