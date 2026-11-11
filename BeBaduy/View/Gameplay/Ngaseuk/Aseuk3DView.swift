import SceneKit
import SwiftUI

/// True 3D Perspective Model of the traditional Baduy "Aseuk" (bamboo dibble stick).
///
/// Built using the exact same seasoned yellow bamboo wood material (Bambu Tali / Gombong Kanekes),
/// segment joint rings, and bindings as the traditional rice drying rack (jemuran padi / lantayan).
///
/// Distinctly 3D visual characteristics:
/// - True perspective camera projection (non-orthographic) with natural foreshortening
/// - Dynamic 3D working tilt (pitch: ~13°, yaw: ~26°) clearly revealing the cylindrical volume,
///   round top cap, 3D curved joint rings, and angled sharp tip
/// - Photographic image-based environment lighting (IBL) sampled from `HumaEnvironment`
/// - Directional warm sunset sunlight and sky ambient fill calibrated to the huma atmosphere
/// - Interactive 360° touch rotation in card previews so the physical 3D geometry can be inspected freely
struct Aseuk3DView: UIViewRepresentable {
    var interactive: Bool = false
    var autoRotate: Bool = false
    var defaultPitch: Float = 0.22
    var defaultYaw: Float = 0.45
    var defaultRoll: Float = -0.08

    func makeCoordinator() -> Coordinator {
        Coordinator(
            interactive: interactive,
            autoRotate: autoRotate,
            pitch: defaultPitch,
            yaw: defaultYaw,
            roll: defaultRoll
        )
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue
        ])
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.isOpaque = false
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = autoRotate

        context.coordinator.setupScene(in: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(
            interactive: interactive,
            autoRotate: autoRotate,
            pitch: defaultPitch,
            yaw: defaultYaw,
            roll: defaultRoll
        )
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    final class Coordinator: NSObject {
        var interactive: Bool
        var autoRotate: Bool
        var pitch: Float
        var yaw: Float
        var roll: Float

        private weak var scnView: SCNView?
        private var aseukRootNode: SCNNode?
        private var panGesture: UIPanGestureRecognizer?
        private var displayLink: CADisplayLink?
        private var lastTime: CFTimeInterval = 0
        private var isUserDragging = false

        init(interactive: Bool, autoRotate: Bool, pitch: Float, yaw: Float, roll: Float) {
            self.interactive = interactive
            self.autoRotate = autoRotate
            self.pitch = pitch
            self.yaw = yaw
            self.roll = roll
        }

        func setupScene(in view: SCNView) {
            self.scnView = view
            let scene = SCNScene()
            view.scene = scene

            // 1. Image-Based Lighting (IBL) sampled from HumaEnvironment
            if let envImage = UIImage(named: "HumaEnvironment") {
                scene.lightingEnvironment.contents = envImage
                scene.lightingEnvironment.intensity = 1.35
            }

            // 2. True Perspective Camera (Non-orthographic)
            // Perspective projection provides real 3D depth, foreshortening, and elliptical cross-sections
            let camera = SCNCamera()
            camera.usesOrthographicProjection = false
            camera.fieldOfView = 34
            camera.zNear = 0.05
            camera.zFar = 20.0
            camera.wantsHDR = false
            camera.exposureOffset = 0.15
            camera.whitePoint = 1.0

            let cameraNode = SCNNode()
            cameraNode.name = "perspectiveCamera"
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0, 2.50)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(cameraNode)

            // 3. 3-Point Studio & Atmospheric Lighting
            // Sun key light from top-right to create prominent 3D cylinder specular highlight
            let sunLight = SCNLight()
            sunLight.type = .directional
            sunLight.color = UIColor(red: 1.0, green: 0.98, blue: 0.92, alpha: 1.0)
            sunLight.intensity = 950
            let sunNode = SCNNode()
            sunNode.light = sunLight
            sunNode.position = SCNVector3(2.0, 3.0, 2.2)
            sunNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(sunNode)

            // Soft sky ambient bounce
            let fillLight = SCNLight()
            fillLight.type = .ambient
            fillLight.color = UIColor(red: 0.92, green: 0.94, blue: 0.98, alpha: 1.0)
            fillLight.intensity = 420
            let fillNode = SCNNode()
            fillNode.light = fillLight
            scene.rootNode.addChildNode(fillNode)

            // Golden rim backlight defining the rounded 3D silhouette edge
            let rimLight = SCNLight()
            rimLight.type = .directional
            rimLight.color = UIColor(red: 1.0, green: 0.92, blue: 0.78, alpha: 1.0)
            rimLight.intensity = 400
            let rimNode = SCNNode()
            rimNode.light = rimLight
            rimNode.position = SCNVector3(-2.2, 1.8, -1.2)
            rimNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(rimNode)

            // 4. Build the 3D Bamboo Aseuk Model
            let aseukNode = buildBambooAseukModel()
            aseukNode.name = "aseukRoot"
            aseukNode.eulerAngles = SCNVector3(pitch, yaw, roll)
            scene.rootNode.addChildNode(aseukNode)
            self.aseukRootNode = aseukNode

            // 5. Gestures & Animation
            if interactive {
                let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                view.addGestureRecognizer(pan)
                self.panGesture = pan
            }

            if autoRotate {
                startDisplayLink()
            }
        }

        func update(interactive: Bool, autoRotate: Bool, pitch: Float, yaw: Float, roll: Float) {
            self.interactive = interactive
            self.autoRotate = autoRotate
            self.pitch = pitch
            self.yaw = yaw
            self.roll = roll

            if !autoRotate && !isUserDragging {
                aseukRootNode?.eulerAngles = SCNVector3(pitch, yaw, roll)
            }

            if interactive && panGesture == nil, let view = scnView {
                let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                view.addGestureRecognizer(pan)
                self.panGesture = pan
            } else if !interactive, let pan = panGesture, let view = scnView {
                view.removeGestureRecognizer(pan)
                self.panGesture = nil
            }

            if autoRotate && displayLink == nil {
                startDisplayLink()
            } else if !autoRotate && displayLink != nil {
                stopDisplayLink()
            }
        }

        func cleanup() {
            stopDisplayLink()
            if let pan = panGesture, let view = scnView {
                view.removeGestureRecognizer(pan)
            }
            panGesture = nil
            scnView?.scene = nil
            scnView = nil
            aseukRootNode = nil
        }

        private func startDisplayLink() {
            stopDisplayLink()
            lastTime = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(onFrame(_:)))
            link.add(to: .main, forMode: .common)
            self.displayLink = link
        }

        private func stopDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func onFrame(_ link: CADisplayLink) {
            guard let node = aseukRootNode else { return }
            let now = link.timestamp
            let dt = lastTime > 0 ? Float(now - lastTime) : 0.016
            lastTime = now

            if autoRotate && !isUserDragging {
                node.eulerAngles.y += dt * 0.55 // Continuous smooth 3D rotation
            }
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let node = aseukRootNode, let view = scnView else { return }
            switch gesture.state {
            case .began:
                isUserDragging = true
            case .changed:
                let translation = gesture.translation(in: view)
                node.eulerAngles.y += Float(translation.x) * 0.018
                node.eulerAngles.x += Float(translation.y) * 0.010
                gesture.setTranslation(.zero, in: view)
            case .ended, .cancelled:
                isUserDragging = false
            default:
                break
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: - Procedural Geometry & Materials Matching Jemuran Padi
        // ════════════════════════════════════════════════════════════════════

        private func buildBambooAseukModel() -> SCNNode {
            let root = SCNNode()

            let detailNormal = makeDetailNormal(frequency: 22, strength: 0.12)

            // 1. Seasoned Yellow Bamboo (bright golden bamboo matching Jemuran Padi)
            let bambooMat = SCNMaterial()
            bambooMat.lightingModel = .physicallyBased
            bambooMat.diffuse.contents = UIImage(named: "HumaWoodTexture")
                ?? UIColor(red: 0.95, green: 0.84, blue: 0.52, alpha: 1)
            bambooMat.diffuse.wrapS = .repeat
            bambooMat.diffuse.wrapT = .repeat
            bambooMat.diffuse.contentsTransform = SCNMatrix4MakeScale(1.0, 3.5, 1.0)
            bambooMat.multiply.contents = UIColor(red: 1.0, green: 0.90, blue: 0.60, alpha: 1)
            bambooMat.normal.contents = detailNormal
            bambooMat.normal.intensity = 0.16
            bambooMat.roughness.contents = 0.58
            bambooMat.metalness.contents = 0.02
            smoothTextureSampling(bambooMat.diffuse)

            // 2. Bamboo Joint Material (matching Jemuran Padi line 1576)
            let jointMat = SCNMaterial()
            jointMat.lightingModel = .physicallyBased
            jointMat.diffuse.contents = UIImage(named: "HumaWoodTexture")
                ?? UIColor(red: 0.80, green: 0.58, blue: 0.30, alpha: 1)
            jointMat.multiply.contents = UIColor(red: 0.86, green: 0.66, blue: 0.36, alpha: 1)
            jointMat.normal.contents = detailNormal
            jointMat.normal.intensity = 0.28
            jointMat.roughness.contents = 0.72
            smoothTextureSampling(jointMat.diffuse)

            // 3. Bamboo Piercing Tip Material (Sharp Point - Golden Core)
            let tipMat = SCNMaterial()
            tipMat.lightingModel = .physicallyBased
            tipMat.diffuse.contents = UIImage(named: "HumaWoodTexture")
                ?? UIColor(red: 0.92, green: 0.78, blue: 0.46, alpha: 1)
            tipMat.diffuse.wrapS = .repeat
            tipMat.diffuse.wrapT = .repeat
            tipMat.diffuse.contentsTransform = SCNMatrix4MakeScale(1.0, 2.0, 1.0)
            tipMat.multiply.contents = UIColor(red: 0.94, green: 0.80, blue: 0.48, alpha: 1)
            tipMat.normal.contents = detailNormal
            tipMat.normal.intensity = 0.20
            tipMat.roughness.contents = 0.60
            tipMat.metalness.contents = 0.02
            smoothTextureSampling(tipMat.diffuse)

            // 4. Lashing / Thatch Tie Material (matching Jemuran Padi line 1586)
            let tieMat = SCNMaterial()
            tieMat.lightingModel = .physicallyBased
            tieMat.diffuse.contents = UIImage(named: "HumaThatchTexture")
                ?? UIImage(named: "HumaWoodTexture")
                ?? UIColor(red: 0.85, green: 0.70, blue: 0.40, alpha: 1)
            tieMat.multiply.contents = UIColor(red: 0.88, green: 0.74, blue: 0.42, alpha: 1)
            tieMat.normal.contents = detailNormal
            tieMat.normal.intensity = 0.25
            tieMat.roughness.contents = 0.82
            tieMat.metalness.contents = 0.0
            smoothTextureSampling(tieMat.diffuse)

            // ── Main Bamboo Pole Geometry (Batang Bambu Jemuran) ───────────────
            // Subtle taper: top radius 0.052, bottom radius 0.044
            let poleTopRadius: CGFloat = 0.052
            let poleBottomRadius: CGFloat = 0.044
            let poleHeight: CGFloat = 1.16
            let poleGeo = SCNCone(topRadius: poleTopRadius, bottomRadius: poleBottomRadius, height: poleHeight)
            poleGeo.radialSegmentCount = 36
            poleGeo.heightSegmentCount = 12
            poleGeo.materials = [bambooMat]
            let poleNode = SCNNode(geometry: poleGeo)
            poleNode.position = SCNVector3(0, 0.12, 0)
            root.addChildNode(poleNode)

            // ── Ujung Tajam Runcing (Sharp Piercing Tip) ──────────────────────
            // Tapered sharp spear-point carved from the bamboo pole
            let tipHeight: CGFloat = 0.32
            let tipGeo = SCNCone(topRadius: poleBottomRadius, bottomRadius: 0.002, height: tipHeight)
            tipGeo.radialSegmentCount = 36
            tipGeo.heightSegmentCount = 10
            tipGeo.materials = [tipMat]
            let tipNode = SCNNode(geometry: tipGeo)
            tipNode.position = SCNVector3(0, Float(0.12 - poleHeight * 0.5 - tipHeight * 0.5), 0)
            root.addChildNode(tipNode)

            // ── Bamboo Joint Segment Nodes (Ruas-Ruas Bambu Jemuran) ─────────
            // Segmented rings matching the jemuran post rings (line 1610)
            let nodeData: [(y: Float, radius: CGFloat)] = [
                (-0.34, poleBottomRadius + 0.0035),
                (-0.08, poleBottomRadius + 0.0042),
                (0.18, poleTopRadius * 0.96 + 0.004),
                (0.44, poleTopRadius * 0.98 + 0.004),
                (0.66, poleTopRadius + 0.004)
            ]
            for node in nodeData {
                let ringGeo = SCNCylinder(radius: node.radius, height: 0.016)
                ringGeo.radialSegmentCount = 36
                ringGeo.materials = [jointMat]
                let ringNode = SCNNode(geometry: ringGeo)
                ringNode.position = SCNVector3(0, node.y, 0)
                root.addChildNode(ringNode)
            }

            // ── Top Bamboo Node Cap (Puncak Ruas Bambu) ─────────────────────
            let capHeight: CGFloat = 0.02
            let capGeo = SCNCylinder(radius: poleTopRadius, height: capHeight)
            capGeo.radialSegmentCount = 36
            capGeo.materials = [jointMat]
            let capNode = SCNNode(geometry: capGeo)
            capNode.position = SCNVector3(0, Float(0.12 + poleHeight * 0.5 + capHeight * 0.5), 0)
            root.addChildNode(capNode)

            // ── Traditional Lashing Tie (Lilitan Pengikat Bambu) ────────────
            let tieGeo = SCNTorus(ringRadius: poleTopRadius + 0.002, pipeRadius: 0.004)
            tieGeo.ringSegmentCount = 36
            tieGeo.pipeSegmentCount = 16
            tieGeo.materials = [tieMat]
            let tieNode = SCNNode(geometry: tieGeo)
            tieNode.position = SCNVector3(0, 0.55, 0)
            root.addChildNode(tieNode)

            return root
        }

        private func smoothTextureSampling(_ property: SCNMaterialProperty) {
            property.minificationFilter  = .linear
            property.magnificationFilter = .linear
            property.mipFilter           = .linear
            property.maxAnisotropy       = 8
        }

        private func makeDetailNormal(frequency: Float, strength: Float) -> UIImage {
            let size = 128
            var pixels = [UInt8](repeating: 255, count: size * size * 4)
            for y in 0..<size {
                for x in 0..<size {
                    let u = Float(x) / Float(size), v = Float(y) / Float(size)
                    let slope = sin(u * frequency * 2 * .pi + sin(v * 2 * .pi) * 0.5)
                    let n = simd_normalize(SIMD3<Float>(slope * strength, 0.025 * cos(v * 2 * .pi), 1))
                    let offset = (y * size + x) * 4
                    pixels[offset] = UInt8((n.x * 0.5 + 0.5) * 255)
                    pixels[offset + 1] = UInt8((n.y * 0.5 + 0.5) * 255)
                    pixels[offset + 2] = UInt8((n.z * 0.5 + 0.5) * 255)
                }
            }
            let provider = CGDataProvider(data: Data(pixels) as CFData)!
            let image = CGImage(
                width: size,
                height: size,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )!
            return UIImage(cgImage: image)
        }
    }
}
