import SceneKit
import SwiftUI

/// Close-up 3D dibble hole and golden rice seed view.
/// Seamlessly uses the authentic Baduy huma terrain from HomeView and the previous page,
/// rendering the exact 3D dibble hole and 3D rice seeds from Home Stage 3 / Ngored.
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

        private struct SeedSpot {
            let x: Float
            let y: Float
            let z: Float
            let rotX: Float
            let rotY: Float
            let rotZ: Float
        }

        // Natural resting positions and angles of golden rice grains inside the cavity
        private let restingSpots: [SeedSpot] = [
            SeedSpot(x: -0.014, y: 0.003, z:  0.006, rotX:  0.25, rotY:  0.70, rotZ: -0.35),
            SeedSpot(x:  0.014, y: 0.002, z: -0.005, rotX: -0.20, rotY: -0.80, rotZ:  0.40),
            SeedSpot(x:  0.003, y: 0.004, z:  0.014, rotX:  0.45, rotY:  0.15, rotZ:  0.20),
            SeedSpot(x: -0.005, y: 0.003, z: -0.012, rotX: -0.35, rotY:  0.85, rotZ: -0.15)
        ]

        func setupScene(in view: SCNView, filled: Bool, isPouring: Bool) {
            self.scnView = view
            let scene = SCNScene()
            view.scene = scene

            // 1. Perspective Camera matching DibbleHole3DView and HomeView
            let camera = SCNCamera()
            camera.fieldOfView = 36
            camera.zNear = 0.02
            camera.zFar = 10.0
            camera.wantsHDR = false
            camera.exposureOffset = 0.2

            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0.45, 0.60)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(cameraNode)

            // 2. Warm Sun Key and Ambient Lighting matching HomeView & DibbleHole3DView
            let sun = SCNLight()
            sun.type = .directional
            sun.color = UIColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1)
            sun.intensity = 900
            sun.castsShadow = true
            sun.shadowRadius = 4.0
            sun.shadowColor = UIColor(red: 0.06, green: 0.04, blue: 0.02, alpha: 0.60)
            let sunNode = SCNNode()
            sunNode.light = sun
            sunNode.position = SCNVector3(1.4, 2.8, 1.8)
            sunNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(sunNode)

            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = UIColor(red: 0.88, green: 0.85, blue: 0.82, alpha: 1)
            ambient.intensity = 420
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            let rimLight = SCNLight()
            rimLight.type = .directional
            rimLight.color = UIColor(red: 1.0, green: 0.92, blue: 0.78, alpha: 1)
            rimLight.intensity = 240
            let rimLightNode = SCNNode()
            rimLightNode.light = rimLight
            rimLightNode.position = SCNVector3(-1.8, 1.6, -1.2)
            rimLightNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(rimLightNode)

            // 3. Root Container
            let root = SCNNode()
            root.name = "holeRoot"

            // 4. Dibble Hole: Exact shape, geometry, and material from HomeView Ngored (makePlantingHoleNode)
            let holeNode = HomeSceneRenderer.makePlantingHoleNode(homePreview: true)
            holeNode.name = "homeDibbleHole"
            holeNode.scale = SCNVector3(3.6, 2.2, 3.6)
            holeNode.position = SCNVector3(0, 0, 0)
            root.addChildNode(holeNode)

            // 5. 3D Rice Seeds: Exact golden rice grains from HomeView Ngored (makePlantingSeedNode)
            let spotCount = min(NgaseukViewModel.seedsPerHole, restingSpots.count)
            for i in 0..<spotCount {
                let spot = restingSpots[i]
                let seedNode = HomeSceneRenderer.makePlantingSeedNode()
                seedNode.scale = SCNVector3(1.76, 4.0, 1.44)
                seedNode.eulerAngles = SCNVector3(spot.rotX, spot.rotY, spot.rotZ)
                seedNode.name = "homeSeed_\(i)"
                seedNode.position = SCNVector3(spot.x, spot.y, spot.z)
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
                    node.position = SCNVector3(spot.x, spot.y, spot.z)
                    node.eulerAngles = SCNVector3(spot.rotX, spot.rotY, spot.rotZ)
                    node.opacity = 1.0
                    node.isHidden = !filled
                }
            }
            wasPouring = isPouring
        }

        private func animatePouring() {
            for (i, node) in seedNodes.enumerated() {
                node.removeAction(forKey: "pourDrop")
                let spot = restingSpots[i]
                let startY: Float = 0.18 + Float(i) * 0.025
                let startX: Float = (Float(i % 2) - 0.5) * 0.035
                let startZ: Float = (Float(i / 2) - 0.5) * 0.035
                node.position = SCNVector3(startX, startY, startZ)
                node.eulerAngles = SCNVector3(spot.rotX * 2, spot.rotY, spot.rotZ * 2)
                node.opacity = 0
                node.isHidden = false

                let delay = Double(i) * 0.10
                let wait = SCNAction.wait(duration: delay)
                let fadeIn = SCNAction.fadeIn(duration: 0.05)
                let fall = SCNAction.customAction(duration: 0.38) { _, elapsed in
                    let t = Float(elapsed / 0.38)
                    let easeIn = t * t
                    node.position = SCNVector3(
                        startX + (spot.x - startX) * t,
                        startY + (spot.y - startY) * easeIn,
                        startZ + (spot.z - startZ) * t
                    )
                }
                let bounceUp = SCNAction.move(by: SCNVector3(0, 0.005, 0), duration: 0.07)
                let bounceDown = SCNAction.move(by: SCNVector3(0, -0.005, 0), duration: 0.08)
                bounceUp.timingMode = .easeOut
                bounceDown.timingMode = .easeIn
                let settle = SCNAction.run { _ in
                    node.position = SCNVector3(spot.x, spot.y, spot.z)
                    node.eulerAngles = SCNVector3(spot.rotX, spot.rotY, spot.rotZ)
                }
                node.runAction(.sequence([wait, fadeIn, fall, bounceUp, bounceDown, settle]), forKey: "pourDrop")
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
