import SceneKit
import SwiftUI
import simd

/// 3D Traditional Baduy "Kored" (Curved Hand Weeding Hoe).
///
/// Loads the supplied kored2.usdz model into a lit SceneKit scene and keeps
/// the existing tap/drag swing motion on its normalized model root.
struct Kored3DView: View {
    var isDragging = false
    var swingCount = 0
    var bladeCentered = false
    var body: some View {
        KoredSceneView(isDragging: isDragging, swingCount: swingCount, bladeCentered: bladeCentered)
            .accessibilityHidden(true)
    }
}

private struct KoredSceneView: UIViewRepresentable {
    let isDragging: Bool
    let swingCount: Int
    let bladeCentered: Bool
    func makeCoordinator() -> Coordinator {
        Coordinator(bladeCentered: bladeCentered)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue
        ])
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.isOpaque = false
        view.autoenablesDefaultLighting = false
        view.isPlaying = true
        view.rendersContinuously = true

        context.coordinator.setupScene(in: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(isDragging: isDragging, swingCount: swingCount)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    final class Coordinator: NSObject {
        private let bladeCentered: Bool
        private weak var scnView: SCNView?
        private var tool: SCNNode?
        private var dragging = false
        private var lastSwingCount = 0

        init(bladeCentered: Bool) {
            self.bladeCentered = bladeCentered
        }

        func update(isDragging value: Bool, swingCount: Int) {
            guard let tool else { return }
            if swingCount != lastSwingCount {
                lastSwingCount = swingCount
                let dip = SCNAction.rotateTo(x: 0.82, y: bladeCentered ? .pi - 0.78 : -0.78,
                                             z: -0.16, duration: 0.11, usesShortestUnitArc: true)
                dip.timingMode = .easeIn
                let contact = SCNAction.move(to: SCNVector3(0, 0, 0), duration: 0.11)
                contact.timingMode = .easeIn
                let recover = SCNAction.rotateTo(x: 0.24, y: bladeCentered ? .pi - 0.32 : -0.32,
                                                 z: -0.42, duration: 0.22, usesShortestUnitArc: true)
                recover.timingMode = .easeOut
                let lift = SCNAction.move(to: SCNVector3(0, bladeCentered ? -0.08 : 0, 0), duration: 0.22)
                lift.timingMode = .easeOut
                tool.runAction(.sequence([.group([dip, contact]), .group([recover, lift])]), forKey: "koredSwing")
            }
            guard value != dragging else { return }
            dragging = value
            let rotation = SCNAction.rotateTo(x: value ? 0.45 : 0.24,
                                              y: bladeCentered ? .pi - (value ? 0.65 : 0.32) : (value ? -0.65 : -0.32),
                                              z: -0.42, duration: 0.16, usesShortestUnitArc: true)
            rotation.timingMode = .easeOut
            tool.runAction(rotation, forKey: "workingTilt")
        }

        func setupScene(in view: SCNView) {
            self.scnView = view
            let scene = SCNScene()
            view.scene = scene
            scene.lightingEnvironment.contents = UIImage(named: "HumaEnvironment")
            scene.lightingEnvironment.intensity = 0.85

            // 1. Perspective Camera
            let camera = SCNCamera()
            // Fit the extended haft inside the tall portrait SceneKit viewport.
            camera.fieldOfView = 50
            camera.projectionDirection = .vertical
            camera.zNear = 0.05
            camera.zFar = 10.0
            camera.wantsHDR = false
            camera.exposureOffset = 0.2

            let cameraNode = SCNNode()
            cameraNode.camera = camera
            // Center the framing on the full haft, whose top now rises above
            // the blade root. Keeping the old low look-at point cropped it.
            cameraNode.position = SCNVector3(0, 0, bladeCentered ? 2.15 : 1.55)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(cameraNode)

            // 2. Sunlight & Metallic Rim
            let sun = SCNLight()
            sun.type = .directional
            sun.color = UIColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1)
            sun.intensity = 1100
            let sunNode = SCNNode()
            sunNode.light = sun
            sunNode.position = SCNVector3(1.5, 2.5, 1.8)
            sunNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(sunNode)

            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = UIColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 1)
            ambient.intensity = 450
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            let rim = SCNLight()
            rim.type = .directional
            rim.color = UIColor(red: 1.0, green: 0.92, blue: 0.80, alpha: 1)
            rim.intensity = 400
            let rimNode = SCNNode()
            rimNode.light = rim
            rimNode.position = SCNVector3(-1.8, 1.2, -1.0)
            rimNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(rimNode)

            // 3. Load the supplied USDZ kored and fit it to the hand-sized viewport.
            let modelURL = Bundle.main.url(forResource: "kored2", withExtension: "usdz")
                ?? Bundle.main.url(forResource: "kored2", withExtension: "usdz", subdirectory: "Asset/Ngored")
            guard let modelURL,
                  let sourceScene = try? SCNScene(url: modelURL, options: nil) else {
                assertionFailure("Could not load Asset/Ngored/kored2.usdz")
                return
            }

            let importedModel = sourceScene.rootNode.clone()
            importedModel.enumerateChildNodes { node, _ in
                if node.camera != nil || node.light != nil {
                    node.removeFromParentNode()
                }
            }

            let bounds = importedModel.boundingBox
            let width = bounds.max.x - bounds.min.x
            let height = bounds.max.y - bounds.min.y
            let depth = bounds.max.z - bounds.min.z
            let longestSide = max(width, max(height, depth))
            guard longestSide > 0.0001 else {
                assertionFailure("The supplied kored USDZ has empty geometry")
                return
            }

            let fitScale: Float = 1.0 / longestSide
            // The imported model's iron head is at its right, lower end.
            // Put that edge at the SceneKit origin for field strikes.
            let center = SCNVector3(
                bladeCentered ? bounds.max.x - width * 0.07 : (bounds.min.x + bounds.max.x) * 0.5,
                bladeCentered ? bounds.min.y + height * 0.10 : (bounds.min.y + bounds.max.y) * 0.5,
                (bounds.min.z + bounds.max.z) * 0.5
            )
            importedModel.scale = SCNVector3(fitScale, fitScale, fitScale)
            importedModel.position = SCNVector3(-center.x * fitScale,
                                                -center.y * fitScale,
                                                -center.z * fitScale)

            let koredRoot = SCNNode()
            koredRoot.name = "koredRoot"
            koredRoot.eulerAngles = SCNVector3(0.24, bladeCentered ? .pi - 0.32 : -0.32, -0.42)
            koredRoot.position.y = bladeCentered ? -0.08 : 0
            koredRoot.addChildNode(importedModel)
            scene.rootNode.addChildNode(koredRoot)
            tool = koredRoot
        }

        func cleanup() {
            tool?.removeAllActions()
            tool = nil
            scnView?.isPlaying = false
            scnView?.rendersContinuously = false
            scnView?.scene = nil
            scnView = nil
        }
    }
}

