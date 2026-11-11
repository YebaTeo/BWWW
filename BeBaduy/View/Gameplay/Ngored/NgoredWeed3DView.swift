import SceneKit
import SwiftUI

/// 3D Mountain Weed (Gulma Huma) rendered in SceneKit.
///
/// Features:
/// - 3D wild grass bunch with multiple curved organic leaf blades
/// - Gentle real-time ambient wind sway
/// - 3D physics tumble / wilting fall when slashed by the kored
struct NgoredWeed3DView: View {
    let cut: Bool
    let hits: Int

    var body: some View {
        NgoredWeedSceneView(cut: cut, hits: hits)
            .frame(width: 80, height: 95)
            .accessibilityHidden(true)
    }
}

private struct NgoredWeedSceneView: UIViewRepresentable {
    let cut: Bool
    let hits: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue
        ])
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling2X
        view.isOpaque = false
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = true

        context.coordinator.setupScene(in: view, cut: cut, hits: hits)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(cut: cut, hits: hits)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    final class Coordinator: NSObject {
        private weak var scnView: SCNView?
        private var weedRootNode: SCNNode?
        private var leafNodes: [SCNNode] = []
        private var displayLink: CADisplayLink?
        private var startTime: CFTimeInterval = 0
        private var isCut = false
        private var currentHits = 0

        func setupScene(in view: SCNView, cut: Bool, hits: Int) {
            self.scnView = view
            let scene = SCNScene()
            view.scene = scene

            // 1. Perspective Camera
            let camera = SCNCamera()
            camera.fieldOfView = 36
            camera.zNear = 0.05
            camera.zFar = 10.0
            camera.exposureOffset = 0.2
            camera.wantsHDR = false

            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0.20, 0.85)
            cameraNode.look(at: SCNVector3(0, 0.08, 0))
            scene.rootNode.addChildNode(cameraNode)

            // 2. Sunlight & Ambient Fill
            let sun = SCNLight()
            sun.type = .directional
            sun.color = UIColor(red: 1.0, green: 0.98, blue: 0.88, alpha: 1)
            sun.intensity = 950
            let sunNode = SCNNode()
            sunNode.light = sun
            sunNode.position = SCNVector3(1.5, 2.5, 1.8)
            sunNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(sunNode)

            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = UIColor(red: 0.88, green: 0.92, blue: 0.85, alpha: 1)
            ambient.intensity = 420
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            // 3. Build 3D Weed Clump
            let root = SCNNode()
            root.name = "weedRoot"

            // Leaf Material (Rich Mountain Green)
            let leafMat = SCNMaterial()
            leafMat.lightingModel = .physicallyBased
            leafMat.diffuse.contents = UIColor(red: 0.32, green: 0.58, blue: 0.18, alpha: 1)
            leafMat.roughness.contents = 0.65
            leafMat.metalness.contents = 0.02
            leafMat.isDoubleSided = true

            let stemMat = SCNMaterial()
            stemMat.lightingModel = .physicallyBased
            stemMat.diffuse.contents = UIColor(red: 0.24, green: 0.44, blue: 0.14, alpha: 1)
            stemMat.roughness.contents = 0.80

            // Center Stem
            let stemGeo = SCNCylinder(radius: 0.007, height: 0.18)
            stemGeo.radialSegmentCount = 16
            stemGeo.materials = [stemMat]
            let stemNode = SCNNode(geometry: stemGeo)
            stemNode.position = SCNVector3(0, 0.09, 0)
            root.addChildNode(stemNode)

            // 6 Radiating Curved 3D Grass Blades
            let leafConfigs: [(yaw: Float, pitch: Float, roll: Float, height: CGFloat, y: Float)] = [
                (-0.45, 0.28, -0.42, 0.16, 0.08),
                (0.40, 0.32, 0.48, 0.17, 0.09),
                (-0.95, 0.18, -0.65, 0.14, 0.06),
                (0.85, 0.22, 0.58, 0.15, 0.07),
                (-0.15, 0.45, -0.18, 0.18, 0.10),
                (0.12, 0.42, 0.22, 0.19, 0.11)
            ]

            for config in leafConfigs {
                // Curved tapered leaf blade
                let leafGeo = SCNCone(topRadius: 0.001, bottomRadius: 0.012, height: config.height)
                leafGeo.radialSegmentCount = 12
                leafGeo.materials = [leafMat]
                let leafNode = SCNNode(geometry: leafGeo)
                leafNode.scale = SCNVector3(1.0, 1.0, 0.32) // Flattened grass blade
                leafNode.position = SCNVector3(0, config.y, 0)
                leafNode.eulerAngles = SCNVector3(config.pitch, config.yaw, config.roll)
                root.addChildNode(leafNode)
                leafNodes.append(leafNode)
            }

            scene.rootNode.addChildNode(root)
            self.weedRootNode = root

            update(cut: cut, hits: hits)
            startWindAnimation()
        }

        func update(cut: Bool, hits: Int) {
            self.isCut = cut
            self.currentHits = hits

            guard let node = weedRootNode else { return }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.35

            if cut {
                // Slashed: tumbles over onto soil in 3D
                node.eulerAngles = SCNVector3(0.25, 0.15, 1.25)
                node.position = SCNVector3(0.04, -0.02, 0)
                node.opacity = 0.38
            } else {
                // Standing: tilts according to stroke hits
                let hitTilt = Float(hits) * 0.18
                node.eulerAngles = SCNVector3(0.08, 0, hitTilt)
                node.position = SCNVector3(Float(hits) * 0.006, 0, 0)
                node.opacity = 1.0
            }

            SCNTransaction.commit()
        }

        private func startWindAnimation() {
            startTime = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(onFrame(_:)))
            link.add(to: .main, forMode: .common)
            self.displayLink = link
        }

        @objc private func onFrame(_ link: CADisplayLink) {
            guard !isCut, let node = weedRootNode else { return }
            let t = Float(CACurrentMediaTime() - startTime)
            let baseTilt = Float(currentHits) * 0.18
            let windSway = sin(t * 3.2) * 0.045 + cos(t * 1.7) * 0.02
            node.eulerAngles.z = baseTilt + windSway
        }

        func cleanup() {
            displayLink?.invalidate()
            displayLink = nil
            scnView?.scene = nil
            scnView = nil
            weedRootNode = nil
            leafNodes.removeAll()
        }
    }
}

