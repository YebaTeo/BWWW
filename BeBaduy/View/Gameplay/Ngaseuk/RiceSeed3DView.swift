import SceneKit
import SwiftUI

/// 3D Rice Seed Vessel (Wadah Benih Padi Huma) rendered in SceneKit.
///
/// Replaces the 2D text label with an authentic Baduy woven bamboo seed bowl (cepon/nyiru)
/// filled with golden unhulled rice seeds (gabah padi huma), complete with 3D levitating
/// golden seed grains inviting the user to touch and drag into the dibble holes.
struct RiceSeed3DView: View {
    var isDragging: Bool = false
    var isInteractable: Bool = false
    var isPouring = false
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if isInteractable && !isDragging && !isPouring {
                Ellipse()
                    .stroke(AppTheme.heading.opacity(0.38), lineWidth: 1.2)
                    .frame(width: 112, height: 42)
                    .shadow(color: AppTheme.heading.opacity(0.15), radius: 4)
                    .offset(y: 24)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            RiceSeedSceneView()
                .frame(width: 130, height: 110)
                .shadow(color: Color(red: 0.15, green: 0.10, blue: 0.05).opacity(0.45), radius: 8, x: 0, y: 6)
        }
        .scaleEffect(isDragging || isPouring ? 1.08 : (isInteractable && isPulsing ? 1.045 : 1))
        .rotation3DEffect(.degrees(isPouring ? 34 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
        .rotationEffect(.degrees(isPouring ? -65 : 0))
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isDragging)
        .animation(.easeInOut(duration: 0.42), value: isPouring)
        .animation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear { if isInteractable { isPulsing = true } }
        .accessibilityLabel("Wadah benih padi huma 3 dimensi")
        .accessibilityHint("Seret baskom benih ini ke lubang tanah yang telah dibuat")
    }
}

private struct RiceSeedSceneView: UIViewRepresentable {
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

        context.coordinator.setupScene(in: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    final class Coordinator: NSObject {
        private weak var scnView: SCNView?
        private var floatingSeedNode: SCNNode?
        private var displayLink: CADisplayLink?
        private var startTime: CFTimeInterval = 0

        func setupScene(in view: SCNView) {
            self.scnView = view
            let scene = SCNScene()
            view.scene = scene

            // 1. Perspective Camera looking slightly downward onto the seed bowl
            let camera = SCNCamera()
            camera.fieldOfView = 35
            camera.zNear = 0.05
            camera.zFar = 10.0
            camera.exposureOffset = 0.2
            camera.wantsHDR = false

            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0.40, 0.65)
            cameraNode.look(at: SCNVector3(0, 0.05, 0))
            scene.rootNode.addChildNode(cameraNode)

            // 2. Warm Sunlight & Golden Rim
            let sun = SCNLight()
            sun.type = .directional
            sun.color = UIColor(red: 1.0, green: 0.98, blue: 0.90, alpha: 1)
            sun.intensity = 950
            let sunNode = SCNNode()
            sunNode.light = sun
            sunNode.position = SCNVector3(1.5, 2.2, 1.8)
            sunNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(sunNode)

            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = UIColor(red: 0.90, green: 0.88, blue: 0.85, alpha: 1)
            ambient.intensity = 420
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            // 3. Woven Bamboo Seed Bowl (Cepon / Wadah Anyaman Bambu Baduy)
            let bowlRoot = SCNNode()
            bowlRoot.name = "seedBowl"

            let bowlMat = SCNMaterial()
            bowlMat.lightingModel = .physicallyBased
            bowlMat.diffuse.contents = UIImage(named: "HumaWoodTexture")
                ?? UIColor(red: 0.85, green: 0.70, blue: 0.42, alpha: 1)
            bowlMat.multiply.contents = UIColor(red: 0.88, green: 0.74, blue: 0.44, alpha: 1)
            bowlMat.roughness.contents = 0.82

            let bowlGeo = SCNCylinder(radius: 0.095, height: 0.038)
            bowlGeo.radialSegmentCount = 36
            bowlGeo.materials = [bowlMat]
            let bowlNode = SCNNode(geometry: bowlGeo)
            bowlNode.position.y = 0.019
            bowlRoot.addChildNode(bowlNode)

            // Rim collar around bowl
            let rimGeo = SCNTorus(ringRadius: 0.096, pipeRadius: 0.007)
            rimGeo.ringSegmentCount = 36
            rimGeo.materials = [bowlMat]
            let rimNode = SCNNode(geometry: rimGeo)
            rimNode.position.y = 0.038
            bowlRoot.addChildNode(rimNode)

            // 4. Mound of Golden Rice Grains (Tumpukan Gabah) inside bowl
            let seedMat = SCNMaterial()
            seedMat.lightingModel = .physicallyBased
            seedMat.diffuse.contents = UIColor(red: 0.96, green: 0.88, blue: 0.52, alpha: 1)
            seedMat.roughness.contents = 0.55
            seedMat.metalness.contents = 0.02

            let moundGeo = SCNSphere(radius: 0.088)
            moundGeo.materials = [seedMat]
            let moundNode = SCNNode(geometry: moundGeo)
            moundNode.scale = SCNVector3(1.0, 0.38, 1.0)
            moundNode.position.y = 0.030
            bowlRoot.addChildNode(moundNode)

            // Individual detailed grain meshes visible on the top of the mound
            for i in 0..<18 {
                let angle = Float(i) * 2.39996
                let dist = 0.025 + Float(i % 5) * 0.012
                let grainGeo = SCNSphere(radius: 0.010)
                grainGeo.materials = [seedMat]
                let grainNode = SCNNode(geometry: grainGeo)
                grainNode.scale = SCNVector3(0.55, 0.42, 1.45)
                grainNode.eulerAngles = SCNVector3(0.18 * sin(angle), angle, 0.15 * cos(angle))
                grainNode.position = SCNVector3(cos(angle) * dist, 0.046 + Float(i % 3) * 0.003, sin(angle) * dist)
                bowlRoot.addChildNode(grainNode)
            }
            scene.rootNode.addChildNode(bowlRoot)

            // 5. Hero Levitating 3D Rice Seeds Group (Floating above vessel inviting interaction)
            let heroGroup = SCNNode()
            heroGroup.name = "floatingHeroSeeds"
            heroGroup.position = SCNVector3(0, 0.115, 0)

            for j in 0..<3 {
                let yaw = Float(j) * (2.0 * .pi / 3.0)
                let grainGeo = SCNSphere(radius: 0.016)
                grainGeo.materials = [seedMat]
                let heroGrain = SCNNode(geometry: grainGeo)
                heroGrain.scale = SCNVector3(0.52, 0.42, 1.45)
                heroGrain.eulerAngles = SCNVector3(0.35, yaw, 0.20)
                heroGrain.position = SCNVector3(cos(yaw) * 0.022, Float(j) * 0.006, sin(yaw) * 0.022)
                heroGroup.addChildNode(heroGrain)
            }
            scene.rootNode.addChildNode(heroGroup)
            self.floatingSeedNode = heroGroup

            startAnimation()
        }

        private func startAnimation() {
            startTime = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(onFrame(_:)))
            link.add(to: .main, forMode: .common)
            self.displayLink = link
        }

        @objc private func onFrame(_ link: CADisplayLink) {
            guard let node = floatingSeedNode else { return }
            let t = Float(CACurrentMediaTime() - startTime)
            node.position.y = 0.115 + sin(t * 2.8) * 0.012
            node.eulerAngles.y = t * 0.75
        }

        func cleanup() {
            displayLink?.invalidate()
            displayLink = nil
            scnView?.scene = nil
            scnView = nil
            floatingSeedNode = nil
        }
    }
}

