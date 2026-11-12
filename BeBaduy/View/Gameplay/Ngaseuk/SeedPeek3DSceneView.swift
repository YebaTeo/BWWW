import SceneKit
import SwiftUI

/// Seed close-up using the AR terrain texture and the home preview's planting rim.
struct SeedPeek3DSceneView: UIViewRepresentable {
    let filled: Bool
    let isPouring: Bool

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
        view.rendersContinuously = isPouring

        context.coordinator.setupScene(in: view, filled: filled, isPouring: isPouring)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        view.rendersContinuously = isPouring
        context.coordinator.update(filled: filled, isPouring: isPouring)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    @MainActor
    final class Coordinator: NSObject {
        private weak var scnView: SCNView?
        private var seedNodes: [SCNNode] = []
        private var holeGroup: SCNNode?
        private var wasPouring = false

        // Resting positions of seeds in the cavity (HomeView seed placement)
        private let restingSpots: [(x: Float, z: Float)] = [
            (-0.005, 0.002),
            (0.005, -0.002),
            (0.001, 0.006),
            (0.001, -0.006)
        ]

        func setupScene(in view: SCNView, filled: Bool, isPouring: Bool) {
            self.scnView = view
            let scene = SCNScene()
            view.scene = scene

            // 1. Perspective Camera looking down into the hole at ~46° angle
            let camera = SCNCamera()
            camera.fieldOfView = 36
            camera.zNear = 0.001
            camera.zFar = 25.0
            camera.wantsHDR = false
            camera.exposureOffset = 0.2

            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0.42, 0.35)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(cameraNode)

            // 2. Sunlight, Ambient, and Warm Bounce Lights matching HomeView
            let sun = SCNLight()
            sun.type = .directional
            sun.color = UIColor(red: 1.0, green: 0.98, blue: 0.90, alpha: 1)
            sun.intensity = 950
            sun.castsShadow = true
            sun.shadowRadius = 3.0
            sun.shadowColor = UIColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 0.55)
            let sunNode = SCNNode()
            sunNode.light = sun
            sunNode.position = SCNVector3(1.8, 3.2, 2.0)
            sunNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(sunNode)

            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = UIColor(red: 0.86, green: 0.88, blue: 0.92, alpha: 1)
            ambient.intensity = 400
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            let rimLight = SCNLight()
            rimLight.type = .directional
            rimLight.color = UIColor(red: 1.0, green: 0.94, blue: 0.80, alpha: 1)
            rimLight.intensity = 280
            let rimLightNode = SCNNode()
            rimLightNode.light = rimLight
            rimLightNode.position = SCNVector3(-2.2, 1.8, -1.0)
            rimLightNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(rimLightNode)

            // Use the same processed soil texture as the AR field, not the raw photo.
            let environment = UIImage(named: "HumaEnvironment")
            let soilImage = environment?.cgImage
                .flatMap { NgahumaMaterials.buildSoilTexture(from: $0) }
                .map { UIImage(cgImage: $0) }
                ?? UIImage(named: "HumaTerrainTexture") ?? UIImage()

            let (terrainGeometry, terrainMaterial) = NgahumaMaterials.makeTerrainMesh(
                span: 1.4,
                steps: 24,
                soilY: 0.0,
                texture: soilImage
            )
            // Close-up UV density keeps pebbles proportional to the small planting hole.
            terrainMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(8, 8, 1)
            let terrainNode = SCNNode(geometry: terrainGeometry)
            terrainNode.name = "arHumaTerrain"
            terrainNode.castsShadow = false
            scene.rootNode.addChildNode(terrainNode)

            // 4. Dibble Hole: Exact shape, geometry, and material from HomeView Ngored (HomeSceneRenderer line 1107-1115)
            let root = SCNNode()
            root.name = "holeRoot"

            let holeNode = HomeSceneRenderer.makePlantingHoleNode()
            holeNode.name = "homeDibbleHole"
            holeNode.position.y = 0.001
            root.addChildNode(holeNode)

            // 5. Seeds: Exact seed spheres and material from HomeView Ngored (HomeSceneRenderer lines 1121-1129)
            for (i, spot) in restingSpots.enumerated() {
                let seedNode = HomeSceneRenderer.makePlantingSeedNode()
                seedNode.scale = SCNVector3(0.44, 0.44, 0.44)
                seedNode.name = "homeSeed_\(i)"
                seedNode.position = SCNVector3(spot.x, 0.0035, spot.z)
                seedNode.isHidden = !filled
                root.addChildNode(seedNode)
                seedNodes.append(seedNode)
            }

            scene.rootNode.addChildNode(root)
            self.holeGroup = root
            self.wasPouring = isPouring

            if isPouring {
                animatePouring()
            }
        }

        func update(filled: Bool, isPouring: Bool) {
            if isPouring && !wasPouring {
                animatePouring()
            } else if !isPouring {
                for (i, node) in seedNodes.enumerated() {
                    node.removeAction(forKey: "pourDrop")
                    let spot = restingSpots[i]
                    node.position = SCNVector3(spot.x, 0.0035, spot.z)
                    node.opacity = 1.0
                    node.isHidden = !filled
                }
            }
            self.wasPouring = isPouring
        }

        private func animatePouring() {
            for (i, node) in seedNodes.enumerated() {
                node.removeAction(forKey: "pourDrop")
                let spot = restingSpots[i]
                let startY: Float = 0.08 + Float(i) * 0.012
                let startX: Float = (Float(i % 2) - 0.5) * 0.012
                let startZ: Float = (Float(i / 2) - 0.5) * 0.012
                node.position = SCNVector3(startX, startY, startZ)
                node.opacity = 0
                node.isHidden = false

                let delay = Double(i) * 0.10
                let waitAction = SCNAction.wait(duration: delay)
                let fadeIn = SCNAction.fadeIn(duration: 0.05)

                let fallAction = SCNAction.customAction(duration: 0.35) { _, elapsed in
                    let t = Float(elapsed / 0.35)
                    let easeIn = t * t // Gravity
                    let currentY = startY + (0.0035 - startY) * easeIn
                    let currentX = startX + (spot.x - startX) * t
                    let currentZ = startZ + (spot.z - startZ) * t
                    node.position = SCNVector3(currentX, currentY, currentZ)
                }

                let bounceUp = SCNAction.move(by: SCNVector3(0, 0.002, 0), duration: 0.07)
                let bounceDown = SCNAction.move(by: SCNVector3(0, -0.002, 0), duration: 0.08)
                bounceUp.timingMode = .easeOut
                bounceDown.timingMode = .easeIn

                let settle = SCNAction.run { _ in
                    node.position = SCNVector3(spot.x, 0.0035, spot.z)
                }

                let sequence = SCNAction.sequence([waitAction, fadeIn, fallAction, bounceUp, bounceDown, settle])
                node.runAction(sequence, forKey: "pourDrop")
            }
        }

        func cleanup() {
            for node in seedNodes {
                node.removeAllActions()
            }
            seedNodes.removeAll()
            scnView?.scene = nil
            scnView = nil
            holeGroup = nil
        }
    }
}
