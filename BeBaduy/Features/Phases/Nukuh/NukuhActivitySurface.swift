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
            .accessibilityIdentifier("nukuh.field")
            .overlay(alignment: .top) {
                if (model.scene.stage == .prepared || model.scene.stage == .burning) && model.scene.ignited.count < 6 && !model.isDemonstrating {
                    Text("Ketuk setiap lahan untuk menyalakan api · \(model.scene.ignited.count)/6")
                        .font(.headline).multilineTextAlignment(.center).padding(16)
                        .foregroundStyle(.white).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 24).padding(.top, 70)
                        .allowsHitTesting(false).accessibilityIdentifier("nukuh.fire.hint")
                }
            }
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
                if stage == .prepared && !model.isDemonstrating {
                    sheet.collapse()
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
