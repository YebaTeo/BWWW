import SceneKit
import SwiftUI

struct NarawasSurface: View {
    let scene: NgahumaScene

    var body: some View {
        NarawasSceneView(scene: scene)
            .overlay {
                Color(red: 0.87, green: 0.19, blue: 0.08)
                    .opacity(Double(scene.emberTintLevel) * 0.006)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay {
                if let edge = scene.lookEdge {
                    GeometryReader { bounds in
                        let left = edge == .left
                        ZStack {
                            LinearGradient(colors: [.red.opacity(0.8), .clear],
                                           startPoint: UnitPoint(x: left ? 0 : 1, y: 0.5),
                                           endPoint: UnitPoint(x: left ? 1 : 0, y: 0.5))
                                .frame(width: min(40, bounds.size.width * 0.1))
                                .position(x: left ? min(20, bounds.size.width * 0.05)
                                          : bounds.size.width - min(20, bounds.size.width * 0.05),
                                          y: bounds.size.height / 2)

                            Label("Putar \(left ? "kanan" : "kiri") \(scene.edgeReturnDegrees)°",
                                  systemImage: left ? "arrow.right" : "arrow.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(.black.opacity(0.7), in: Capsule())
                                .position(x: left ? 100 : bounds.size.width - 100,
                                          y: bounds.size.height / 2)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

private struct NarawasSceneView: UIViewRepresentable {
    let scene: NgahumaScene

    func makeUIView(context: Context) -> SCNView {
        if let view = scene.takePreparedFieldView() {
            scene.attach(view, prepared: true)
            return view
        }
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
