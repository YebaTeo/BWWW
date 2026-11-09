import SceneKit
import SwiftUI

struct NukuhActivitySurface: View {
    let model: NukuhViewModel
    @Environment(ActivitySheetState.self) private var sheet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NukuhSurface(scene: model.scene)
            .ignoresSafeArea()
            .accessibilityLabel("Lahan Nukuh tiga dimensi")
            .task {
                model.configureLookMotion(reduceMotion: reduceMotion)
                model.scene.muted = !ActivityAudio.shared.enabled
                await model.scene.prepareAssets()
                await model.scene.loadAudio()
            }
            .onChange(of: ActivityAudio.shared.enabled) { _, enabled in
                model.scene.muted = !enabled
            }
            .onChange(of: reduceMotion) { _, value in
                model.configureLookMotion(reduceMotion: value)
            }
            .onChange(of: model.scene.stage) { _, stage in
                if stage == .prepared {
                    sheet.expand()
                }
            }
    }
}

private struct NukuhSurface: UIViewRepresentable {
    let scene: NgahumaScene

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue
        ])
        scene.attach(view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}

    func makeCoordinator() -> NgahumaScene { scene }

    static func dismantleUIView(_ view: SCNView, coordinator: NgahumaScene) {
        coordinator.stop()
    }
}
