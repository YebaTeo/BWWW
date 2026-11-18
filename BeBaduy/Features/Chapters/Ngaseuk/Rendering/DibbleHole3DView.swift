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
    let digCount: Int
    let seeded: Bool
    let focused: Bool

    var body: some View {
        DibbleHoleSceneView(digCount: digCount, seeded: seeded, focused: focused)
            .frame(width: 84, height: 56)
            .accessibilityHidden(true)
    }
}

private struct DibbleHoleSceneView: UIViewRepresentable {
    let digCount: Int
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

        context.coordinator.setupScene(in: view, digCount: digCount, seeded: seeded, focused: focused)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(digCount: digCount, seeded: seeded, focused: focused)
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

        func setupScene(in view: SCNView, digCount: Int, seeded: Bool, focused: Bool) {
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

            // Reuse the same disturbed-soil patch, rim, and cavity as HomeView Ngored.
            let holeGroup = HomeSceneRenderer.makePlantingHoleNode()
            holeGroup.name = "excavatedHole"

            // ── 3D Seeds matching HomeView Stage 3 Ngored (line 1121) ────
            let seedsGroup = SCNNode()
            seedsGroup.name = "seedsInside"

            let seedOffsets: [(x: Float, z: Float)] = [
                (-0.004, 0.001),
                (0.004, -0.001),
                (0.001, 0.004),
                (0.001, -0.004)
            ]
            for offset in seedOffsets {
                let seedNode = HomeSceneRenderer.makePlantingSeedNode()
                seedNode.position = SCNVector3(offset.x, -0.002, offset.z)
                seedsGroup.addChildNode(seedNode)
            }
            holeGroup.addChildNode(seedsGroup)
            self.seedsGroupNode = seedsGroup

            root.addChildNode(holeGroup)
            self.holeNode = holeGroup

            applyState(digCount: digCount, seeded: seeded, focused: focused)
        }

        func update(digCount: Int, seeded: Bool, focused: Bool) {
            applyState(digCount: digCount, seeded: seeded, focused: focused)
        }

        private func applyState(digCount: Int, seeded: Bool, focused: Bool) {
            targetNode?.isHidden = digCount > 0
            focusGlowNode?.opacity = focused ? 1.0 : 0.45
            holeNode?.isHidden = digCount == 0
            let completedStrokes = min(3, max(0, digCount))
            let scale: Float = switch completedStrokes {
            case 0: 0.5
            case 1: 1.0
            case 2: 1.8
            default: 2.7
            }
            holeNode?.scale = SCNVector3(scale, 1, scale)
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

