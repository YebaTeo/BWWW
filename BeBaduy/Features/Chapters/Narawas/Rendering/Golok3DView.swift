import SceneKit
import SwiftUI

/// 3D Traditional Baduy "Golok" (Machete) overlay shown when swiping trees in Narawas.
struct Golok3DView: View {
    var swingCount = 0

    var body: some View {
        GolokSceneView(swingCount: swingCount)
            .accessibilityHidden(true)
    }
}

private struct GolokSceneView: UIViewRepresentable {
    let swingCount: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
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
        context.coordinator.update(swingCount: swingCount)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(swingCount: swingCount)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    @MainActor
    final class Coordinator: NSObject {
        private weak var scnView: SCNView?
        private var tool: SCNNode?
        private var lastSwingCount = 0

        func update(swingCount: Int) {
            guard let tool, swingCount != lastSwingCount else { return }
            lastSwingCount = swingCount
            let dip = SCNAction.rotateTo(x: 0.78, y: -0.72, z: 0.35, duration: 0.11, usesShortestUnitArc: true)
            dip.timingMode = .easeIn
            let contact = SCNAction.move(to: SCNVector3(0, -0.06, 0), duration: 0.11)
            contact.timingMode = .easeIn
            let recover = SCNAction.rotateTo(x: 0.24, y: -0.32, z: -0.45, duration: 0.22, usesShortestUnitArc: true)
            recover.timingMode = .easeOut
            let lift = SCNAction.move(to: SCNVector3(0, 0.04, 0), duration: 0.22)
            lift.timingMode = .easeOut
            tool.runAction(.sequence([.group([dip, contact]), .group([recover, lift])]), forKey: "golokSwing")
        }

        func setupScene(in view: SCNView) {
            self.scnView = view
            let scene = SCNScene()
            view.scene = scene
            scene.lightingEnvironment.contents = UIImage(named: "HumaEnvironment")
            scene.lightingEnvironment.intensity = 0.85

            let camera = SCNCamera()
            camera.fieldOfView = 50
            camera.projectionDirection = .vertical
            camera.zNear = 0.05
            camera.zFar = 10.0
            camera.wantsHDR = false
            camera.exposureOffset = 0.2

            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0, 2.0)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(cameraNode)

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

            let modelURL = Bundle.main.url(forResource: "GOLOK", withExtension: "usdz")
                ?? Bundle.main.url(forResource: "GOLOK", withExtension: "usdz", subdirectory: "Features/Chapters/Narawas/Resources")
            guard let modelURL,
                  let sourceScene = try? SCNScene(url: modelURL, options: nil) else {
                assertionFailure("Could not load Features/Chapters/Narawas/Resources/GOLOK.usdz")
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
                assertionFailure("The supplied GOLOK USDZ has empty geometry")
                return
            }

            let fitScale: Float = 1.1 / longestSide
            let center = SCNVector3(
                (bounds.min.x + bounds.max.x) * 0.5,
                (bounds.min.y + bounds.max.y) * 0.5,
                (bounds.min.z + bounds.max.z) * 0.5
            )
            importedModel.scale = SCNVector3(fitScale, fitScale, fitScale)
            importedModel.position = SCNVector3(
                -center.x * fitScale,
                -center.y * fitScale,
                -center.z * fitScale
            )

            let golokRoot = SCNNode()
            golokRoot.name = "golokRoot"
            golokRoot.eulerAngles = SCNVector3(0.24, -0.32, -0.45)
            golokRoot.position.y = 0.04
            golokRoot.addChildNode(importedModel)
            scene.rootNode.addChildNode(golokRoot)
            tool = golokRoot
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

