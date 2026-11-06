import RealityKit
import SwiftUI
struct NukuhActivityView: View {
    let model: NukuhViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 16) {
            NukuhSurface(scene: model.scene).frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
            Text(model.motionActive
                 ? "Gerakkan ponsel perlahan untuk melihat sekeliling. Geser mendatar juga bisa."
                 : "Geser mendatar di lahan untuk melihat sekeliling.")
                .font(.subheadline)
            HStack {
                Button(model.motionEnabled ? "Gunakan geseran saja" : "Aktifkan gerakan ponsel", action: model.toggleLookMotion)
                    .frame(minHeight: 44).accessibilityIdentifier("nukuh.motion")
                Button("Pusatkan pandangan", action: model.recenterLook)
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
            case .prepared:
                InstructionCard(title: "Pohon berhasil ditebang", message: "Selanjutnya, amati perubahan lahan saat sisa tumbuhan dibakar dalam adegan virtual.", identifier: "nukuh.burn", action: model.burn)
            case .burning:
                Text("Amati api mereda dan permukaan lahan berubah.")
                ProgressView(value: model.scene.progress).accessibilityLabel("Perubahan lahan")
                Button("Tampilkan kondisi setelah api reda") { model.scene.finishBurn() }.frame(minHeight: 44)
                    .accessibilityIdentifier("nukuh.finishBurn")
            case .complete: Text("Lahan sudah siap")
            }
        }.task { model.configureLookMotion(reduceMotion: reduceMotion); model.scene.muted = !ActivityAudio.shared.enabled; await model.scene.prepareAssets(); await model.scene.loadAudio() }
            .onChange(of: ActivityAudio.shared.enabled) { _, enabled in model.scene.muted = !enabled }
            .onChange(of: reduceMotion) { _, value in model.configureLookMotion(reduceMotion: value) }
    }
}
private struct NukuhSurface: UIViewRepresentable {
    let scene: NgahumaScene
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        scene.attach(view); return view
    }
    func updateUIView(_ view: ARView, context: Context) {}
    func makeCoordinator() -> NgahumaScene { scene }
    static func dismantleUIView(_ view: ARView, coordinator: NgahumaScene) { coordinator.stop() }
}
