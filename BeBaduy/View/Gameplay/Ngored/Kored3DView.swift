import SceneKit
import SwiftUI
import simd

/// 3D Traditional Baduy "Kored" (Curved Hand Weeding Hoe).
///
/// Crafted in SceneKit with:
/// - Hand-turned ergonomic hardwood handle (gagang kai)
/// - Forged iron neck collar (leher beusi)
/// - Angled crescent steel blade (bilah waja melengkung) with razor cutting edge
/// - PBR metallic reflection and realistic directional lighting
struct Kored3DView: View {
    var isDragging = false
    var swingCount = 0
    var body: some View {
        KoredSceneView(isDragging: isDragging, swingCount: swingCount)
            .accessibilityHidden(true)
    }
}

private struct KoredSceneView: UIViewRepresentable {
    let isDragging: Bool
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
        private weak var scnView: SCNView?
        private var tool: SCNNode?
        private var dragging = false
        private var lastSwingCount = 0

        func update(isDragging value: Bool, swingCount: Int) {
            guard let tool else { return }
            if swingCount != lastSwingCount {
                lastSwingCount = swingCount
                let dip = SCNAction.rotateTo(x: 0.82, y: -0.78, z: -0.16, duration: 0.11, usesShortestUnitArc: true)
                dip.timingMode = .easeIn
                let recover = SCNAction.rotateTo(x: 0.24, y: -0.32, z: -0.42, duration: 0.22, usesShortestUnitArc: true)
                recover.timingMode = .easeOut
                tool.runAction(.sequence([dip, recover]), forKey: "koredSwing")
            }
            guard value != dragging else { return }
            dragging = value
            let rotation = SCNAction.rotateTo(x: value ? 0.45 : 0.24,
                                              y: value ? -0.65 : -0.32,
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
            cameraNode.position = SCNVector3(0, 0.42, 1.45)
            cameraNode.look(at: SCNVector3(0, 0.42, 0))
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
            woodMat.multiply.contents = UIColor(red: 1.0, green: 0.90, blue: 0.60, alpha: 1)
            woodMat.diffuse.contentsTransform = SCNMatrix4MakeScale(1, 3.5, 1)
            woodMat.diffuse.wrapT = .repeat
            woodMat.diffuse.maxAnisotropy = 8
            woodMat.roughness.contents = 0.58
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
            bladeMat.diffuse.contents = UIColor(red: 0.30, green: 0.32, blue: 0.33, alpha: 1)
            bladeMat.roughness.contents = 0.52
            bladeMat.metalness.contents = 0.72

            // ── A. Ergonomic Hardwood Handle ─────────────────────────────
            // Longer, tapered wooden haft to match the supplied hoe reference.
            let handleGeo = SCNCapsule(capRadius: 0.021, height: 0.92)
            handleGeo.radialSegmentCount = 32
            handleGeo.materials = [woodMat]
            let handleNode = SCNNode(geometry: handleGeo)
            handleNode.position = SCNVector3(0.04, 0.44, 0)
            handleNode.eulerAngles.z = 0.22
            koredRoot.addChildNode(handleNode)

            // ── B. Forged Iron Ferrule & Neck ────────────────────────────
            let ferruleGeo = SCNCylinder(radius: 0.025, height: 0.028)
            ferruleGeo.radialSegmentCount = 32
            ferruleGeo.materials = [ironMat]
            let ferruleNode = SCNNode(geometry: ferruleGeo)
            ferruleNode.position = SCNVector3(0, -0.44, 0)
            handleNode.addChildNode(ferruleNode)

            // A continuous bent shank joins the socket to the blade.
            let socket = handleNode.convertPosition(SCNVector3(0, -0.44, 0), to: koredRoot)
            let points: [SIMD3<Float>] = [
                SIMD3(socket.x, socket.y, socket.z),
                SIMD3(0.025, -0.045, 0), SIMD3(-0.025, -0.075, 0.012),
                SIMD3(-0.075, -0.10, 0.012)
            ]
            for index in 0..<(points.count - 1) {
                let start = points[index]
                let end = points[index + 1]
                let shaft = SCNCylinder(radius: 0.010, height: CGFloat(simd_length(end - start)))
                shaft.radialSegmentCount = 20
                shaft.materials = [ironMat]
                let segment = SCNNode(geometry: shaft)
                segment.simdPosition = (start + end) * 0.5
                segment.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(end - start))
                koredRoot.addChildNode(segment)
                let joint = SCNSphere(radius: 0.010)
                joint.materials = [ironMat]
                let jointNode = SCNNode(geometry: joint)
                jointNode.simdPosition = end
                koredRoot.addChildNode(jointNode)
            }

            // Curved forged blade: rounded shoulders, broad cutting belly,
            // extruded side walls and a bevel that catches the warm field light.
            let outline = UIBezierPath()
            outline.move(to: CGPoint(x: -0.050, y: 0.035))
            outline.addQuadCurve(to: CGPoint(x: 0.050, y: 0.035), controlPoint: CGPoint(x: 0, y: 0.044))
            outline.addQuadCurve(to: CGPoint(x: 0.100, y: -0.035), controlPoint: CGPoint(x: 0.090, y: 0.010))
            outline.addQuadCurve(to: CGPoint(x: -0.100, y: -0.035), controlPoint: CGPoint(x: 0, y: -0.068))
            outline.addQuadCurve(to: CGPoint(x: -0.050, y: 0.035), controlPoint: CGPoint(x: -0.090, y: 0.010))
            outline.close()
            let bladeGeo = SCNShape(path: outline, extrusionDepth: 0.012)
            bladeGeo.chamferRadius = 0.003
            bladeGeo.materials = [bladeMat]
            let edgeMat = SCNMaterial()
            edgeMat.lightingModel = .physicallyBased
            edgeMat.diffuse.contents = UIColor(red: 0.57, green: 0.59, blue: 0.57, alpha: 1)
            edgeMat.metalness.contents = 0.8
            edgeMat.roughness.contents = 0.35
            bladeGeo.materials = [bladeMat, bladeMat, ironMat, edgeMat, edgeMat]
            let bladeNode = SCNNode(geometry: bladeGeo)
            bladeNode.position = SCNVector3(-0.11, -0.17, 0)
            bladeNode.eulerAngles = SCNVector3(-0.15, 0.40, 0.35)
            koredRoot.addChildNode(bladeNode)
            tool = koredRoot

            scene.rootNode.addChildNode(koredRoot)
        }

        func cleanup() {
            tool?.removeAllActions()
            tool = nil
            scnView?.scene = nil
            scnView = nil
        }
    }
}

