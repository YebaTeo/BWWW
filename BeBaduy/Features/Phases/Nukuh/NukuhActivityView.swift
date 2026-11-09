import SwiftUI
struct NukuhActivityView: View {
    let model: NukuhViewModel
    @Environment(\.dynamicTypeSize) private var typeSize
    private var motionLayout: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.motionActive
                 ? "Gerakkan ponsel perlahan untuk melihat sekeliling. Geser mendatar juga bisa."
                 : "Geser untuk melihat lahan.")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            motionLayout {
                Button(model.motionEnabled ? "Geser saja" : "Gerakan ponsel", action: model.toggleLookMotion)
                    .frame(minHeight: 44).accessibilityIdentifier("nukuh.motion")
                Button("Pusatkan", action: model.recenterLook)
                    .frame(minHeight: 44).accessibilityIdentifier("nukuh.recenter")
            }
            if !model.motionMessage.isEmpty { Text(model.motionMessage).font(.footnote) }
            if model.scene.loadingAssets { ProgressView("Menyiapkan lahan…") }
            if let error = model.scene.assetError {
                Text(error)
                Button("Coba lagi") { Task { await model.scene.prepareAssets() } }
            }
            switch model.scene.stage {
            case .entering: Text("Lingkungan virtual tanpa kamera")
            case .clearing:
                Text("Ketuk pohon untuk menebang. Geser di lahan untuk melihat sekeliling.")
                    .accessibilityIdentifier("nukuh.sceneReady")
                Text("\(model.collected.count) / 6 pohon").accessibilityIdentifier("nukuh.progress")
                ForEach(0..<6) { index in
                    ActivityChoice(title: "Tebang pohon \(index + 1)", symbol: "tree", done: model.collected.contains(index), identifier: "nukuh.cut.\(index)") { model.collect(index) }
                }.disabled(model.isDemonstrating)
            case .prepared, .burning:
                Text("Ketuk setiap lahan untuk menyalakan api virtual").font(.headline)
                Text("Api hanya menyala pada lahan yang kamu ketuk. Geser untuk menemukan lahan lainnya, atau gunakan tombol di bawah.")
                Text("\(model.scene.ignited.count) / 6 lahan dinyalakan")
                    .accessibilityIdentifier("nukuh.fire.progress")
                ForEach(0..<6) { index in
                    ActivityChoice(title: "Nyalakan lahan \(index + 1)", symbol: "flame", done: model.scene.ignited.contains(index), identifier: "nukuh.ignite.\(index)") {
                        model.burn(startingAt: index)
                    }
                }.disabled(model.isDemonstrating)
                if model.scene.ignited.count == 6 {
                    Text("Amati api mereda dan permukaan lahan berubah.")
                    ProgressView(value: model.scene.progress).accessibilityLabel("Perubahan lahan")
                    Button("Tampilkan kondisi setelah api reda") { model.scene.finishBurn() }.frame(minHeight: 44)
                        .accessibilityIdentifier("nukuh.finishBurn")
                }
            case .complete: Text("Lahan sudah siap")
            }
        }
    }
}
