import SceneKit
import SwiftUI

/// 3D Traditional Baduy "Kored" (Curved Hand Weeding Hoe).
///
/// Crafted in SceneKit with:
/// - Hand-turned ergonomic hardwood handle (gagang kai)
/// - Forged iron neck collar (leher beusi)
/// - Angled crescent steel blade (bilah waja melengkung) with razor cutting edge
/// - PBR metallic reflection and realistic directional lighting
struct Kored3DView: View {
    var body: some View {
        KoredSceneView()
            .frame(width: 88, height: 130)
            .accessibilityHidden(true)
    }
}

private struct KoredSceneView: UIViewRepresentable {
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

        context.coordinator.setupScene(in: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    final class Coordinator: NSObject {
        private weak var scnView: SCNView?

        func setupScene(in view: SCNView) {
            self.scnView = view
            let scene = SCNScene()
            view.scene = scene

            // 1. Perspective Camera
            let camera = SCNCamera()
            camera.fieldOfView = 36
            camera.zNear = 0.05
            camera.zFar = 10.0
            camera.wantsHDR = false
            camera.exposureOffset = 0.2

            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0.15, 0.85)
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

            // 3. Build the 3D Kored Model
            let koredRoot = SCNNode()
            koredRoot.name = "koredRoot"
            // Set natural angled slashing orientation
            koredRoot.eulerAngles = SCNVector3(0.24, -0.32, -0.42)

            // Hardwood Handle Material
            let woodMat = SCNMaterial()
            woodMat.lightingModel = .physicallyBased
            woodMat.diffuse.contents = UIImage(named: "HumaWoodTexture")
                ?? UIColor(red: 0.72, green: 0.50, blue: 0.28, alpha: 1)
            woodMat.multiply.contents = UIColor(red: 0.82, green: 0.60, blue: 0.34, alpha: 1)
            woodMat.roughness.contents = 0.65
            woodMat.metalness.contents = 0.04

            // Forged Iron Neck Material
            let ironMat = SCNMaterial()
            ironMat.lightingModel = .physicallyBased
            ironMat.diffuse.contents = UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1)
            ironMat.roughness.contents = 0.52
            ironMat.metalness.contents = 0.78

            // Forged Steel Blade Material
            let bladeMat = SCNMaterial()
            bladeMat.lightingModel = .physicallyBased
            bladeMat.diffuse.contents = UIColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1)
            bladeMat.roughness.contents = 0.28
            bladeMat.metalness.contents = 0.92

            // ── A. Ergonomic Hardwood Handle ─────────────────────────────
            let handleGeo = SCNCylinder(radius: 0.024, height: 0.26)
            handleGeo.radialSegmentCount = 32
            handleGeo.materials = [woodMat]
            let handleNode = SCNNode(geometry: handleGeo)
            handleNode.position = SCNVector3(0.04, 0.12, 0)
            handleNode.eulerAngles.z = 0.22
            koredRoot.addChildNode(handleNode)

            // Rounded Handle Butt Cap
            let buttGeo = SCNSphere(radius: 0.025)
            buttGeo.materials = [woodMat]
            let buttNode = SCNNode(geometry: buttGeo)
            buttNode.position = SCNVector3(0, 0.13, 0)
            handleNode.addChildNode(buttNode)

            // ── B. Forged Iron Ferrule & Neck ────────────────────────────
            let ferruleGeo = SCNCylinder(radius: 0.025, height: 0.028)
            ferruleGeo.radialSegmentCount = 32
            ferruleGeo.materials = [ironMat]
            let ferruleNode = SCNNode(geometry: ferruleGeo)
            ferruleNode.position = SCNVector3(0, -0.13, 0)
            handleNode.addChildNode(ferruleNode)

            // Curved neck connecting handle to hoe blade
            let neckGeo = SCNCylinder(radius: 0.012, height: 0.14)
            neckGeo.radialSegmentCount = 24
            neckGeo.materials = [ironMat]
            let neckNode = SCNNode(geometry: neckGeo)
            neckNode.position = SCNVector3(-0.02, -0.05, 0)
            neckNode.eulerAngles.z = -0.55
            koredRoot.addChildNode(neckNode)

            // ── C. Curved Forged Steel Hoe Blade (Bilah Kored) ───────────
            let bladeGeo = SCNBox(width: 0.14, height: 0.065, length: 0.007, chamferRadius: 0.003)
            bladeGeo.materials = [bladeMat]
            let bladeNode = SCNNode(geometry: bladeGeo)
            bladeNode.position = SCNVector3(-0.09, -0.10, 0)
            bladeNode.eulerAngles = SCNVector3(-0.15, 0.40, 0.35)
            koredRoot.addChildNode(bladeNode)

            // Cutting Edge Bevel
            let edgeGeo = SCNCylinder(radius: 0.005, height: 0.14)
            edgeGeo.radialSegmentCount = 16
            edgeGeo.materials = [bladeMat]
            let edgeNode = SCNNode(geometry: edgeGeo)
            edgeNode.eulerAngles.z = .pi / 2
            edgeNode.position = SCNVector3(0, -0.032, 0)
            bladeNode.addChildNode(edgeNode)

            scene.rootNode.addChildNode(koredRoot)
        }

        func cleanup() {
            scnView?.scene = nil
            scnView = nil
        }
    }
}

