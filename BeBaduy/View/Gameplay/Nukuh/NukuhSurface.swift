import SceneKit
import SwiftUI

struct NukuhSurface: UIViewRepresentable {
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
