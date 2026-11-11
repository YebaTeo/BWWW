import SceneKit
import SwiftUI

/// 3D Dibble Planting Hole (Lubang Tanam Aseuk) rendered with SceneKit.
///
/// Designed to match the exact soil and seed aesthetics of Home Stage 3 (buildPlantingStage):
/// - Excavated circular earthen collar with loose soil clods (torus rim)
/// - Deep recessed fertile cavity with dark soil shadow
/// - 3 to 4 clustered golden unhulled rice grains (gabah) when seeded
/// - Concentric targeted huma furrow guide when undug
struct DibbleHole3DView: View {
    let dug: Bool
    let seeded: Bool
    let focused: Bool

    var body: some View {
        DibbleHoleSceneView(dug: dug, seeded: seeded, focused: focused)
            .frame(width: 84, height: 56)
            .accessibilityHidden(true)
    }
}

private struct DibbleHoleSceneView: UIViewRepresentable {
    let dug: Bool
    let seeded: Bool
    let focused: Bool

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

        context.coordinator.setupScene(in: view, dug: dug, seeded: seeded, focused: focused)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(dug: dug, seeded: seeded, focused: focused)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    @MainActor
    final class Coordinator: NSObject {
        private weak var scnView: SCNView?
        private var holeNode: SCNNode?
        private var targetNode: SCNNode?
        private var seedsGroupNode: SCNNode?
        private var focusGlowNode: SCNNode?

        func setupScene(in view: SCNView, dug: Bool, seeded: Bool, focused: Bool) {
            self.scnView = view
            let scene = SCNScene()
            view.scene = scene

            // 1. Perspective Camera looking down at ~50° angle onto huma soil
            let camera = SCNCamera()
            camera.fieldOfView = 36
            camera.zNear = 0.05
            camera.zFar = 10.0
            camera.exposureOffset = 0.2
            camera.wantsHDR = false

            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0.45, 0.60)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(cameraNode)

            // 2. Warm Sun Key & Sky Ambient Lighting
            let sun = SCNLight()
            sun.type = .directional
            sun.color = UIColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1)
            sun.intensity = 850
            let sunNode = SCNNode()
            sunNode.light = sun
            sunNode.position = SCNVector3(1.2, 2.0, 1.5)
            sunNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(sunNode)

            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = UIColor(red: 0.88, green: 0.85, blue: 0.82, alpha: 1)
            ambient.intensity = 380
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            // 3. Root Container
            let root = SCNNode()
            root.name = "holeRoot"
            scene.rootNode.addChildNode(root)

            // ── Undug Target Guide ───────────────────────────────────────
            let targetGroup = SCNNode()
            targetGroup.name = "targetGuide"

            let targetRingGeo = SCNTorus(ringRadius: 0.085, pipeRadius: 0.0035)
            targetRingGeo.ringSegmentCount = 32
            let targetMat = SCNMaterial()
            targetMat.lightingModel = .constant
            targetMat.diffuse.contents = UIColor(red: 1.0, green: 0.92, blue: 0.75, alpha: 0.85)
            targetRingGeo.materials = [targetMat]
            let targetRing = SCNNode(geometry: targetRingGeo)
            targetRing.scale = SCNVector3(1.0, 0.35, 1.0)
            targetGroup.addChildNode(targetRing)

            let glowGeo = SCNPlane(width: 0.22, height: 0.12)
            let glowMat = SCNMaterial()
            glowMat.lightingModel = .constant
            glowMat.diffuse.contents = UIColor(red: 1.0, green: 0.85, blue: 0.45, alpha: 0.22)
            glowMat.isDoubleSided = true
            glowGeo.materials = [glowMat]
            let glowNode = SCNNode(geometry: glowGeo)
            glowNode.eulerAngles.x = -.pi / 2
            glowNode.position.y = 0.001
            targetGroup.addChildNode(glowNode)
            self.focusGlowNode = glowNode

            root.addChildNode(targetGroup)
            self.targetNode = targetGroup

            // ── Excavated 3D Dibble Hole (matching HomeView Stage 3 Ngored) ────
            let holeGroup = SCNNode()
            holeGroup.name = "excavatedHole"

            // Earthen Torus Collar matching HomeView line 1107
            let rimGeo = SCNTorus(ringRadius: 0.078, pipeRadius: 0.024)
            rimGeo.ringSegmentCount = 36
            rimGeo.pipeSegmentCount = 18
            let rimMat = SCNMaterial()
            rimMat.lightingModel = .physicallyBased
            rimMat.diffuse.contents  = UIColor(red: 0.10, green: 0.06, blue: 0.035, alpha: 1)
            rimMat.roughness.contents = 1.0
            rimMat.metalness.contents = 0.0
            rimGeo.materials = [rimMat]
            let rimNode = SCNNode(geometry: rimGeo)
            rimNode.scale = SCNVector3(1.0, 0.42, 0.82)
            holeGroup.addChildNode(rimNode)

            // Deep Dark Cavity Interior
            let cavityGeo = SCNCone(topRadius: 0.072, bottomRadius: 0.008, height: 0.065)
            cavityGeo.radialSegmentCount = 24
            let cavityMat = SCNMaterial()
            cavityMat.lightingModel = .lambert
            cavityMat.diffuse.contents = UIColor(red: 0.05, green: 0.03, blue: 0.015, alpha: 1)
            cavityGeo.materials = [cavityMat]
            let cavityNode = SCNNode(geometry: cavityGeo)
            cavityNode.eulerAngles.x = .pi // Pointing downwards into earth
            cavityNode.position.y = -0.015
            cavityNode.scale = SCNVector3(1.0, 1.0, 0.78)
            holeGroup.addChildNode(cavityNode)

            // Loose Soil Clods around rim
            let clodMat = SCNMaterial()
            clodMat.lightingModel = .physicallyBased
            clodMat.diffuse.contents = UIColor(red: 0.18, green: 0.11, blue: 0.06, alpha: 1)
            clodMat.roughness.contents = 0.96
            for i in 0..<8 {
                let angle = Float(i) * (.pi / 4.0) + Float(i) * 0.12
                let dist: Float = 0.092 + Float(i % 3) * 0.012
                let clodGeo = SCNSphere(radius: CGFloat(0.009 + Float(i % 2) * 0.004))
                clodGeo.materials = [clodMat]
                let clodNode = SCNNode(geometry: clodGeo)
                clodNode.scale = SCNVector3(1.2, 0.6, 1.0)
                clodNode.position = SCNVector3(cos(angle) * dist, 0.006, sin(angle) * dist * 0.78)
                holeGroup.addChildNode(clodNode)
            }

            // ── 3D Seeds matching HomeView Stage 3 Ngored (line 1121) ────
            let seedsGroup = SCNNode()
            seedsGroup.name = "seedsInside"

            let seedMat = SCNMaterial()
            seedMat.lightingModel = .lambert
            seedMat.diffuse.contents  = UIColor(red: 0.95, green: 0.90, blue: 0.78, alpha: 1)
            seedMat.roughness.contents = 0.70
            seedMat.metalness.contents = 0.0

            let seedOffsets: [(x: Float, z: Float)] = [
                (-0.014, 0.004),
                (0.012, -0.005),
                (0.002, 0.012),
                (0.004, -0.011)
            ]
            for offset in seedOffsets {
                let seedGeo = SCNSphere(radius: 0.013)
                seedGeo.segmentCount = 12
                seedGeo.materials = [seedMat]
                let seedNode = SCNNode(geometry: seedGeo)
                seedNode.position = SCNVector3(offset.x, -0.006, offset.z)
                seedsGroup.addChildNode(seedNode)
            }
            holeGroup.addChildNode(seedsGroup)
            self.seedsGroupNode = seedsGroup

            root.addChildNode(holeGroup)
            self.holeNode = holeGroup

            applyState(dug: dug, seeded: seeded, focused: focused)
        }

        func update(dug: Bool, seeded: Bool, focused: Bool) {
            applyState(dug: dug, seeded: seeded, focused: focused)
        }

        private func applyState(dug: Bool, seeded: Bool, focused: Bool) {
            targetNode?.isHidden = dug
            focusGlowNode?.opacity = focused ? 1.0 : 0.45
            holeNode?.isHidden = !dug
            seedsGroupNode?.isHidden = !seeded
            if seeded {
                seedsGroupNode?.opacity = 1.0
            }
        }

        func cleanup() {
            scnView?.scene = nil
            scnView = nil
            holeNode = nil
            targetNode = nil
            seedsGroupNode = nil
            focusGlowNode = nil
        }
    }
}

