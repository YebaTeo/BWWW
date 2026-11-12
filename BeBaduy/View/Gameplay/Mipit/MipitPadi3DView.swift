import SceneKit
import SwiftUI

/// 3D SceneKit View for the Mipit harvesting activity.
///
/// Cultural and Agricultural Precision:
/// - Interactable state (!isHarvested): Renders the 3D golden ripe rice plant from Home Stage 4 (Mipit),
///   featuring fertile root soil, arching golden blades, and drooping panicles laden with 3D gabah grains,
///   animated with real-time natural Kanekes breeze.
/// - Harvested state (isHarvested): Smoothly transitions to the authentic Baduy harvested rice sheaf
///   (ikatan padi / geugeusan pare) from the next stage (Ngalantai / Stage 5) tied with split-bamboo tali awian,
///   WITHOUT the drying tarp ("tanpa terpalnya"), resting gracefully on the soil.
struct MipitPadi3DView: View {
    let isHarvested: Bool
    var activeCut: Bool = false

    var body: some View {
        MipitPadiSceneView(isHarvested: isHarvested, activeCut: activeCut)
            .accessibilityHidden(true)
    }
}

private struct MipitPadiSceneView: UIViewRepresentable {
    let isHarvested: Bool
    let activeCut: Bool

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

        context.coordinator.setupScene(in: view, isHarvested: isHarvested)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(isHarvested: isHarvested, activeCut: activeCut)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    @MainActor
    final class Coordinator: NSObject {
        private weak var scnView: SCNView?
        private var standingPlantNode: SCNNode?
        private var harvestedSheafNode: SCNNode?
        private var cameraNode: SCNNode?
        private var currentHarvested: Bool?

        func setupScene(in view: SCNView, isHarvested: Bool) {
            self.scnView = view
            self.currentHarvested = isHarvested

            let scene = SCNScene()

            // 1. Photographic Environment Lighting (IBL)
            if let envImage = UIImage(named: "HumaEnvironment") {
                scene.lightingEnvironment.contents = envImage
                scene.lightingEnvironment.intensity = 1.18
            }

            // 2. Camera: Framed with three-quarters perspective
            let camera = SCNCamera()
            camera.zNear = 0.05
            camera.zFar = 25.0
            camera.fieldOfView = 36.0
            camera.wantsHDR = true
            camera.bloomThreshold = 1.25
            camera.bloomIntensity = 0.10

            let camNode = SCNNode()
            camNode.name = "mipitCamera"
            camNode.camera = camera
            camNode.position = SCNVector3(0, 0.26, 0.86)
            camNode.look(at: SCNVector3(0, 0.18, 0))
            scene.rootNode.addChildNode(camNode)
            self.cameraNode = camNode

            // 3. Directional Key Light (Warm golden sunset hour)
            let sunLight = SCNLight()
            sunLight.type = .directional
            sunLight.color = UIColor(red: 1.0, green: 0.90, blue: 0.72, alpha: 1.0)
            sunLight.intensity = 880
            sunLight.castsShadow = false
            let sunNode = SCNNode()
            sunNode.light = sunLight
            sunNode.eulerAngles = SCNVector3(-0.52, 0.42, 0)
            scene.rootNode.addChildNode(sunNode)

            // 4. Ambient Sky Fill Light
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.color = UIColor(red: 0.72, green: 0.80, blue: 0.90, alpha: 1.0)
            ambientLight.intensity = 260
            let ambientNode = SCNNode()
            ambientNode.light = ambientLight
            scene.rootNode.addChildNode(ambientNode)

            // Home-style contact shadow beneath the small soil clod.
            let shadowGeo = SCNPlane(width: 0.28, height: 0.24)
            let shadowMat = SCNMaterial()
            shadowMat.lightingModel = .constant
            shadowMat.diffuse.contents = UIColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 0.65)
            shadowMat.isDoubleSided = true
            shadowMat.transparencyMode = .aOne
            shadowMat.writesToDepthBuffer = false
            shadowMat.shaderModifiers = [.fragment: """
            #pragma transparent
            #pragma body
            float2 uv = (_surface.diffuseTexcoord - float2(0.5)) * 2.0;
            float r = length(uv);
            _output.color.a *= (1.0 - smoothstep(0.20, 1.0, r)) * 0.75;
            """]
            shadowGeo.materials = [shadowMat]
            let shadowNode = SCNNode(geometry: shadowGeo)
            shadowNode.name = "groundShadow"
            shadowNode.eulerAngles.x = -.pi / 2
            shadowNode.position = SCNVector3(0, 0.001, 0)
            scene.rootNode.addChildNode(shadowNode)

            // Standing Ripe Rice Plant (From Home Stage 4), composited directly
            // over the shared Home soil background with its familiar root clod.
            let plantNode = HomeSceneRenderer.makeHomeRipeRicePlant()
            plantNode.name = "standingRicePlant"
            plantNode.position = SCNVector3(0, 0, 0)
            plantNode.isHidden = isHarvested
            plantNode.opacity = isHarvested ? 0 : 1
            scene.rootNode.addChildNode(plantNode)
            self.standingPlantNode = plantNode

            // Harvested Rice Sheaf (From Next Stage WITHOUT Tarp)
            let sheafNode = HomeSceneRenderer.makeNgalantaiHarvestedSheaf()
            sheafNode.name = "harvestedRiceSheaf"
            sheafNode.position = SCNVector3(0, 0, 0)
            sheafNode.eulerAngles = SCNVector3(0.08, 0.24, -0.04)
            sheafNode.isHidden = !isHarvested
            sheafNode.opacity = isHarvested ? 1 : 0
            scene.rootNode.addChildNode(sheafNode)
            self.harvestedSheafNode = sheafNode

            view.scene = scene
        }

        func update(isHarvested: Bool, activeCut: Bool) {
            guard let previous = currentHarvested else {
                currentHarvested = isHarvested
                return
            }

            // Animate transition between unharvested and harvested
            if !previous && isHarvested {
                currentHarvested = true

                // A) Standing plant tilts and fades down (falling smoothly as ani-ani cuts)
                let cutAnim = SCNAction.sequence([
                    SCNAction.group([
                        SCNAction.rotateBy(x: 0.14, y: 0.06, z: -0.16, duration: 0.18),
                        SCNAction.moveBy(x: 0.015, y: -0.035, z: 0.015, duration: 0.18)
                    ]),
                    SCNAction.group([
                        SCNAction.fadeOut(duration: 0.20),
                        SCNAction.scale(to: 0.72, duration: 0.20),
                        SCNAction.moveBy(x: 0.02, y: -0.05, z: 0.02, duration: 0.20)
                    ]),
                    SCNAction.run { [weak self] _ in
                        self?.standingPlantNode?.isHidden = true
                    }
                ])
                standingPlantNode?.runAction(cutAnim)

                // B) Harvested tied sheaf appears and settles on the soil
                harvestedSheafNode?.isHidden = false
                harvestedSheafNode?.opacity = 0
                harvestedSheafNode?.scale = SCNVector3(0.75, 0.75, 0.75)
                harvestedSheafNode?.position.y = 0.06
                let appearAnim = SCNAction.sequence([
                    SCNAction.wait(duration: 0.10),
                    SCNAction.group([
                        SCNAction.fadeIn(duration: 0.34),
                        SCNAction.scale(to: 1.0, duration: 0.34),
                        SCNAction.move(to: SCNVector3(0, 0, 0), duration: 0.34)
                    ])
                ])
                appearAnim.timingMode = .easeOut
                harvestedSheafNode?.runAction(appearAnim)

            } else if previous && !isHarvested {
                // Reset (Replay / restart)
                currentHarvested = false
                standingPlantNode?.removeAllActions()
                standingPlantNode?.isHidden = false
                standingPlantNode?.opacity = 1.0
                standingPlantNode?.scale = SCNVector3(1, 1, 1)
                standingPlantNode?.position = SCNVector3(0, 0, 0)
                standingPlantNode?.eulerAngles = SCNVector3(0, 0, 0)

                harvestedSheafNode?.removeAllActions()
                harvestedSheafNode?.isHidden = true
                harvestedSheafNode?.opacity = 0.0
            }

            // Interactive cut tremor feedback
            if activeCut && !isHarvested {
                let twitch1 = SCNAction.rotateBy(x: 0.035, y: 0.02, z: -0.05, duration: 0.05)
                let twitch2 = SCNAction.rotateBy(x: -0.035, y: -0.02, z: 0.05, duration: 0.05)
                standingPlantNode?.runAction(SCNAction.sequence([twitch1, twitch2]))
            }
        }

        func cleanup() {
            standingPlantNode?.removeAllActions()
            harvestedSheafNode?.removeAllActions()
            scnView?.scene = nil
            scnView = nil
        }
    }
}
