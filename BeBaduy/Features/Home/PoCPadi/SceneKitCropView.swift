// SceneKitCropView.swift
// BeBaduy – Kanekes traditional rice-farming ceremony visualiser
//
// 5-stage cinematic scene driven by a single progress: CGFloat (0 → 1)
//   Stage 1  NUKUH   p 0.000 – 0.333  Dense wild forest
//   Transition 1→2   p 0.100 – 0.333  Trees fall & burn
//   Stage 2  NGASEUK p 0.333 – 0.666  Cleared, plain soil
//   Stage 3  NGORED  p 0.666 – 0.750  Dibble holes and seeds
//   Stage 4  DIBUAT  p 0.666 – 0.750  Golden panicles / harvest
//   Stage 5  LEUIT   p 0.750 – 1.000  Camera pans right to the rice barn

import SceneKit
import SwiftUI

// MARK: - Public SwiftUI wrapper

struct SceneKitCropView: UIViewRepresentable {
    let progress: CGFloat
    let isActive: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue
        ])
        context.coordinator.install(in: view)
        context.coordinator.setActive(isActive && scenePhase == .active, in: view, reduceMotion: reduceMotion)
        context.coordinator.update(progress: progress)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.setActive(isActive && scenePhase == .active, in: view, reduceMotion: reduceMotion)
        context.coordinator.update(progress: progress)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.stopUpdates()
        view.isPlaying = false
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {

        // ── Blade helper (wind animation) ────────────────────────────────────
        private final class Blade {
            let pivot: SCNNode
            let root: SCNNode
            let phase: Float
            let response: Float
            let restYaw: Float

            init(pivot: SCNNode, root: SCNNode,
                 phase: Float, response: Float, restYaw: Float) {
                self.pivot    = pivot
                self.root     = root
                self.phase    = phase
                self.response = response
                self.restYaw  = restYaw
            }
        }

        // ── Scene graph roots ────────────────────────────────────────────────
        private let scene        = SCNScene()
        /// Stage-1: wild forest trees
        private let forestRoot   = SCNNode()
        private let shadowRoot   = SCNNode()
        /// Stage-1: scattered wild-grass blades
        private let wildRoot     = SCNNode()
        /// Stage-3: dibble holes + seed spheres
        private let plantingRoot = SCNNode()
        /// Stage-3: rice leaves
        private let leavesRoot   = SCNNode()
        /// Stage-4: golden panicles
        private let paniclesRoot = SCNNode()
        /// Fire embers + glow
        private let fireRoot     = SCNNode()
        /// Ash clods on the charred ground
        private let ashRoot      = SCNNode()
        /// Stage-5: raised rice barn revealed after the harvest
        private let leuitRoot    = SCNNode()

        /// The SceneKit overlay pans independently over the static sunset
        /// image when the final stage reveals the lumbung.
        private let cameraNode   = SCNNode()

        // ── Per-tree state ───────────────────────────────────────────────────
        /// (trunk node, canopy node, natural fall-start offset in [0,1])
        private var treeNodes: [(trunk: SCNNode, canopy: SCNNode, fallAngle: Float, origin: SCNVector3)] = []
        private var impactedTrees = Set<Int>()
        private let stumpRoot = SCNNode()
        private var flameSystems: [SCNParticleSystem] = []
        private let fireLight = SCNLight()
        private let animationEpoch = CACurrentMediaTime()

        // ── Ember / seed nodes ───────────────────────────────────────────────
        private var emberNodes: [(node: SCNNode, baseX: Float, baseZ: Float, phase: Float)] = []
        private var seedNodes:  [SCNNode] = []

        // ── Blade / material arrays ──────────────────────────────────────────
        private var blades:        [Blade]       = []
        private var leafMaterials: [SCNMaterial] = []

        // ── Ground material (tinted dynamically) ─────────────────────────────
        private var groundMaterial: SCNMaterial?
        private var targetProgress: CGFloat = 0
        private var displayedProgress: CGFloat = 0
        private var displayedCameraPan: Float = 0
        private var lastFrameTime: CFTimeInterval = 0
        private var displayLink: CADisplayLink?

        // CADisplayLink retains its target. A weak proxy lets SwiftUI release
        // the coordinator cleanly when this screen leaves the hierarchy.
        @MainActor private final class FrameTarget: NSObject {
            weak var owner: Coordinator?
            @objc func tick(_ link: CADisplayLink) { owner?.advance(link) }
        }
        private let frameTarget = FrameTarget()

        func setActive(_ active: Bool, in view: SCNView, reduceMotion: Bool) {
            displayLink?.isPaused = !active
            view.isPlaying = active
            isWindEnabled = active && !reduceMotion
        }

        func stopUpdates() {
            displayLink?.invalidate()
            displayLink = nil
        }

        private func advance(_ link: CADisplayLink) {
            let dt = lastFrameTime == 0 ? 0 : min(link.timestamp - lastFrameTime, 1.0 / 15)
            lastFrameTime = link.timestamp
            // Frame-rate independent settling; retarget from the current state
            // when dragging reverses, instead of queuing more animations.
            let blend = isWindEnabled ? 1 - exp(-dt / 0.16) : 1
            displayedProgress += (targetProgress - displayedProgress) * blend
            if abs(targetProgress - displayedProgress) < 0.0001 {
                displayedProgress = targetProgress
            }
            let panTarget = smoothstep(0.73, 0.95, Float(displayedProgress))
            let panBlend = Float(1 - exp(-dt / 0.42))
            displayedCameraPan += (panTarget - displayedCameraPan) * panBlend
            if abs(panTarget - displayedCameraPan) < 0.0001 {
                displayedCameraPan = panTarget
            }
            SCNTransaction.begin()
            SCNTransaction.disableActions = true
            applyProgress(displayedProgress)
            SCNTransaction.commit()
        }

        // ── Wind toggle ──────────────────────────────────────────────────────
        private static let windActionKey = "vegetation.breeze"
        var isWindEnabled = true {
            didSet {
                guard oldValue != isWindEnabled else { return }
                for blade in blades {
                    if isWindEnabled {
                        startBreeze(on: blade)
                    } else {
                        blade.pivot.removeAction(forKey: Self.windActionKey)
                        blade.pivot.eulerAngles = SCNVector3(0, blade.restYaw, 0)
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: install(in:)
        // ════════════════════════════════════════════════════════════════════

        func install(in view: SCNView) {
            configureRenderer(view)
            configureCamera()
            configureLighting()
            buildGround()
            buildForest()        // Stage 1
            buildWildGrass()     // Stage 1 undergrowth
            buildFire()          // Transition 1→2
            buildAsh()           // Post-burn clods
            buildPlantingStage() // Stage 2
            buildRicePlant()     // Stage 3 + 4
            buildLeuit()         // Stage 5
            frameTarget.owner = self
            let link = CADisplayLink(target: frameTarget, selector: #selector(FrameTarget.tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Renderer setup
        // ════════════════════════════════════════════════════════════════════

        private func configureRenderer(_ view: SCNView) {
            scene.background.contents = UIColor.clear
            scene.physicsWorld.gravity = SCNVector3Zero
            scene.physicsWorld.timeStep = 1.0 / 60.0
            scene.physicsWorld.speed   = 1

            view.scene                      = scene
            view.backgroundColor            = .clear
            view.isOpaque                   = false
            view.autoenablesDefaultLighting = false
            view.antialiasingMode           = .multisampling2X
            view.isJitteringEnabled         = false
            view.preferredFramesPerSecond   = 60
            view.rendersContinuously        = true   // needed for ember oscillation
            view.isPlaying                  = true
            view.allowsCameraControl        = false
        }

        private func configureCamera() {
            let camera               = SCNCamera()
            camera.fieldOfView       = 38
            camera.zNear             = 0.01
            camera.zFar              = 20
            camera.wantsHDR          = true
            camera.wantsExposureAdaptation = false
            camera.exposureOffset    = -1.05
            camera.whitePoint        = 1.8
            camera.screenSpaceAmbientOcclusionIntensity = 0.42
            camera.screenSpaceAmbientOcclusionRadius    = 0.035
            camera.screenSpaceAmbientOcclusionBias      = 0.002
            camera.bloomThreshold    = 1.2
            camera.bloomIntensity    = 0.12
            camera.bloomBlurRadius   = 3

            cameraNode.name      = "cropCamera"
            cameraNode.camera    = camera
            cameraNode.position  = SCNVector3(0, 0.52, 1.75)
            cameraNode.look(at: SCNVector3(0, 0.10, 0))
            scene.rootNode.addChildNode(cameraNode)
        }

        private func configureLighting() {
            // Key – warm Kanekes sunset directional
            let sun           = SCNLight()
            sun.type          = .directional
            sun.color         = UIColor(red: 1.0, green: 0.88, blue: 0.70, alpha: 1)
            sun.intensity     = 155
            sun.castsShadow   = true
            sun.shadowMode    = .deferred
            sun.shadowRadius  = 10
            sun.shadowSampleCount = 8
            sun.shadowBias = 0.003
            sun.shadowMapSize = CGSize(width: 1024, height: 1024)
            sun.shadowColor   = UIColor(white: 0.05, alpha: 0.30)
            let sunNode       = SCNNode()
            sunNode.light     = sun
            sunNode.position  = SCNVector3(2.6, 3.2, -2.4)
            sunNode.look(at: SCNVector3(0, 0.1, 0))
            scene.rootNode.addChildNode(sunNode)

            // Fill – cool sky ambient
            let ambient       = SCNLight()
            ambient.type      = .ambient
            ambient.color     = UIColor(red: 0.88, green: 0.82, blue: 0.70, alpha: 1)
            ambient.intensity = 230
            let ambientNode   = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            // Rim – back-light
            let rim           = SCNLight()
            rim.type          = .omni
            rim.color         = UIColor(red: 1.0, green: 0.87, blue: 0.68, alpha: 1)
            rim.intensity     = 18
            rim.attenuationStartDistance = 0.3
            rim.attenuationEndDistance   = 2.2
            let rimNode       = SCNNode()
            rimNode.light     = rim
            rimNode.position  = SCNVector3(0.65, 0.72, -0.65)
            scene.rootNode.addChildNode(rimNode)

            // Soft, warm fill reaches every plant category: trees, weeds,
            // and rice. Keep it broad and low so it blends with the sunset.
            let fill = SCNLight()
            fill.type = .omni
            fill.color = UIColor(red: 1.0, green: 0.79, blue: 0.57, alpha: 1)
            fill.intensity = 58
            fill.attenuationStartDistance = 0.5
            fill.attenuationEndDistance = 3.5
            let fillNode = SCNNode()
            fillNode.light = fill
            fillNode.position = SCNVector3(0.45, 0.75, -0.35)
            scene.rootNode.addChildNode(fillNode)

        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Ground
        // ════════════════════════════════════════════════════════════════════

        private func buildGround() {
            let ground = SCNCylinder(radius: 0.52, height: 0.045)
            ground.radialSegmentCount = 128

            let mat         = SCNMaterial()
            mat.name        = "humaSoil"
            // The plot is a color-matched foreground patch, not a separate
            // sunlit object. Keeping it unlit prevents the warm key light
            // from washing the soil into the pale cream seen in the overlay.
            mat.lightingModel = .constant
            // Match the photographic soil directly (#6A4B33), instead of
            // tinting a brighter albedo texture and ending up with a lighter
            // foreground disk.
            mat.diffuse.contents = UIColor(red: 106.0 / 255.0,
                                           green: 75.0 / 255.0,
                                           blue: 51.0 / 255.0,
                                           alpha: 1)
            mat.shaderModifiers = [.fragment: """
            #pragma transparent
            #pragma body
            float radius = length(_surface.diffuseTexcoord - float2(0.5));
            _output.color.a *= 0.92 * (1.0 - smoothstep(0.22, 0.49, radius));
            """]
            mat.transparencyMode = .aOne
            mat.writesToDepthBuffer = false
            smoothTextureSampling(mat.diffuse)
            mat.roughness.contents = 0.94
            mat.metalness.contents = 0.0
            // multiply.contents is used to tint to charred black during burning
            mat.multiply.contents = UIColor.white
            ground.materials = [mat]
            groundMaterial = mat

            let node            = SCNNode(geometry: ground)
            node.name           = "groundPlot"
            node.position.y     = 0.012
            // The photographic backdrop already contains the exact soil
            // surface. Keep this cylinder for physics/contact only; drawing
            // it creates an artificial curved disk over the background.
            node.opacity       = 0
            node.movabilityHint = .fixed
            node.physicsBody    = SCNPhysicsBody(
                type: .static,
                shape: SCNPhysicsShape(
                    geometry: SCNCylinder(radius: 0.52, height: 0.045),
                    options: nil))
            scene.rootNode.addChildNode(node)
            // A real SceneKit shadow receiver over the photographic ground.
            let receiverMaterial = SCNMaterial()
            receiverMaterial.lightingModel = .shadowOnly
            receiverMaterial.isDoubleSided = true
            receiverMaterial.writesToDepthBuffer = false
            let receiverGeometry = SCNPlane(width: 3, height: 3)
            receiverGeometry.materials = [receiverMaterial]
            let receiver = SCNNode(geometry: receiverGeometry)
            receiver.name = "soilShadowReceiver"
            receiver.position.y = soilY
            receiver.eulerAngles.x = -.pi / 2
            receiver.castsShadow = false
            scene.rootNode.addChildNode(receiver)
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Stage 1 – Forest (p 0.00 → 0.33)
        // ════════════════════════════════════════════════════════════════════

        private func buildForest() {
            forestRoot.name = "forest"
            scene.rootNode.addChildNode(forestRoot)
            shadowRoot.name = "treeShadows"
            scene.rootNode.addChildNode(shadowRoot)

            // Deliberately irregular placement: varied depth, scale and yaw
            // keep the forest from reading as a repeated row of clones.
            scene.rootNode.addChildNode(stumpRoot)
            let placements: [(x: Float, z: Float, yaw: Float, scale: Float)] = [
                (-0.34, -0.15, -0.12, 0.78),
                ( 0.27, -0.20,  0.16, 1.08),
                (-0.10,  0.03, -0.08, 0.93),
                ( 0.36,  0.10,  0.11, 0.70),
                (-0.28,  0.22, -0.18, 1.22)
            ]
            for (i, placement) in placements.enumerated() {
                addTexturedTree(index: i, x: placement.x, z: placement.z,
                                yaw: placement.yaw, scale: placement.scale)
            }
        }

        // All rooted objects share this surface, including their contact shadows.
        private let soilY: Float = 0.038
        private let treeSoilRoot = SCNNode()
        private let riceSoilRoot = SCNNode()

        private func addTexturedTree(index: Int, x: Float, z: Float,
                                     yaw: Float, scale: Float) {
            let texture = UIImage(named: "HumaTreeNatural") ?? UIImage(named: "HumaTree")
            let material = SCNMaterial()
            // The tree atlas already carries painted sunset shading. Preserve
            // its colors and let the shared scene lighting shade the 3D trunk,
            // grass, and rice together.
            material.lightingModel = .constant
            material.diffuse.contents = texture
            material.multiply.contents = UIColor.white
            material.isDoubleSided = true
            material.transparencyMode = .aOne
            material.writesToDepthBuffer = false
            material.readsFromDepthBuffer = true
            smoothTextureSampling(material.diffuse)

            let pivot = SCNNode()
            pivot.name = "treeCutPivot_\(index)"
            pivot.position = SCNVector3(x, soilY, z)
            pivot.scale = SCNVector3(scale, scale, scale)
            pivot.eulerAngles.y = yaw
            let wood = stumpMaterial(index: index)

            // The source artwork already contains the complete trunk and
            // crown. Keep exactly one tree card; separate trunk meshes create
            // a misaligned dark duplicate beside the textured trunk.
            let plane = solidTreeGeometry.copy() as! SCNGeometry
            plane.materials = solidTreeGeometry.materials.map { $0.copy() as! SCNMaterial }
            let canopy = SCNNode()
            canopy.name = "treeSprite_\(index)"
            canopy.position.y = 0
            let front = SCNNode(geometry: plane)
            front.name = "treeSilhouette"
            front.position.z = 0
            canopy.addChildNode(front)
            // Radial leaf masses extend along Z as well as X. They use UV
            // windows into the original crown artwork, never another full tree.
            let radial = SCNNode(geometry: radialCrownGeometry.copy() as? SCNGeometry)
            radial.name = "radialFoliage"
            let radialMaterial = SCNMaterial()
            // The original atlas remains the visible albedo on the front
            // shell. This secondary volume is deliberately low-poly and
            // softly green so it supplies occlusion/depth without creating a
            // second, misaligned bark texture behind the tree.
            radialMaterial.lightingModel = .constant
            radialMaterial.diffuse.contents = UIColor(red: 0.12, green: 0.17, blue: 0.045, alpha: 1)
            radialMaterial.multiply.contents = UIColor(white: 0.72, alpha: 1)
            radialMaterial.isDoubleSided = true
            radialMaterial.writesToDepthBuffer = true
            radial.geometry?.materials = [radialMaterial]
            radial.position = SCNVector3(0, -0.012, -0.018)
            radial.opacity = 0
            radial.isHidden = true
            canopy.addChildNode(radial)
            let supports = SCNNode()
            // A low-poly branch scaffold gives the crown a readable core
            // when the front atlas is blended away during the fall.
            for i in 0..<12 {
                let a = Float(i) * 2.39996
                let direction = SIMD3<Float>(cos(a), 0, sin(a))
                let p0 = SIMD3<Float>(0, 0.255, -0.012)
                let p1 = direction * 0.045 + SIMD3<Float>(0, 0.305, -0.038)
                let p2 = direction * 0.092 + SIMD3<Float>(0, 0.355, -0.058)
                let p3 = direction * 0.135 + SIMD3<Float>(0, 0.382, -0.062)
                supports.addChildNode(branch(from: p0, to: p1,
                    radius: 0.0034, material: wood))
                supports.addChildNode(branch(from: p1, to: p2,
                    radius: 0.0025, material: wood))
                supports.addChildNode(branch(from: p2, to: p3,
                    radius: 0.0017, material: wood))
                // Two small twigs per primary branch make the canopy read as
                // a connected tree instead of a stack of floating cards.
                for twig in 0..<2 {
                    let side: Float = twig == 0 ? 1.0 : -1.0
                    let tangent = SIMD3<Float>(-sin(a) * side, 0, cos(a) * side)
                    let twigStart = p2 + tangent * 0.004
                    let twigEnd = p2 + direction * 0.036 + tangent * 0.026
                        + SIMD3<Float>(0, 0.018, 0)
                    supports.addChildNode(branch(from: twigStart, to: twigEnd,
                        radius: 0.00115, material: wood))
                }
            }
            let rearBranches = supports.flattenedClone()
            rearBranches.name = "radialBranches"
            rearBranches.opacity = 0
            rearBranches.isHidden = true
            canopy.addChildNode(rearBranches)
            pivot.addChildNode(canopy)

            forestRoot.addChildNode(pivot)
            treeNodes.append((trunk: pivot, canopy: canopy, fallAngle: Float(index) / 4, origin: pivot.position))

            let stumpHeight: Float = 0.045 * scale
            let stumpGeometry = SCNCone(topRadius: CGFloat(0.012 * scale),
                bottomRadius: CGFloat(0.014 * scale), height: CGFloat(stumpHeight))
            stumpGeometry.radialSegmentCount = 16
            stumpGeometry.materials = [wood.copy() as! SCNMaterial]
            let stump = SCNNode(geometry: stumpGeometry)
            stump.position = SCNVector3(x, soilY + stumpHeight * 0.5 - 0.003, z)
            stumpRoot.addChildNode(stump)

            if treeSoilRoot.parent == nil { scene.rootNode.addChildNode(treeSoilRoot) }
            addRootContact(to: treeSoilRoot, x: x, z: z, radius: 0.037 * scale)
            let shadowMaterial = SCNMaterial()
            shadowMaterial.lightingModel = .constant
            shadowMaterial.diffuse.contents = particleSprite
            shadowMaterial.multiply.contents = UIColor(white: 0.03, alpha: 1)
            shadowMaterial.isDoubleSided = true
            shadowMaterial.writesToDepthBuffer = false
            let shadowGeometry = SCNPlane(width: CGFloat(0.25 * scale), height: CGFloat(0.15 * scale))
            shadowGeometry.materials = [shadowMaterial]
            let shadow = SCNNode(geometry: shadowGeometry)
            shadow.eulerAngles.x = -.pi / 2
            shadow.position = SCNVector3(x, soilY + 0.0003, z)
            shadow.castsShadow = false
            shadowRoot.addChildNode(shadow)
        }

        /// One shared mesh: original full-resolution artwork on the front,
        /// with a closed body derived from its alpha mask. Sampling is used
        /// only to construct geometry; the bundled image remains untouched.
        private lazy var solidTreeGeometry: SCNGeometry = {
            let image = UIImage(named: "HumaTreeNatural") ?? UIImage(named: "HumaTree")
            let size = 192
            var pixels = [UInt8](repeating: 0, count: size * size * 4)
            pixels.withUnsafeMutableBytes { bytes in
                guard let context = CGContext(data: bytes.baseAddress, width: size, height: size,
                    bitsPerComponent: 8, bytesPerRow: size * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                    let cg = image?.cgImage else { return }
                context.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
            }
            func opaque(_ x: Int, _ y: Int) -> Bool {
                guard x >= 0, y >= 0, x < size, y < size else { return false }
                return pixels[((size - 1 - y) * size + x) * 4 + 3] > 180
            }
            // Erosion keeps the closed body safely inside the fine leaf edges.
            func occupied(_ x: Int, _ y: Int) -> Bool {
                guard x >= 0, y >= 0, x < size, y < size else { return false }
                for dy in -1...1 {
                    for dx in -1...1 where !opaque(x + dx, y + dy) { return false }
                }
                return true
            }
            var vertices: [SCNVector3] = []
            var normals: [SCNVector3] = []
            var uv: [CGPoint] = []
            var frontIndices: [UInt32] = []
            var bodyIndices: [UInt32] = []
            func quad(_ points: [SIMD3<Float>], _ coords: [CGPoint], body: Bool) {
                let base = UInt32(vertices.count)
                let n = simd_normalize(simd_cross(points[1] - points[0], points[2] - points[0]))
                vertices += points.map { SCNVector3($0) }
                normals += Array(repeating: SCNVector3(n), count: 4)
                uv += coords
                let indices: [UInt32] = [base, base + 1, base + 2, base, base + 2, base + 3]
                if body { bodyIndices += indices } else { frontIndices += indices }
            }
            let width: Float = 0.34, height: Float = 0.50
            // Subdivide the original front surface so crown regions can bend
            // independently. UVs still sample the exact original image.
            for row in 0..<40 {
                for column in 0..<32 {
                    let u0 = Float(column)/32, u1 = Float(column+1)/32
                    let v0 = Float(row)/40, v1 = Float(row+1)/40
                    quad([SIMD3((u0-0.5)*width,v0*height,0),
                          SIMD3((u1-0.5)*width,v0*height,0),
                          SIMD3((u1-0.5)*width,v1*height,0),
                          SIMD3((u0-0.5)*width,v1*height,0)],
                         [CGPoint(x: CGFloat(u0), y: CGFloat(1-v0)),
                          CGPoint(x: CGFloat(u1), y: CGFloat(1-v0)),
                          CGPoint(x: CGFloat(u1), y: CGFloat(1-v1)),
                          CGPoint(x: CGFloat(u0), y: CGFloat(1-v1))], body: false)
                }
            }
            for y in 0..<size {
                for x in 0..<size where occupied(x, y) {
                    let u0 = Float(x) / Float(size), u1 = Float(x + 1) / Float(size)
                    let v0 = Float(y) / Float(size), v1 = Float(y + 1) / Float(size)
                    // Crown has substantial depth; trunk and roots stay narrow.
                    // A deeper crown shell gives the original textured tree
                    // visible sidewalls when it rotates, without adding any
                    // second foliage card behind it.
                    let d: Float = v0 > 0.60 ? 0.045 : 0.012
                    let a = SIMD3<Float>((u0 - 0.5)*width, v0*height, 0)
                    let b = SIMD3<Float>((u1 - 0.5)*width, v0*height, 0)
                    let c = SIMD3<Float>((u1 - 0.5)*width, v1*height, 0)
                    let e = SIMD3<Float>((u0 - 0.5)*width, v1*height, 0)
                    // Extrude away along the initial camera ray to keep the
                    // body hidden by the source silhouette in the standing pose.
                    let offset = SIMD3<Float>(0, -0.24*d, -d)
                    let coords = [CGPoint(x: CGFloat(u0), y: CGFloat(1-v0)),
                        CGPoint(x: CGFloat(u1), y: CGFloat(1-v0)),
                        CGPoint(x: CGFloat(u1), y: CGFloat(1-v1)),
                        CGPoint(x: CGFloat(u0), y: CGFloat(1-v1))]
                    let rear = coords.map { CGPoint(x: $0.x * 0.92 + 0.04,
                                                    y: max(0, $0.y - CGFloat(d / height))) }
                    quad([e+offset, c+offset, b+offset, a+offset], coords.reversed(), body: true)
                    if !occupied(x-1, y) { quad([a,e,e+offset,a+offset], [coords[0],coords[3],rear[3],rear[0]], body: true) }
                    if !occupied(x+1, y) { quad([c,b,b+offset,c+offset], [coords[2],coords[1],rear[1],rear[2]], body: true) }
                    if !occupied(x, y-1) { quad([b,a,a+offset,b+offset], [coords[1],coords[0],rear[0],rear[1]], body: true) }
                    if !occupied(x, y+1) { quad([e,c,c+offset,e+offset], [coords[3],coords[2],rear[2],rear[3]], body: true) }
                }
            }
            let front = SCNMaterial()
            front.lightingModel = .constant
            front.diffuse.contents = image
            front.isDoubleSided = true
            front.transparencyMode = .aOne
            front.writesToDepthBuffer = true
            front.shaderModifiers = [.geometry: """
            #pragma arguments
            float treeWindTime;
            float treeWindAmplitude;
            float treeCrownBlend;
            #pragma body
            float3 rest = _geometry.position.xyz;
            float crown = smoothstep(0.255, 0.355, rest.y);
            // Three rounded crown lobes replace the shallow planar bulge.
            // Both shell surfaces follow the same rounded profile so fine
            // alpha edges do not become long extruded spikes during rotation.
            float2 left = (rest.xy - float2(-0.087, 0.385)) / float2(0.095, 0.090);
            float2 middle = (rest.xy - float2(0.0, 0.423)) / float2(0.105, 0.078);
            float2 right = (rest.xy - float2(0.087, 0.390)) / float2(0.095, 0.086);
            float lobeL = sqrt(max(0.0, 1.0 - dot(left, left)));
            float lobeM = sqrt(max(0.0, 1.0 - dot(middle, middle)));
            float lobeR = sqrt(max(0.0, 1.0 - dot(right, right)));
            float roundness = crown * (0.65 * max(lobeL, max(lobeM, lobeR))
                + 0.35 * (lobeL + lobeM + lobeR) / 3.0);
            float dome = roundness * 0.050;
            float wave = 0.70 * sin(treeWindTime * 0.72 + rest.x * 21.0)
                       + 0.30 * sin(treeWindTime * 1.13 + rest.y * 38.0 + rest.x * 11.0);
            float flutter = sin(treeWindTime * 1.35 + rest.x * 63.0 + rest.y * 29.0);
            float sway = crown * treeWindAmplitude;
            _geometry.position.x += sway * wave;
            _geometry.position.z += dome + sway * flutter * 0.55;
            _geometry.position.y += dome * 0.24 + sway * flutter * 0.08;
            """, .fragment: """
            #pragma arguments
            float treeCrownBlend;
            #pragma transparent
            #pragma body
            // Keep the original trunk visible at the cut pivot while the
            // crown dissolves into the radial 3D leaf structure.
            float crownMask = 1.0 - smoothstep(0.42, 0.55,
                _surface.diffuseTexcoord.y);
            _output.color.a *= 1.0 - treeCrownBlend * crownMask;
            if (_output.color.a < 0.08) { discard_fragment(); }
            """]
            front.setValue(Float(0), forKey: "treeWindTime")
            front.setValue(Float(0), forKey: "treeWindAmplitude")
            front.setValue(Float(0), forKey: "treeCrownBlend")
            smoothTextureSampling(front.diffuse)
            let body = front.copy() as! SCNMaterial
            body.lightingModel = .constant
            body.multiply.contents = UIColor(white: 0.83, alpha: 1)
            body.isDoubleSided = true
            body.setValue(Float(0), forKey: "treeCrownBlend")
            let geometry = SCNGeometry(sources: [.init(vertices: vertices), .init(normals: normals),
                .init(textureCoordinates: uv)], elements: [
                    .init(indices: frontIndices, primitiveType: .triangles),
                    .init(indices: bodyIndices, primitiveType: .triangles)])
            geometry.materials = [front, body]
            return geometry
        }()

        /// Shared low-poly leaf volume. Rounded clumps are distributed around
        /// the same branch centre as the source atlas. They add real depth and
        /// rear-facing foliage while the original textured silhouette remains
        /// the front-facing appearance.
        private lazy var radialCrownGeometry: SCNGeometry = {
            var vertices: [SIMD3<Float>] = []
            var normals: [SIMD3<Float>] = []
            var indices: [UInt32] = []

            let rings = 6
            let sides = 12
            let clumpCount = 18
            for i in 0..<clumpCount {
                let fi = Float(i)
                let a = fi * 2.39996
                let radial = sqrt((fi + 1) / Float(clumpCount)) * 0.115
                let center = SIMD3<Float>(
                    cos(a) * radial,
                    0.355 + 0.085 * (1 - radial / 0.115)
                        + sin(fi * 1.71) * 0.018,
                    -0.050 + sin(a) * radial * 0.72 + cos(fi * 2.17) * 0.012)
                let rx = 0.050 + 0.012 * (0.5 + 0.5 * sin(fi * 1.53))
                let ry = 0.038 + 0.010 * (0.5 + 0.5 * cos(fi * 2.13))
                let rz = 0.048 + 0.014 * (0.5 + 0.5 * sin(fi * 2.77))
                let rotation = simd_quatf(angle: a + sin(fi * 2.01) * 0.30,
                                          axis: SIMD3<Float>(0, 1, 0))
                    * simd_quatf(angle: sin(fi * 1.37) * 0.32,
                                 axis: SIMD3<Float>(1, 0, 0))
                    * simd_quatf(angle: cos(fi * 2.41) * 0.28,
                                 axis: SIMD3<Float>(0, 0, 1))
                let base = UInt32(vertices.count)
                for ring in 0...rings {
                    let theta = Float(ring) / Float(rings) * .pi
                    for side in 0...sides {
                        let phi = Float(side) / Float(sides) * 2 * .pi
                        let unit = SIMD3<Float>(sin(theta) * cos(phi),
                                                cos(theta),
                                                sin(theta) * sin(phi))
                        let local = SIMD3<Float>(unit.x * rx, unit.y * ry, unit.z * rz)
                        vertices.append(center + rotation.act(local))
                        normals.append(rotation.act(unit))
                        if ring < rings && side < sides {
                            let b = base + UInt32(ring * (sides + 1) + side)
                            let n = b + UInt32(sides + 1)
                            indices += [b, n, b + 1, b + 1, n, n + 1]
                        }
                    }
                }
            }

            return SCNGeometry(sources: [.init(vertices: vertices.map(SCNVector3.init)),
                .init(normals: normals.map(SCNVector3.init))],
                elements: [.init(indices: indices, primitiveType: .triangles)])
        }()

        /// A tight contact shadow and a shallow, irregular soil lip. Both are
        /// fixed to the ground, so cutting moves the tree but never its soil.
        private func addRootContact(to parent: SCNNode, x: Float, z: Float, radius: Float) {
            let shadowMaterial = SCNMaterial()
            shadowMaterial.lightingModel = .constant
            shadowMaterial.diffuse.contents = particleSprite
            shadowMaterial.multiply.contents = UIColor(white: 0.025, alpha: 1)
            shadowMaterial.transparency = 0.50
            shadowMaterial.isDoubleSided = true
            shadowMaterial.writesToDepthBuffer = false
            let plane = SCNPlane(width: CGFloat(radius * 2.8), height: CGFloat(radius * 2.8))
            plane.materials = [shadowMaterial]
            let shadow = SCNNode(geometry: plane)
            shadow.position = SCNVector3(x, soilY + 0.0002, z)
            shadow.eulerAngles.x = -.pi / 2
            shadow.castsShadow = false
            parent.addChildNode(shadow)

            var positions: [SCNVector3] = []
            var coords: [CGPoint] = []
            var triangles: [UInt32] = []
            let sides = 40
            for ring in 0...3 {
                let t = Float(ring) / 3
                for j in 0...sides {
                    let a = Float(j) / Float(sides) * 2 * .pi
                    let radiusAtAngle = radius * (1 + 0.10 * sin(a * 5) + 0.07 * cos(a * 9))
                    let r = t * radiusAtAngle
                    // Just 5 mm of soil covers the stem base. No large mound.
                    let y = soilY + 0.005 * (1 - t * t)
                    positions.append(SCNVector3(cos(a) * r, y, sin(a) * r))
                    coords.append(CGPoint(x: CGFloat(cos(a) * t * 0.5 + 0.5),
                                          y: CGFloat(sin(a) * t * 0.5 + 0.5)))
                    if ring < 3 && j < sides {
                        let b = UInt32(ring * (sides + 1) + j)
                        let n = b + UInt32(sides + 1)
                        triangles += [b, b + 1, n, b + 1, n + 1, n]
                    }
                }
            }
            let soil = SCNMaterial()
            soil.lightingModel = .constant
            soil.diffuse.contents = UIImage(named: "HumaTerrainTexture")
                ?? UIColor(red: 0.31, green: 0.22, blue: 0.15, alpha: 1)
            soil.multiply.contents = UIColor(red: 0.40, green: 0.33, blue: 0.27, alpha: 1)
            soil.isDoubleSided = true
            soil.shaderModifiers = [.fragment: """
            #pragma transparent
            #pragma body
            float r = length(_surface.diffuseTexcoord - float2(0.5));
            _output.color.a *= 1.0 - smoothstep(0.30, 0.50, r);
            if (_output.color.a < 0.02) { discard_fragment(); }
            """]
            let mesh = SCNGeometry(sources: [.init(vertices: positions),
                .init(textureCoordinates: coords)],
                elements: [.init(indices: triangles, primitiveType: .triangles)])
            mesh.materials = [soil]
            let lip = SCNNode(geometry: mesh)
            lip.position = SCNVector3(x, 0, z)
            lip.castsShadow = false
            parent.addChildNode(lip)
        }

        private func stumpMaterial(index: Int) -> SCNMaterial {
            let material = SCNMaterial()
            material.lightingModel = .lambert
            material.diffuse.contents = UIImage(named: "HumaWoodTexture")
                ?? UIColor(red: 0.32, green: 0.20, blue: 0.12, alpha: 1)
            material.multiply.contents = UIColor(red: 0.78, green: 0.62, blue: 0.46, alpha: 1)
            material.roughness.contents = 1.0
            smoothTextureSampling(material.diffuse)
            return material
        }

        private func branch(from start: SIMD3<Float>, to end: SIMD3<Float>,
                            radius: Float, material: SCNMaterial) -> SCNNode {
            let vector = end - start
            let geometry = SCNCone(topRadius: CGFloat(radius * 0.8),
                                   bottomRadius: CGFloat(radius), height: CGFloat(simd_length(vector)))
            geometry.radialSegmentCount = 16
            geometry.materials = [material]
            let node = SCNNode(geometry: geometry)
            node.simdPosition = (start + end) * 0.5
            node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(vector))
            return node
        }

        /// Continuous rings share vertices and normals: no stacked cone seams.
        private func curvedTrunk(height: Float, radius: Float, material: SCNMaterial) -> SCNNode {
            let rings = 32, sides = 16
            var vertices: [SCNVector3] = [], normals: [SCNVector3] = []
            var uvs: [CGPoint] = [], indices: [UInt32] = []
            for ring in 0...rings {
                let t = Float(ring) / Float(rings)
                let center = SIMD3<Float>(sin(t * .pi * 2) * 0.006, height * t, sin(t * .pi) * 0.006)
                let tangent = simd_normalize(SIMD3<Float>(cos(t * .pi * 2) * .pi * 0.012,
                    height, cos(t * .pi) * .pi * 0.006))
                let right = simd_normalize(simd_cross(tangent, SIMD3<Float>(0, 0, 1)))
                let forward = simd_normalize(simd_cross(right, tangent))
                for side in 0...sides {
                    let a = Float(side) / Float(sides) * 2 * .pi
                    let n = right * cos(a) + forward * sin(a)
                    vertices.append(SCNVector3(center + n * radius * (1 - t * 0.5)))
                    normals.append(SCNVector3(n))
                    uvs.append(CGPoint(x: Double(side) / Double(sides), y: Double(t)))
                    if ring < rings && side < sides {
                        let b = UInt32(ring * (sides + 1) + side), next = b + UInt32(sides + 1)
                        indices += [b, next, b + 1, b + 1, next, next + 1]
                    }
                }
            }
            let geometry = SCNGeometry(sources: [.init(vertices: vertices), .init(normals: normals),
                .init(textureCoordinates: uvs)], elements: [.init(indices: indices, primitiveType: .triangles)])
            geometry.materials = [material]
            return SCNNode(geometry: geometry)
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Stage 1 – Wild grass undergrowth
        // ════════════════════════════════════════════════════════════════════

        private func buildWildGrass() {
            wildRoot.name = "wildGrass"
            scene.rootNode.addChildNode(wildRoot)
            for index in 0..<52 {
                let angle    = Float(index) * 2.3999
                let distance = 0.10 + Float((index * 13) % 31) * 0.011
                let base     = SCNVector3(cos(angle) * distance, 0.038, sin(angle) * distance)
                let height   = 0.065 + Float(index % 7) * 0.008
                let tint: UIColor = index.isMultiple(of: 3)
                    ? UIColor(red: 0.55, green: 0.58, blue: 0.23, alpha: 1)
                    : UIColor(red: 0.32, green: 0.48, blue: 0.16, alpha: 1)
                addBlade(
                    to: wildRoot,
                    base: base,
                    height: height,
                    width: 0.018,
                    yaw: angle + Float(index % 5) * 0.21,
                    mass: 0.16,
                    response: 1.0,
                    tint: tint,
                    phase: Float(index % 9) * 0.42
                )
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Transition 1→2 – Fire embers
        // ════════════════════════════════════════════════════════════════════

        private func buildFire() {
            fireRoot.name = "fire"
            scene.rootNode.addChildNode(fireRoot)
            fireLight.type = .omni
            fireLight.color = UIColor(red: 1, green: 0.48, blue: 0.12, alpha: 1)
            fireLight.intensity = 0
            fireLight.attenuationEndDistance = 0.9
            let glow = SCNNode()
            glow.light = fireLight
            glow.position = SCNVector3(0, 0.18, 0)
            fireRoot.addChildNode(glow)

            // Five small emitters keep the flame silhouette rich without
            // waking eight particle systems at the same instant.
            for i in 0..<5 {
                let phase: Float = Float(i) * 0.785   // π/4 spacing
                let angle: Float = Float(i) * 1.3
                let dist:  Float = 0.05 + Float(i % 4) * 0.055
                let baseX: Float = cos(angle) * dist
                let baseZ: Float = sin(angle) * dist
                let emitter = SCNNode()
                emitter.position = SCNVector3(baseX, 0.05, baseZ)
                let flames = makeFlames()
                emitter.addParticleSystem(flames)
                fireRoot.addChildNode(emitter)
                flameSystems.append(flames)

                let sphere     = SCNSphere(radius: 0.012)
                sphere.segmentCount = 8
                let mat        = SCNMaterial()
                mat.lightingModel = .physicallyBased
                mat.diffuse.contents  = UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1)
                mat.emission.contents = UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1)
                mat.emission.intensity = 2.0
                mat.roughness.contents = 0.3
                mat.metalness.contents = 0.0
                sphere.materials = [mat]

                let node       = SCNNode(geometry: sphere)
                node.name      = "ember_\(i)"
                node.position  = SCNVector3(baseX, 0.06, baseZ)
                node.opacity   = 0
                node.isHidden  = true
                fireRoot.addChildNode(node)

                emberNodes.append((node: node, baseX: baseX, baseZ: baseZ, phase: phase))
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Transition 1→2 – Ash clods
        // ════════════════════════════════════════════════════════════════════

        private func buildAsh() {
            ashRoot.name = "ash"
            scene.rootNode.addChildNode(ashRoot)
            for i in 0..<6 {
                let angle: Float = Float(i) * 1.047    // 60° steps
                let dist:  Float = 0.07 + Float(i % 3) * 0.08
                let x     = cos(angle) * dist
                let z     = sin(angle) * dist

                let sphere    = SCNSphere(radius: 0.014)
                sphere.segmentCount = 8
                let mat       = SCNMaterial()
                mat.lightingModel = .lambert
                mat.diffuse.contents  = UIColor(red: 0.14, green: 0.10, blue: 0.08, alpha: 1)
                mat.roughness.contents = 0.98
                mat.metalness.contents = 0.0
                sphere.materials = [mat]

                let node      = SCNNode(geometry: sphere)
                node.position = SCNVector3(x, 0.038, z)
                node.opacity  = 0
                node.isHidden = true
                ashRoot.addChildNode(node)
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Stage 3 – Planting (holes + seeds)
        // ════════════════════════════════════════════════════════════════════

        private func buildPlantingStage() {
            plantingRoot.name = "plantingStage"
            scene.rootNode.addChildNode(plantingRoot)

            let positions: [SCNVector3] = [.init(0, 0.039, 0)]
            /*
                .init(0,     0.039, 0),    .init(-0.10, 0.039, -0.05),
                .init(0.10,  0.039, -0.05),.init(-0.16, 0.039,  0.04),
                .init(0.16,  0.039,  0.04),.init(0,     0.039,  0.12),
                .init(-0.08, 0.039,  0.14),.init(0.08,  0.039,  0.14),
                .init(-0.05, 0.039, -0.14),.init(0.05,  0.039, -0.14),
            ]*/

            for (index, position) in positions.enumerated() {
                // ── Dibble hole ────────────────────────────────────────────
                let hole = SCNTorus(ringRadius: 0.017, pipeRadius: 0.006)
                hole.ringSegmentCount = 24
                let holeMat = SCNMaterial()
                holeMat.lightingModel = .physicallyBased
                holeMat.diffuse.contents  = UIColor(red: 0.10, green: 0.06, blue: 0.035, alpha: 1)
                holeMat.roughness.contents = 1.0
                holeMat.metalness.contents = 0.0
                hole.materials = [holeMat]
                let holeNode = SCNNode(geometry: hole)
                holeNode.name     = "hole_\(index)"
                holeNode.position = position
                plantingRoot.addChildNode(holeNode)

                // ── Seed sphere ────────────────────────────────────────────
                let seed    = SCNSphere(radius: 0.008)
                seed.segmentCount = 8
                let seedMat = SCNMaterial()
                seedMat.lightingModel = .lambert
                seedMat.diffuse.contents  = UIColor(red: 0.95, green: 0.90, blue: 0.78, alpha: 1)
                seedMat.roughness.contents = 0.70
                seedMat.metalness.contents = 0.0
                seed.materials = [seedMat]
                let seedNode        = SCNNode(geometry: seed)
                seedNode.name       = "seed_\(index)"
                seedNode.position   = SCNVector3(position.x, position.y + 0.015, position.z)
                seedNode.scale      = SCNVector3(0.001, 0.001, 0.001)
                seedNode.opacity    = 0
                seedNode.isHidden   = true
                plantingRoot.addChildNode(seedNode)
                seedNodes.append(seedNode)

            }
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Stage 3+4 – Rice plant
        // ════════════════════════════════════════════════════════════════════

        private func buildRicePlant() {
            leavesRoot.name   = "riceLeaves"
            paniclesRoot.name = "ricePanicles"
            scene.rootNode.addChildNode(leavesRoot)
            scene.rootNode.addChildNode(paniclesRoot)
            // Growth scales around the rooted base, never around world zero.
            leavesRoot.pivot = SCNMatrix4MakeTranslation(0, soilY, 0)
            paniclesRoot.pivot = SCNMatrix4MakeTranslation(0, soilY, 0)
            leavesRoot.position.y = soilY
            paniclesRoot.position.y = soilY
            scene.rootNode.addChildNode(riceSoilRoot)
            addRootContact(to: riceSoilRoot, x: 0, z: 0, radius: 0.055)

            for index in 0..<34 {
                let ring     = index / 9
                let angle    = Float(index) * 2.3999
                let height   = 0.36 + Float(index % 6) * 0.035
                let distance = Float(ring) * 0.014
                let base     = SCNVector3(cos(angle) * distance, 0.038, sin(angle) * distance)
                let material = addBlade(
                    to: leavesRoot,
                    base: base,
                    height: height,
                    width: 0.022,
                    yaw: angle,
                    mass: 0.30,
                    response: 0.68,
                    tint: UIColor(red: 0.28, green: 0.58, blue: 0.16, alpha: 1),
                    phase: Float(index % 11) * 0.35
                )
                leafMaterials.append(material)
            }

            for index in 0..<11 {
                let angle  = Float(index) * 2.3999
                let mat    = addBlade(
                    to: paniclesRoot,
                    base: SCNVector3(cos(angle) * 0.025, 0.038, sin(angle) * 0.025),
                    height: 0.48 + Float(index % 3) * 0.025,
                    width: 0.012,
                    yaw: angle,
                    mass: 0.52,
                    response: 0.48,
                    tint: UIColor(red: 0.88, green: 0.69, blue: 0.18, alpha: 1),
                    phase: Float(index) * 0.47
                )
                mat.multiply.contents = UIColor(red: 0.88, green: 0.69, blue: 0.18, alpha: 1)
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Stage 5 – Leuit (raised rice barn)
        // ════════════════════════════════════════════════════════════════════

        /// A compact low-poly lumbung built from a handful of reusable
        /// primitives. It is intentionally a single rooted assembly: the
        /// camera pan reveals volume, while the wood/thatch albedos keep it
        /// visually consistent with the existing agricultural scene.
        private func buildLeuit() {
            leuitRoot.name = "leuit"
            // Start just outside the portrait camera's right edge; the final
            // pan brings this x-position into the center of the frame.
            leuitRoot.position = SCNVector3(0.55, 0, -0.16)
            leuitRoot.opacity = 0
            leuitRoot.isHidden = true
            scene.rootNode.addChildNode(leuitRoot)

            let wood = SCNMaterial()
            wood.name = "leuitWood"
            wood.lightingModel = .physicallyBased
            let woodTexture = UIImage(named: "HumaWoodTexture")
            wood.diffuse.contents = woodTexture
                ?? UIColor(red: 0.25, green: 0.14, blue: 0.08, alpha: 1)
            // Keep the albedo bright enough for the grain to read at the
            // barn's small on-screen scale.
            wood.multiply.contents = UIColor(red: 0.90, green: 0.78, blue: 0.64, alpha: 1)
            wood.roughness.contents = 0.92
            wood.metalness.contents = 0.0
            wood.diffuse.wrapS = .repeat
            wood.diffuse.wrapT = .repeat
            smoothTextureSampling(wood.diffuse)

            let thatch = SCNMaterial()
            thatch.name = "leuitThatch"
            thatch.lightingModel = .physicallyBased
            let thatchTexture = UIImage(named: "HumaThatchTexture")
            thatch.diffuse.contents = thatchTexture
                ?? UIColor(red: 0.48, green: 0.32, blue: 0.16, alpha: 1)
            thatch.multiply.contents = UIColor(red: 0.90, green: 0.78, blue: 0.52, alpha: 1)
            thatch.roughness.contents = 1.0
            thatch.metalness.contents = 0.0
            thatch.diffuse.wrapS = .repeat
            thatch.diffuse.wrapT = .repeat
            smoothTextureSampling(thatch.diffuse)

            let riceStalk = SCNMaterial()
            riceStalk.name = "leuitDriedRiceStalk"
            riceStalk.lightingModel = .physicallyBased
            riceStalk.diffuse.contents = UIColor(red: 0.83, green: 0.57, blue: 0.19, alpha: 1)
            riceStalk.roughness.contents = 1.0
            riceStalk.metalness.contents = 0.0

            let riceGrain = SCNMaterial()
            riceGrain.name = "leuitRiceGrain"
            riceGrain.lightingModel = .physicallyBased
            riceGrain.diffuse.contents = UIColor(red: 1.0, green: 0.72, blue: 0.25, alpha: 1)
            riceGrain.roughness.contents = 0.88
            riceGrain.metalness.contents = 0.0

            let darkWood = wood.copy() as! SCNMaterial
            darkWood.name = "leuitDoor"
            darkWood.multiply.contents = UIColor(red: 0.68, green: 0.40, blue: 0.22, alpha: 1)

            let woven = wood.copy() as! SCNMaterial
            woven.name = "leuitWovenBamboo"
            woven.multiply.contents = UIColor(red: 1.0, green: 0.88, blue: 0.62, alpha: 1)

            let stone = SCNMaterial()
            stone.name = "leuitFootingStone"
            stone.lightingModel = .physicallyBased
            stone.diffuse.contents = UIColor(red: 0.44, green: 0.40, blue: 0.34, alpha: 1)
            stone.roughness.contents = 1.0
            stone.metalness.contents = 0.0

            let postHeight: Float = 0.20
            let bodyHeight: Float = 0.26

            // Four short posts lift the storehouse above the soil.
            for x in [-0.14, 0.14] {
                for z in [-0.12, 0.12] {
                    let footingGeometry = SCNSphere(radius: 0.038)
                    footingGeometry.segmentCount = 10
                    footingGeometry.materials = [stone]
                    let footing = SCNNode(geometry: footingGeometry)
                    footing.scale = SCNVector3(1.15, 0.58, 0.9)
                    footing.position = SCNVector3(Float(x), soilY - 0.002, Float(z))
                    leuitRoot.addChildNode(footing)

                    let postGeometry = SCNCylinder(radius: 0.018, height: CGFloat(postHeight))
                    postGeometry.radialSegmentCount = 10
                    postGeometry.materials = [woven]
                    let post = SCNNode(geometry: postGeometry)
                    post.position = SCNVector3(Float(x), soilY + postHeight * 0.5, Float(z))
                    leuitRoot.addChildNode(post)
                }
            }

            let floorGeometry = SCNBox(width: 0.46, height: 0.035, length: 0.38, chamferRadius: 0.006)
            floorGeometry.materials = [wood.copy() as! SCNMaterial]
            let floor = SCNNode(geometry: floorGeometry)
            floor.position = SCNVector3(0, soilY + postHeight, 0)
            leuitRoot.addChildNode(floor)

            let bodyGeometry = SCNBox(width: 0.40, height: CGFloat(bodyHeight), length: 0.32, chamferRadius: 0.012)
            bodyGeometry.materials = [wood]
            let body = SCNNode(geometry: bodyGeometry)
            body.position = SCNVector3(0, soilY + postHeight + bodyHeight * 0.5 - 0.008, 0)
            leuitRoot.addChildNode(body)

            let bodyBaseY = soilY + postHeight - 0.008
            let bodyTopY = bodyBaseY + bodyHeight
            let frontZ: Float = 0.166

            // A woven panel fills the triangular gable above the square body.
            let gablePath = UIBezierPath()
            gablePath.move(to: CGPoint(x: -0.20, y: 0))
            gablePath.addLine(to: CGPoint(x: 0.20, y: 0))
            gablePath.addLine(to: CGPoint(x: 0, y: 0.145))
            gablePath.close()
            let gableGeometry = SCNShape(path: gablePath, extrusionDepth: 0.006)
            gableGeometry.materials = [woven]
            let gable = SCNNode(geometry: gableGeometry)
            gable.position = SCNVector3(0, bodyTopY, frontZ - 0.012)
            leuitRoot.addChildNode(gable)

            // Raised golden rails frame the body like the timber detail in
            // the reference leuit, while diagonal strips read as woven walls.
            for y in [bodyBaseY + 0.018, bodyTopY - 0.016] {
                let beamGeometry = SCNBox(width: 0.44, height: 0.018, length: 0.024, chamferRadius: 0.003)
                beamGeometry.materials = [woven]
                let beam = SCNNode(geometry: beamGeometry)
                beam.position = SCNVector3(0, y, frontZ + 0.008)
                leuitRoot.addChildNode(beam)
            }

            for panelCenterX: Float in [-0.13, 0.13] {
                for slope: Float in [-1, 1] {
                    for row in 0..<6 {
                        let stripGeometry = SCNBox(width: 0.145, height: 0.007, length: 0.004, chamferRadius: 0.002)
                        stripGeometry.materials = [woven]
                        let strip = SCNNode(geometry: stripGeometry)
                        strip.position = SCNVector3(
                            panelCenterX,
                            bodyBaseY + 0.043 + Float(row) * 0.031,
                            frontZ + 0.012
                        )
                        strip.eulerAngles.z = slope * 0.68
                        leuitRoot.addChildNode(strip)
                    }
                }
            }

            // A dark front door gives the barn a readable opening without
            // adding another high-poly mesh.
            let doorGeometry = SCNBox(width: 0.12, height: 0.18, length: 0.012, chamferRadius: 0.004)
            doorGeometry.materials = [darkWood]
            let door = SCNNode(geometry: doorGeometry)
            door.position = SCNVector3(0, bodyBaseY + 0.102, frontZ + 0.014)
            leuitRoot.addChildNode(door)

            // Narrow vertical boards make the door read as joined timber.
            for x: Float in [-0.038, 0, 0.038] {
                let plankGeometry = SCNBox(width: 0.003, height: 0.17, length: 0.002, chamferRadius: 0)
                plankGeometry.materials = [wood]
                let plank = SCNNode(geometry: plankGeometry)
                plank.position = SCNVector3(x, bodyBaseY + 0.102, frontZ + 0.022)
                leuitRoot.addChildNode(plank)
            }

            // A pair of rails and four rungs forms the small access ladder.
            for side: Float in [-1, 1] {
                let railGeometry = SCNBox(width: 0.014, height: 0.23, length: 0.016, chamferRadius: 0.004)
                railGeometry.materials = [woven]
                let rail = SCNNode(geometry: railGeometry)
                rail.position = SCNVector3(side * 0.068, soilY + 0.112, 0.245)
                rail.eulerAngles.z = side < 0 ? -0.13 : 0.13
                leuitRoot.addChildNode(rail)
            }
            for row in 0..<4 {
                let rungGeometry = SCNBox(width: 0.115, height: 0.012, length: 0.016, chamferRadius: 0.003)
                rungGeometry.materials = [wood]
                let rung = SCNNode(geometry: rungGeometry)
                rung.position = SCNVector3(0, soilY + 0.045 + Float(row) * 0.050, 0.245)
                leuitRoot.addChildNode(rung)
            }

            // Two overlapping planes form the roof, layered with visible
            // dried rice stalk bundles and small hanging grain heads.
            for side: Float in [-1, 1] {
                let roofGeometry = SCNBox(width: 0.29, height: 0.055, length: 0.48, chamferRadius: 0.008)
                roofGeometry.materials = [thatch.copy() as! SCNMaterial]
                let roof = SCNNode(geometry: roofGeometry)
                roof.position = SCNVector3(side * 0.12, bodyTopY + 0.068, 0)
                roof.eulerAngles.z = side < 0 ? 0.55 : -0.55
                leuitRoot.addChildNode(roof)

                for row in 0..<9 {
                    let z = -0.19 + Float(row) * 0.047
                    let stalkGeometry = SCNCylinder(radius: 0.0032, height: 0.34)
                    stalkGeometry.radialSegmentCount = 5
                    stalkGeometry.materials = [riceStalk]
                    let stalk = SCNNode(geometry: stalkGeometry)
                    stalk.position = SCNVector3(side * 0.12, bodyTopY + 0.068, z)
                    stalk.eulerAngles.z = side < 0 ? 2.15 : -2.15
                    leuitRoot.addChildNode(stalk)

                    // A few kernels on each exposed eave make the roof read
                    // as bundled padi rather than generic straw thatch.
                    for grainIndex in 0..<3 {
                        let grainGeometry = SCNSphere(radius: 0.0045)
                        grainGeometry.segmentCount = 6
                        grainGeometry.materials = [riceGrain]
                        let grain = SCNNode(geometry: grainGeometry)
                        grain.scale = SCNVector3(0.82, 1.65, 0.72)
                        grain.position = SCNVector3(
                            side * (0.238 + Float(grainIndex % 2) * 0.008),
                            bodyTopY - 0.018 - Float(grainIndex) * 0.012,
                            z + Float(grainIndex - 1) * 0.007
                        )
                        leuitRoot.addChildNode(grain)
                    }
                }
            }

            // The gable frame and front beam stay exposed below the thatch.
            let frontBeamGeometry = SCNBox(width: 0.43, height: 0.018, length: 0.020, chamferRadius: 0.003)
            frontBeamGeometry.materials = [woven]
            let frontBeam = SCNNode(geometry: frontBeamGeometry)
            frontBeam.position = SCNVector3(0, bodyTopY + 0.012, frontZ + 0.006)
            leuitRoot.addChildNode(frontBeam)

            for side: Float in [-1, 1] {
                let rafterGeometry = SCNBox(width: 0.018, height: 0.19, length: 0.018, chamferRadius: 0.003)
                rafterGeometry.materials = [woven]
                let rafter = SCNNode(geometry: rafterGeometry)
                rafter.position = SCNVector3(side * 0.095, bodyTopY + 0.068, frontZ + 0.008)
                rafter.eulerAngles.z = side < 0 ? -0.66 : 0.66
                leuitRoot.addChildNode(rafter)
            }

            let ridgeGeometry = SCNCylinder(radius: 0.014, height: 0.45)
            ridgeGeometry.radialSegmentCount = 10
            ridgeGeometry.materials = [woven]
            let ridge = SCNNode(geometry: ridgeGeometry)
            ridge.position = SCNVector3(0, bodyTopY + 0.142, 0)
            ridge.eulerAngles.x = .pi / 2
            leuitRoot.addChildNode(ridge)

            // Tight contact shadow anchors the raised building to the same
            // photographic soil as the trees and rice.
            let shadowMaterial = SCNMaterial()
            shadowMaterial.lightingModel = .constant
            shadowMaterial.diffuse.contents = particleSprite
            shadowMaterial.multiply.contents = UIColor(white: 0.035, alpha: 1)
            shadowMaterial.transparency = 0.36
            shadowMaterial.writesToDepthBuffer = false
            let shadowGeometry = SCNPlane(width: 0.52, height: 0.30)
            shadowGeometry.materials = [shadowMaterial]
            let shadow = SCNNode(geometry: shadowGeometry)
            shadow.name = "leuitContactShadow"
            shadow.position = SCNVector3(0, soilY + 0.0003, 0)
            shadow.eulerAngles.x = -.pi / 2
            shadow.castsShadow = false
            leuitRoot.addChildNode(shadow)
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: update(progress:)   ← the main cinematic driver
        // ════════════════════════════════════════════════════════════════════

        func update(progress: CGFloat) {
            targetProgress = min(1, max(0, progress))
            #if DEBUG
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--tree-progress=") }),
               let value = Double(argument.dropFirst("--tree-progress=".count)) {
                targetProgress = min(1, max(0, CGFloat(value)))
            }
            #endif
            if lastFrameTime == 0 || !isWindEnabled {
                displayedProgress = targetProgress
                displayedCameraPan = smoothstep(0.73, 0.95, Float(displayedProgress))
                applyProgress(displayedProgress)
            }
        }

        private func applyProgress(_ progress: CGFloat) {
            let fullP = Float(min(1, max(0, progress)))
            // Keep the original farming choreography intact through DIBUAT
            // at 75% of the timeline. The final quarter is reserved for the
            // rightward camera move and the leuit reveal.
            let p = min(1, fullP / 0.75)
            let time = Float(CACurrentMediaTime() - animationEpoch)

            // ── 1. Forest visibility & tree falling (p 0.00 → 0.33) ─────────
            // Keep the original tree cards readable while the fall begins,
            // then blend them into the radial 3D crown over the longer
            // cinematic clearing interval.
            let forestOpacity = 1 - smoothstep(0.24, 0.32, p)
            setVisibility(forestRoot, opacity: forestOpacity)
            setVisibility(treeSoilRoot, opacity: 1 - smoothstep(0.32, 0.39, p))
            setVisibility(riceSoilRoot, opacity: smoothstep(0.42, 0.52, p))
            shadowRoot.opacity = CGFloat(forestOpacity * (1 - 0.45 * smoothstep(0.02, 0.12, p)))
            setVisibility(wildRoot, opacity: 1 - smoothstep(0.28, 0.37, p))
            // Cut stumps must not be present in the untouched Nukuh state.
            // Reveal them only as the tree finishes its fall, then let the
            // burn transition hide them again with the rest of the field.
            let cutReveal = smoothstep(0.12, 0.19, p)
            let stumpFade = 1 - smoothstep(0.31, 0.38, p)
            setVisibility(stumpRoot, opacity: cutReveal * stumpFade)
            let char = CGFloat(1 - 0.8 * smoothstep(0.16, 0.24, p))
            for stump in stumpRoot.childNodes {
                stump.geometry?.materials.forEach { $0.multiply.contents = UIColor(white: char, alpha: 1) }
            }

            // Per-tree fall: each tree starts at a staggered global-p value
            for (index, entry) in treeNodes.enumerated() {
                let trunk  = entry.trunk
                // Stagger: tree i starts falling when global p crosses [0.10 + offset*0.08]
                let fallStart: Float = 0.02 + entry.fallAngle * 0.035
                let fallEnd:   Float = fallStart + 0.20
                let fallT = max(0, min(1, (p - fallStart) / (fallEnd - fallStart)))
                // One rigid body around a fixed base. A short forward lean is
                // followed by gravity-like acceleration up to ground contact.
                let contactTime: Float = 0.88
                let groundAngle: Float = 1.49
                let release = smoothstep(0, 0.12, fallT) * 0.018
                let descent = max(0, min(1, (fallT - 0.12) / (contactTime - 0.12)))
                let angle = release + (groundAngle - 0.018) * descent * descent
                let settling = max(0, min(1, (fallT - contactTime) / (1 - contactTime)))
                let rebound = 0.04 * sin(settling * .pi) * exp(-3 * settling)
                // Fall mostly across the screen, with a smaller forward roll
                // so the deepened crown shell exposes its side instead of
                // becoming an edge-on paper strip.
                trunk.eulerAngles.x = (angle - rebound) * 0.34
                trunk.eulerAngles.z = -(angle - rebound) * 0.94
                trunk.position = entry.origin

                // Wind dies away as the tree starts moving. The crown remains
                // attached rigidly instead of counter-rotating at a second base.
                entry.canopy.eulerAngles = SCNVector3Zero
                if let materials = entry.canopy.childNode(withName: "treeSilhouette", recursively: false)?.geometry?.materials {
                    for material in materials {
                        material.setValue(time + Float(index) * 1.37, forKey: "treeWindTime")
                        material.setValue(isWindEnabled ? Float(0.0035) * (1 - descent) : 0,
                                          forKey: "treeWindAmplitude")
                        material.setValue(Float(0),
                                          forKey: "treeCrownBlend")
                    }
                }
            let crownReveal: Float = 0
                if let radial = entry.canopy.childNode(withName: "radialFoliage", recursively: false),
                   let material = radial.geometry?.firstMaterial {
                    radial.opacity = CGFloat(crownReveal)
                    material.setValue(time + Float(index) * 1.37, forKey: "treeWindTime")
                    material.setValue(isWindEnabled ? Float(0.0035) * (1-descent) : 0,
                                      forKey: "treeWindAmplitude")
                }
                entry.canopy.childNode(withName: "radialBranches", recursively: false)?.opacity =
                    0
                let shadow = shadowRoot.childNodes[index]
                let reachX = abs(sin(trunk.eulerAngles.z)) * 0.36 * trunk.scale.y
                let reachZ = abs(sin(trunk.eulerAngles.x)) * 0.36 * trunk.scale.y
                let signX: Float = trunk.eulerAngles.z >= 0 ? 1 : -1
                let signZ: Float = trunk.eulerAngles.x >= 0 ? 1 : -1
                shadow.position.x = entry.origin.x + reachX * signX
                shadow.position.z = entry.origin.z + reachZ * signZ
                shadow.opacity = CGFloat(0.10 + descent * 0.12)
                shadow.scale.x = 0.8 + abs(sin(trunk.eulerAngles.z)) * 0.4
                shadow.scale.y = 0.8 + abs(sin(trunk.eulerAngles.x)) * 0.4

                entry.canopy.childNode(withName: "treeSilhouette", recursively: false)?
                    .geometry?.materials.last?.transparency = 0
                if fallT >= contactTime && !impactedTrees.contains(index) {
                    impactedTrees.insert(index)
                    if isWindEnabled { emitDust(at: shadow.position) }
                } else if fallT < 0.75 {
                    impactedTrees.remove(index)
                }
            }

            // ── 2. Fire / burning (ends before NGASEUK at timeline p ≈ 0.44) ─
            let fireT = smoothstep(0.27, 0.31, p) * (1 - smoothstep(0.38, 0.44, p))
            fireRoot.opacity = CGFloat(fireT)
            let flicker = 0.90 + 0.06 * sin(time * 4.1) + 0.04 * sin(time * 7.3)
            fireLight.intensity = CGFloat(fireT * flicker * 12)
            for system in flameSystems {
                // Let existing particles expire naturally. Resetting every
                // frame while fireT is zero causes a burst of work exactly
                // when the flame is first revealed and produces a hitch.
                system.birthRate = isWindEnabled ? CGFloat(fireT * 16) : 0
            }
            for ember in emberNodes {
                ember.node.opacity  = CGFloat(fireT * 0.18)
                ember.node.isHidden = fireT < 0.01
                // Oscillate position
                let phase = ember.phase
                ember.node.position = SCNVector3(
                    ember.baseX + sin(time * 2.1 + phase) * 0.015,
                    0.06 + abs(sin(time * 1.8 + phase)) * 0.12 * fireT,
                    ember.baseZ + cos(time * 1.5 + phase) * 0.015
                )
                // Warm emission pulse
                let emitG = Float(0.4 + 0.3 * abs(sin(time + phase)))
                ember.node.geometry?.firstMaterial?.emission.contents =
                    UIColor(red: 1.0, green: CGFloat(emitG), blue: 0, alpha: 1)
            }

            // ── 3. Ash clods (p 0.30 → 0.50) ───────────────────────────────
            let ashOpacity = smoothstep(0.34, 0.38, p) * (1 - smoothstep(0.42, 0.46, p))
            setVisibility(ashRoot, opacity: ashOpacity)

            // ── 4. Ground tint: soil → charred → back to soil ───────────────
            //   Charred peak at p ≈ 0.35, fading back to warm brown by 0.52
            if let groundMat = groundMaterial {
                let charredT = smoothstep(0.27, 0.31, p) * (1 - smoothstep(0.40, 0.46, p))
                let soilRGB  = SIMD3<Float>(1.0, 1.0, 1.0)         // white = no tint change
                let charRGB  = SIMD3<Float>(0.08 / 0.35, 0.05 / 0.20, 0.03 / 0.12)
                let mixed    = simd_mix(soilRGB, charRGB, SIMD3<Float>(repeating: charredT))
                groundMat.multiply.contents = UIColor(
                    red: CGFloat(mixed.x),
                    green: CGFloat(mixed.y),
                    blue: CGFloat(mixed.z),
                    alpha: 1)
            }

            // ── 5. Dibble holes appear at NGORED (p 0.82 → 0.89) ──────────
            // NGASEUK stays plain; the holes are revealed as NGORED begins.
            let plantingIn  = smoothstep(0.82, 0.89, p)
            let plantingOut = 1 - smoothstep(0.90, 0.98, p)
            setVisibility(plantingRoot, opacity: plantingIn * plantingOut)

            // ── 6. Seeds appear with the holes during NGORED ───────────────
            for (i, seedNode) in seedNodes.enumerated() {
                // Stagger each seed slightly
                let offset: Float = Float(i) * 0.012
                let seedIn  = smoothstep(0.82 + offset, 0.89 + offset, p)
                let seedOut = smoothstep(0.90 + offset, 0.98 + offset, p)
                let seedT   = max(0, seedIn - seedOut)
                let s       = CGFloat(max(0.001, seedT))
                seedNode.scale    = SCNVector3(s, s, s)
                seedNode.opacity  = CGFloat(seedT)
                seedNode.isHidden = seedT < 0.005
            }

            // ── 7. Rice blades emerge after NGORED (p 0.90 → 0.98) ────────
            // Scale from the planting point so the rice visibly grows out of
            // the hole instead of simply fading in at full size.
            let riceGrowth = smoothstep(0.90, 0.98, p)
            leavesRoot.scale = SCNVector3(riceGrowth, riceGrowth, riceGrowth)
            setVisibility(leavesRoot, opacity: riceGrowth)

            // ── 8. Panicles – DIBUAT only (p 0.94 → 1.0) ──────────────────
            let panicleGrowth = smoothstep(0.94, 1.0, p)
            paniclesRoot.scale = SCNVector3(panicleGrowth, panicleGrowth, panicleGrowth)
            setVisibility(paniclesRoot, opacity: panicleGrowth)

            // ── 9. Rice colour-lerp green → gold ────────────────────────────
            let green    = SIMD3<Float>(0.82, 0.94, 0.70)
            let gold     = SIMD3<Float>(1.00, 0.84, 0.34)
            let ripeness = smoothstep(0.94, 1.0, p)
            let mixed    = simd_mix(green, gold, SIMD3<Float>(repeating: ripeness))
            let tint     = UIColor(
                red: CGFloat(mixed.x),
                green: CGFloat(mixed.y),
                blue: CGFloat(mixed.z),
                alpha: 1)
            leafMaterials.forEach { $0.multiply.contents = tint }

            // ── 10. Final pan: harvest field → leuit ──────────────────────
            // The background is a SwiftUI image, so only the transparent
            // SceneKit layer moves. Keeping the camera target close to its
            // starting height preserves the horizon while the barn enters
            // from the right as a volumetric object.
            let panT = displayedCameraPan
            let leuitT = smoothstep(0.12, 0.92, panT)
            let cameraX = 0.60 * panT
            cameraNode.position = SCNVector3(cameraX, 0.52, 1.75)
            cameraNode.look(at: SCNVector3(cameraX * 0.82, 0.10, 0))
            // Give the detailed roof, woven walls, and ladder enough screen
            // space to read clearly in the final portrait scene.
            let leuitScale = 0.68 * (0.94 + 0.06 * leuitT)
            leuitRoot.scale = SCNVector3(leuitScale, leuitScale, leuitScale)
            setVisibility(leuitRoot, opacity: leuitT)
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Blade helpers
        // ════════════════════════════════════════════════════════════════════

        @discardableResult
        private func addBlade(
            to root: SCNNode,
            base: SCNVector3,
            height: Float,
            width: Float,
            yaw: Float,
            mass: CGFloat,
            response: Float,
            tint: UIColor,
            phase: Float
        ) -> SCNMaterial {
            let material = SCNMaterial()
            material.lightingModel    = .physicallyBased
            material.normal.contents = leafNormal
            material.normal.intensity = 0.08
            let albedoName = root === plantingRoot ? "HumaYoungRice" : "HumaGrassTexture"
            material.diffuse.contents = UIImage(named: albedoName) ?? tint
            // Preserve the authored AR albedo instead of flattening it with a
            // dark green shader and a strong multiply tint.
            material.multiply.contents = UIColor(white: 0.96, alpha: 1)
            material.emission.intensity = 0
            material.roughness.contents = 0.92
            material.metalness.contents = 0.0
            material.isDoubleSided      = true
            material.transparencyMode   = .aOne
            material.writesToDepthBuffer = true
            material.shaderModifiers = nil
            material.diffuse.wrapS      = .repeat
            material.diffuse.wrapT      = .clamp
            smoothTextureSampling(material.diffuse)

            let geometry = makeBladeGeometry(
                height: height,
                width: width,
                arch: height * (0.20 + response * 0.05),
                material: material
            )
            let pivot       = SCNNode(geometry: geometry)
            pivot.name      = "blade"
            pivot.position  = base
            pivot.eulerAngles.y = yaw
            root.addChildNode(pivot)

            let blade = Blade(
                pivot: pivot,
                root: root,
                phase: phase,
                response: response / Float(max(mass, 0.08)),
                restYaw: yaw
            )
            blades.append(blade)
            startBreeze(on: blade)
            return material
        }

        /// One keyed action owns each blade's wind sway.
        private func startBreeze(on blade: Blade) {
            guard isWindEnabled,
                  blade.pivot.action(forKey: Self.windActionKey) == nil else { return }
            let amplitude  = CGFloat(min(0.065, 0.035 + blade.response * 0.004))
            let halfPeriod = 2.8 + Double(blade.phase.truncatingRemainder(dividingBy: 1.4))
            let direction: CGFloat = sin(blade.phase) >= 0 ? 1 : -1

            func lean(_ amount: CGFloat, duration: TimeInterval) -> SCNAction {
                let a = SCNAction.rotateTo(
                    x: amount * 0.25,
                    y: CGFloat(blade.restYaw),
                    z: amount,
                    duration: duration,
                    usesShortestUnitArc: true)
                a.timingMode = .easeInEaseOut
                return a
            }
            let loop = SCNAction.sequence([
                lean(-amplitude * direction, duration: halfPeriod),
                lean( amplitude * direction, duration: halfPeriod)
            ])
            blade.pivot.runAction(.sequence([
                lean(amplitude * direction, duration: halfPeriod / 2),
                .repeatForever(loop)
            ]), forKey: Self.windActionKey)
        }

        private func makeBladeGeometry(
            height: Float,
            width: Float,
            arch: Float,
            material: SCNMaterial
        ) -> SCNGeometry {
            let segments = 24
            var vertices:           [SCNVector3] = []
            var normals:            [SCNVector3] = []
            var textureCoordinates: [CGPoint]    = []
            var indices:            [UInt32]     = []

            for segment in 0...segments {
                let t        = Float(segment) / Float(segments)
                let taper    = max(0.08, sin(t * .pi) * (1 - t * 0.42))
                let halfWidth = width * 0.5 * taper
                let y        = height * (t - 0.08 * t * t)
                let z        = arch * t * t
                vertices.append(SCNVector3(-halfWidth, y, z))
                vertices.append(SCNVector3( halfWidth, y, z))
                let normal = simd_normalize(SIMD3<Float>(0, -2 * arch * t, height * (1 - 0.16 * t)))
                normals.append(SCNVector3(normal))
                normals.append(SCNVector3(normal))
                textureCoordinates.append(CGPoint(x: 0, y: CGFloat(t)))
                textureCoordinates.append(CGPoint(x: 1, y: CGFloat(t)))
                if segment < segments {
                    let base: UInt32 = UInt32(segment * 2)
                    indices += [base, base+1, base+2, base+1, base+3, base+2]
                }
            }

            let geometry = SCNGeometry(
                sources: [
                    SCNGeometrySource(vertices: vertices),
                    SCNGeometrySource(normals: normals),
                    SCNGeometrySource(textureCoordinates: textureCoordinates)
                ],
                elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
            )
            geometry.materials = [material]
            return geometry
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Utilities
        // ════════════════════════════════════════════════════════════════════

        // A cheap artistic approximation of leaf transmission, not full SSS.
        // View-space normals give a soft rim; emission remains deliberately low.
        private let leafTransmissionBody = """
        float rim = pow(1.0 - abs(normalize(_surface.normal).z), 2.0);
        _surface.emission.rgb += float3(0.12, 0.16, 0.035) * rim;
        """
        private var leafTransmission: String {
            "#pragma body\n" + leafTransmissionBody
        }

        // Generated once per scene. These are subtle tangent-space detail maps,
        // not claimed to be scanned normals matched to the supplied albedo.
        private lazy var barkNormal = makeDetailNormal(frequency: 12, strength: 0.32)
        private lazy var leafNormal = makeDetailNormal(frequency: 22, strength: 0.12)

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
            let image = CGImage(width: size, height: size, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
            return UIImage(cgImage: image)
        }

        private lazy var particleSprite: UIImage = {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { context in
                let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
                context.cgContext.drawRadialGradient(gradient,
                    startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                    endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
            }
        }()

        private func makeFlames() -> SCNParticleSystem {
            let system = SCNParticleSystem()
            system.birthRate = 0
            system.particleLifeSpan = 0.62
            system.particleLifeSpanVariation = 0.12
            system.particleSize = 0.038
            system.particleSizeVariation = 0.012
            system.particleVelocity = 0.12
            system.particleVelocityVariation = 0.03
            system.emittingDirection = SCNVector3(0, 1, 0)
            system.spreadingAngle = 15
            system.acceleration = SCNVector3(0.015, 0.06, 0)
            system.emitterShape = SCNSphere(radius: 0.018)
            system.particleImage = particleSprite
            system.blendMode = .additive
            system.isLightingEnabled = false
            let color = CAKeyframeAnimation()
            color.values = [UIColor(red: 1, green: 0.95, blue: 0.55, alpha: 0.8),
                            UIColor(red: 1, green: 0.48, blue: 0.04, alpha: 0.6),
                            UIColor(red: 0.45, green: 0.06, blue: 0, alpha: 0)]
            color.keyTimes = [0, 0.35, 1]
            system.propertyControllers = [.color: SCNParticlePropertyController(animation: color)]
            return system
        }

        private func emitDust(at position: SCNVector3) {
            let node = SCNNode()
            node.position = position
            let dust = SCNParticleSystem()
            dust.loops = false
            dust.emissionDuration = 0.1
            dust.birthRate = 160
            dust.particleLifeSpan = 0.65
            dust.particleSize = 0.018
            dust.particleVelocity = 0.10
            dust.spreadingAngle = 80
            dust.emittingDirection = SCNVector3(0, 1, 0)
            dust.particleColor = UIColor(red: 0.45, green: 0.33, blue: 0.20, alpha: 0.35)
            dust.particleImage = particleSprite
            dust.blendMode = .alpha
            let fade = CABasicAnimation()
            fade.fromValue = 0.35
            fade.toValue = 0
            dust.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]
            node.addParticleSystem(dust)
            scene.rootNode.addChildNode(node)
            node.runAction(.sequence([.wait(duration: 1.2), .removeFromParentNode()]))
        }

        private func smoothTextureSampling(_ property: SCNMaterialProperty) {
            property.minificationFilter  = .linear
            property.magnificationFilter = .linear
            property.mipFilter           = .linear
            property.maxAnisotropy       = 8
        }

        private func setVisibility(_ node: SCNNode, opacity: Float) {
            node.opacity  = CGFloat(max(0, min(1, opacity)))
            node.isHidden = opacity < 0.005
        }

        private func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
            let t = max(0, min(1, (value - edge0) / (edge1 - edge0)))
            return t * t * (3 - 2 * t)
        }
    }
}
