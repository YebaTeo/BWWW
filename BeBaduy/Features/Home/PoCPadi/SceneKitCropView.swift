// SceneKitCropView.swift
// BeBaduy – Kanekes traditional rice-farming ceremony visualiser
//
// 5-stage cinematic scene driven by a single progress: CGFloat (0 → 1)
//   Stage 1  NUKUH   p 0.000 – 0.333  Dense wild forest
//   Transition 1→2   p 0.100 – 0.333  Trees fall & burn
//   Stage 2  NGASEUK p 0.333 – 0.666  Cleared, plain soil
//   Stage 3  NGORED  p 0.666 – 0.750  Dibble holes and seeds
//   Stage 4  DIBUAT  p 0.666 – 0.750  Golden panicles / harvest
//   Stage 5  LEUIT   p 0.750 – 1.000  Bamboo rack rises; harvested rice hangs

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
        /// Stage-5: bamboo drying rack and harvested rice bundles.
        private let leuitRoot    = SCNNode()
        private var rackPosts: [SCNNode] = []
        private var rackBraces: [SCNNode] = []
        private let rackBeam = SCNNode()
        private var hangingBundles: [SCNNode] = []
        private let rackShadowRoot = SCNNode()
        private var rackPostShadows: [SCNNode] = []
        private var rackPostContactShadows: [SCNNode] = []
        private let rackBeamShadow = SCNNode()
        private var rackBundleShadows: [SCNNode] = []
        private var harvestTransferNodes: [(
            node: SCNNode,
            target: SCNNode,
            startPosition: SIMD3<Float>,
            startOrientation: simd_quatf,
            startScale: SIMD3<Float>,
            delay: Float
        )] = []

        /// The camera stays centered as the final bamboo rack rises.
        private let cameraNode   = SCNNode()

        // ── Per-tree state ───────────────────────────────────────────────────
        /// (trunk node, canopy node, directional shadow, natural fall-start offset in [0,1])
        private var treeNodes: [(trunk: SCNNode, canopy: SCNNode, shadow: SCNNode, fallAngle: Float, origin: SCNVector3)] = []
        private var impactedTrees = Set<Int>()
        private var crackedTrees = Set<Int>()
        private var fracturePairs: [(base: SCNNode, falling: SCNNode)] = []
        private let stumpRoot = SCNNode()
        private let rootFlareRoot = SCNNode()
        private var flameSystems: [SCNParticleSystem] = []
        private var sparkSystems: [SCNParticleSystem] = []
        private var smokeSystems: [SCNParticleSystem] = []
        private var groundGlowNodes: [SCNNode] = []
        private let fireLight = SCNLight()
        private let sunKeyLight = SCNLight()
        private let skyAmbientLight = SCNLight()
        private let warmFillLight = SCNLight()
        private let sunsetRimLight = SCNLight()
        private let moonLight = SCNLight()
        private let sunOrbitNode = SCNNode()
        private let moonOrbitNode = SCNNode()
        private let animationEpoch = CACurrentMediaTime()

        // ── Ember / seed nodes ───────────────────────────────────────────────
        private var emberNodes: [(node: SCNNode, baseX: Float, baseZ: Float, phase: Float)] = []
        private var seedNodes:  [SCNNode] = []

        // ── Blade / material arrays ──────────────────────────────────────────
        private var blades:        [Blade]       = []
        private var leafMaterials: [SCNMaterial] = []
        private var panicleMaterials: [SCNMaterial] = []

        // ── Ground material (tinted dynamically) ─────────────────────────────
        private var groundMaterial: SCNMaterial?
        private var targetProgress: CGFloat = 0
        private var displayedProgress: CGFloat = 0
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
            rootFlareRoot.name = "rootFlares"
            scene.rootNode.addChildNode(rootFlareRoot)
            buildWildGrass()     // Stage 1 undergrowth
            buildFire()          // Transition 1→2
            buildAsh()           // Post-burn clods
            buildPlantingStage() // Stage 2
            buildRicePlant()     // Stage 3 + 4
            buildLeuitRack()     // Stage 5
            configureObjectShadows()
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
            moonLight.type = .directional
            moonLight.color = UIColor(red: 0.42, green: 0.62, blue: 1.0, alpha: 1)
            moonLight.intensity = 0
            moonLight.castsShadow = true
            moonLight.shadowMode = .deferred
            moonLight.shadowMapSize = CGSize(width: 2048, height: 2048)
            moonLight.orthographicScale = 4
            moonLight.shadowSampleCount = 8
            moonLight.shadowRadius = 3
            moonLight.shadowBias = 0.003
            moonLight.shadowColor = UIColor(white: 0, alpha: 0.65)
            let moonNode = moonOrbitNode
            moonNode.light = moonLight
            moonNode.position = SCNVector3(2.5, 3, 1.5)
            moonNode.look(at: SCNVector3(0, 0.1, 0))
            scene.rootNode.addChildNode(moonNode)

            // Key – warm Kanekes sunset directional
            let sun           = sunKeyLight
            sun.type          = .directional
            sun.color         = UIColor(red: 1.0, green: 0.88, blue: 0.70, alpha: 1)
            sun.intensity     = 155
            sun.castsShadow   = true
            sun.shadowMode    = .forward
            sun.shadowRadius  = 2.5
            sun.orthographicScale = 3.6
            sun.shadowSampleCount = 8
            sun.shadowBias = 0.002
            sun.shadowMapSize = CGSize(width: 2048, height: 2048)
            sun.shadowColor   = UIColor(white: 0.02, alpha: 0.70)
            let sunNode       = sunOrbitNode
            sunNode.light     = sun
            sunNode.position  = SCNVector3(2.6, 3.2, -2.4)
            sunNode.look(at: SCNVector3(0, 0.1, 0))
            scene.rootNode.addChildNode(sunNode)

            // Fill – cool sky ambient
            let ambient       = skyAmbientLight
            ambient.type      = .ambient
            ambient.color     = UIColor(red: 0.88, green: 0.82, blue: 0.70, alpha: 1)
            ambient.intensity = 230
            let ambientNode   = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            // Rim – back-light
            let rim           = sunsetRimLight
            rim.type          = .omni
            rim.color         = UIColor(red: 1.0, green: 0.87, blue: 0.68, alpha: 1)
            rim.intensity     = 18
            rim.attenuationStartDistance = 0.3
            rim.attenuationEndDistance   = 2.2
            let rimNode       = SCNNode()
            rimNode.light     = rim
            rimNode.position  = SCNVector3(0.65, 0.72, -0.65)
            scene.rootNode.addChildNode(rimNode)

            // Broad reflected fill on the viewer-facing trunk and crown.
            // Its energy follows the celestial lights without a second shadow.
            let fill = warmFillLight
            fill.type = .omni
            fill.color = UIColor(red: 1.0, green: 0.94, blue: 0.86, alpha: 1)
            fill.intensity = 0
            fill.castsShadow = false
            fill.attenuationStartDistance = 1.5
            fill.attenuationEndDistance = 5
            let fillNode = SCNNode()
            fillNode.light = fill
            fillNode.position = SCNVector3(0, 0.70, 1.1)
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
            let receiverGeometry = SCNPlane(width: 8, height: 8)
            receiverGeometry.materials = [receiverMaterial]
            let receiver = SCNNode(geometry: receiverGeometry)
            receiver.name = "soilShadowReceiver"
            receiver.position.y = soilY
            receiver.eulerAngles.x = -.pi / 2
            receiver.castsShadow = false
            scene.rootNode.addChildNode(receiver)
        }

        private func configureObjectShadows() {
            // Include the entire farming sequence, including cloned harvest
            // bundles. Preserve explicit exclusions for painted contact shadows.
            for root in [forestRoot, rootFlareRoot, stumpRoot, wildRoot,
                         plantingRoot, leavesRoot, paniclesRoot, ashRoot, leuitRoot] {
                root.enumerateChildNodes { node, _ in
                    guard node.geometry != nil else { return }
                    if node.name?.contains("Shadow") == true || node.name?.contains("shadow") == true {
                        node.castsShadow = false
                        return
                    }
                    node.castsShadow = true
                    node.geometry?.materials.forEach { $0.readsFromDepthBuffer = true }
                }
            }
            fireRoot.enumerateChildNodes { node, _ in node.castsShadow = false }
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Stage 1 – Forest (p 0.00 → 0.33)
        // ════════════════════════════════════════════════════════════════════

        private func buildForest() {
            forestRoot.name = "forest"
            scene.rootNode.addChildNode(forestRoot)
            shadowRoot.name = "treeShadows"
            shadowRoot.renderingOrder = -2
            scene.rootNode.addChildNode(shadowRoot)

            // Deliberately irregular placement: varied depth, scale and yaw
            // keep the forest from reading as a repeated row of clones.
            scene.rootNode.addChildNode(stumpRoot)
            let placements: [(x: Float, z: Float, yaw: Float, scale: Float)] = [
                (-0.34, -0.15, -0.12, 1.10),
                ( 0.27, -0.20,  0.16, 1.50),
                (-0.10,  0.03, -0.08, 1.32),
                ( 0.36,  0.10,  0.11, 1.02),
                (-0.28,  0.22, -0.18, 1.68)
            ]
            for (i, placement) in placements.enumerated() {
                addTexturedTree(index: i, x: placement.x, z: placement.z,
                                yaw: placement.yaw, scale: placement.scale)
            }
        }

        // All rooted objects share this surface, including their contact shadows.
        private let soilY: Float = 0.038
        private let riceSoilRoot = SCNNode()

        private func addTexturedTree(index: Int, x: Float, z: Float,
                                     yaw: Float, scale: Float) {
            let pivot = SCNNode()
            pivot.name = "treeCutPivot_\(index)"
            let cutHeight: Float = 0.075 // six of forty mesh rows; bottom 15% stays rooted
            let imageBase: Float = -0.035 * scale
            pivot.position = SCNVector3(x, soilY + (imageBase + cutHeight) * scale, z)
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
            // Sink the root flare into the shared ground plane. The artwork
            // includes roots below the trunk; leaving it at local zero makes
            // the enlarged tree read as if it sits on top of a separate disk.
            canopy.position.y = -cutHeight
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

            // Unified directional tree shadow cast behind the object (dibelakang objek)
            let shadowYaw: Float = atan2(-2.6, 2.4)
            let dirShadowRoot = SCNNode()
            dirShadowRoot.name = "treeDirectionalShadow_\(index)"
            dirShadowRoot.position = SCNVector3(x, soilY + 0.0003, z)
            dirShadowRoot.eulerAngles.y = shadowYaw
            dirShadowRoot.renderingOrder = -2
            dirShadowRoot.castsShadow = false

            // Soft, blurred directional tree shadow cast behind the object (dibelakang objek)
            let shadowMat = SCNMaterial()
            shadowMat.lightingModel = .constant
            shadowMat.diffuse.contents = UIColor(red: 0.12, green: 0.08, blue: 0.05, alpha: 1)
            shadowMat.isDoubleSided = true
            shadowMat.writesToDepthBuffer = false
            shadowMat.shaderModifiers = [.fragment: """
            #pragma transparent
            #pragma body
            float2 uv = _surface.diffuseTexcoord;
            // Teardrop profile: gently wider at the canopy and tapered at trunk base
            float widthScale = 0.50 + 0.50 * (1.0 - uv.y);
            float dx = abs(uv.x - 0.5) * 2.0 / widthScale;
            float dy = (uv.y - 0.5) * 2.0;
            float r = sqrt(dx * dx + dy * dy);
            // Ultra-soft quadratic bell-curve falloff for natural diffuse blur
            float blur = max(0.0, 1.0 - r);
            _output.color.a *= blur * blur * 0.25;
            """]
            let shadowGeo = SCNPlane(width: CGFloat(0.26 * scale), height: CGFloat(0.34 * scale))
            shadowGeo.materials = [shadowMat]
            let shadowNode = SCNNode(geometry: shadowGeo)
            shadowNode.eulerAngles.x = -.pi / 2
            shadowNode.position = SCNVector3(0, 0.0001, -0.15 * scale)
            shadowNode.castsShadow = false
            dirShadowRoot.addChildNode(shadowNode)
            shadowRoot.addChildNode(dirShadowRoot)

            // The original image's root flare stays planted as the upper
            // tree rotates away. Its opacity follows the cut/fall progress.
            let rootAnchor = SCNNode()
            rootAnchor.position = SCNVector3(x, soilY + (imageBase + cutHeight * 0.5) * scale, z)
            rootAnchor.scale = SCNVector3(scale, scale, scale)
            rootAnchor.eulerAngles.y = yaw
            let rootMaterial = SCNMaterial()
            rootMaterial.lightingModel = .constant
            rootMaterial.diffuse.contents = Self.rootFlareTexture
            rootMaterial.multiply.contents = UIColor(red: 1.48, green: 1.45, blue: 1.38, alpha: 1)
            rootMaterial.isDoubleSided = true
            rootMaterial.transparencyMode = .aOne
            rootMaterial.writesToDepthBuffer = false
            let rootPlane = SCNPlane(width: 0.34, height: CGFloat(cutHeight))
            rootPlane.materials = [rootMaterial]
            let rootImage = SCNNode(geometry: rootPlane)
            rootImage.position.z = 0
            rootAnchor.addChildNode(rootImage)
            rootAnchor.opacity = 1
            rootAnchor.isHidden = false
            rootFlareRoot.addChildNode(rootAnchor)

            let baseFracture = makeFractureSurface(seed: index)
            baseFracture.position.y = cutHeight * 0.5
            rootAnchor.addChildNode(baseFracture)
            let fallingFracture = makeFractureSurface(seed: index)
            fallingFracture.eulerAngles.z = .pi
            pivot.addChildNode(fallingFracture)
            baseFracture.opacity = 0
            fallingFracture.opacity = 0
            fracturePairs.append((baseFracture, fallingFracture))

            forestRoot.addChildNode(pivot)
            treeNodes.append((
                trunk: pivot,
                canopy: canopy,
                shadow: dirShadowRoot,
                fallAngle: Float(index) / 4,
                origin: pivot.position
            ))
        }

        /// One shared mesh: original full-resolution artwork on the front,
        /// with a closed body derived from its alpha mask. Sampling is used
        /// only to construct geometry; the bundled image remains untouched.
        private static let rootFlareTexture: UIImage = {
            guard let image = UIImage(named: "HumaTreeNatural") ?? UIImage(named: "HumaTree"),
                  let cg = image.cgImage else { return UIImage() }
            // Exact complement of the moving mesh: full width, bottom 15%.
            let bounds = CGRect(x: 0, y: CGFloat(cg.height) * 0.85,
                                width: CGFloat(cg.width), height: CGFloat(cg.height) * 0.15)
            guard let crop = cg.cropping(to: bounds) else { return image }
            return UIImage(cgImage: crop, scale: image.scale, orientation: image.imageOrientation)
        }()

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
            for row in 6..<40 {
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
            for y in 29..<size {
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
            front.multiply.contents = UIColor(red: 1.48, green: 1.45, blue: 1.38, alpha: 1)
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
            float rootSeparation;
            #pragma transparent
            #pragma body
            // Keep the original trunk visible at the cut pivot while the
            // crown dissolves into the radial 3D leaf structure.
            float crownMask = 1.0 - smoothstep(0.42, 0.55,
                _surface.diffuseTexcoord.y);
            _output.color.a *= 1.0 - treeCrownBlend * crownMask;
            float rootMask = smoothstep(0.94, 0.985, _surface.diffuseTexcoord.y);
            // Root pixels are excluded from this mesh at construction time.
            if (_output.color.a < 0.08) { discard_fragment(); }
            """]
            front.setValue(Float(0), forKey: "treeWindTime")
            front.setValue(Float(0), forKey: "treeWindAmplitude")
            front.setValue(Float(0), forKey: "treeCrownBlend")
            front.setValue(Float(0), forKey: "rootSeparation")
            smoothTextureSampling(front.diffuse)
            let body = front.copy() as! SCNMaterial
            body.lightingModel = .constant
            body.multiply.contents = UIColor(red: 1.15, green: 1.12, blue: 1.05, alpha: 1)
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

        /// A shallow, irregular soil lip fixed to the ground.
        private func addRootContact(to parent: SCNNode, x: Float, z: Float, radius: Float) {
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
            material.lightingModel = .constant
            material.diffuse.contents = UIImage(named: "HumaWoodTexture")
                ?? UIColor(red: 0.32, green: 0.20, blue: 0.12, alpha: 1)
            material.multiply.contents = UIColor(red: 1.25, green: 1.10, blue: 0.95, alpha: 1)
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
            fireLight.color = UIColor(red: 1.0, green: 0.48, blue: 0.12, alpha: 1)
            fireLight.intensity = 0
            fireLight.attenuationStartDistance = 0.12
            fireLight.attenuationEndDistance = 2.4
            let glow = SCNNode()
            glow.light = fireLight
            glow.position = SCNVector3(0, 0.15, 0)
            fireRoot.addChildNode(glow)

            let emberGlowTexture = NgahumaMaterials.makeEmberGlowSprite()

            // Tree coordinates matching buildForest():
            let placements: [(x: Float, z: Float, scale: Float)] = [
                (-0.34, -0.15, 1.10),
                ( 0.27, -0.20, 1.50),
                (-0.10,  0.03, 1.32),
                ( 0.36,  0.10, 1.02),
                (-0.28,  0.22, 1.68)
            ]

            for (treeIdx, p) in placements.enumerated() {
                let patchAngle = atan2(p.x, -p.z)

                // 0. Soft incandescent ground ember glow disk beneath each burning tree
                let emberPlane = SCNPlane(width: CGFloat(0.38 * p.scale), height: CGFloat(0.38 * p.scale))
                let emberMat = SCNMaterial()
                emberMat.lightingModel = .constant
                emberMat.diffuse.contents = emberGlowTexture
                emberMat.blendMode = .add
                emberMat.writesToDepthBuffer = false
                emberMat.isDoubleSided = true
                emberPlane.materials = [emberMat]

                let emberNode = SCNNode(geometry: emberPlane)
                emberNode.name = "homeGroundEmberGlow_\(treeIdx)"
                emberNode.eulerAngles.x = -.pi / 2
                emberNode.position = SCNVector3(p.x, soilY + 0.002, p.z)
                emberNode.opacity = 0
                emberNode.isHidden = true
                emberNode.renderingOrder = 22
                emberNode.castsShadow = false
                fireRoot.addChildNode(emberNode)
                groundGlowNodes.append(emberNode)

                // 1. Four 3D perimeter flame emitters encircling the OUTSIDE of the trunk bark
                let baseRadius = 0.054 * p.scale
                let perimeterOffsets: [(x: Float, z: Float)] = [
                    ( baseRadius,  0),
                    (-baseRadius,  0),
                    ( 0,  baseRadius),
                    ( 0, -baseRadius)
                ]
                for (pIdx, offset) in perimeterOffsets.enumerated() {
                    let pNode = SCNNode()
                    pNode.name = "homeFlamePerimeter_\(treeIdx)_\(pIdx)"
                    pNode.position = SCNVector3(p.x + offset.x, soilY + 0.014, p.z + offset.z)
                    pNode.renderingOrder = 25
                    let flames = makeFlames()
                    pNode.addParticleSystem(flames)
                    fireRoot.addChildNode(pNode)
                    flameSystems.append(flames)
                }

                // 2. Stump top fracture flame emitter (bursting up from the cut wood cross-section)
                let cutHeight: Float = 0.075
                let fractureNode = SCNNode()
                fractureNode.name = "homeFlameFracture_\(treeIdx)"
                fractureNode.position = SCNVector3(p.x, soilY + cutHeight * p.scale, p.z)
                fractureNode.renderingOrder = 26
                let fractureFlames = makeFlames()
                fractureFlames.particleSize = 0.13
                fractureFlames.emitterShape = SCNBox(width: 0.05, height: 0.008, length: 0.05, chamferRadius: 0)
                fractureNode.addParticleSystem(fractureFlames)
                fireRoot.addChildNode(fractureNode)
                flameSystems.append(fractureFlames)

                // 3. Surrounding ground brushfire emitters (radiating in the grass around the tree)
                let groundOffsets: [(x: Float, z: Float)] = [
                    ( sin(patchAngle + 0.75) * 0.13 * p.scale, -cos(patchAngle + 0.75) * 0.13 * p.scale),
                    ( sin(patchAngle - 0.85) * 0.17 * p.scale, -cos(patchAngle - 0.85) * 0.17 * p.scale)
                ]
                for (gIdx, gOffset) in groundOffsets.enumerated() {
                    let gNode = SCNNode()
                    gNode.name = "homeFlameGround_\(treeIdx)_\(gIdx)"
                    gNode.position = SCNVector3(p.x + gOffset.x, soilY + 0.010, p.z + gOffset.z)
                    gNode.renderingOrder = 24
                    let gFlames = makeFlames()
                    gFlames.particleSize = 0.14
                    gFlames.emitterShape = SCNBox(width: 0.08, height: 0.008, length: 0.08, chamferRadius: 0)
                    gNode.addParticleSystem(gFlames)
                    fireRoot.addChildNode(gNode)
                    flameSystems.append(gFlames)
                }

                // 4. Upward swirling sparks and thermal smoke plume
                let atmosphereNode = SCNNode()
                atmosphereNode.position = SCNVector3(p.x, soilY + 0.035, p.z)
                let sparks = NgahumaMaterials.makeFireSparks(sprite: particleSprite, scale: 0.62)
                sparks.emitterShape = SCNBox(width: 0.14, height: 0.015, length: 0.14, chamferRadius: 0)
                let smoke = makeSmoke()
                atmosphereNode.addParticleSystem(sparks)
                atmosphereNode.addParticleSystem(smoke)
                fireRoot.addChildNode(atmosphereNode)
                sparkSystems.append(sparks)
                smokeSystems.append(smoke)
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
                let mat    = addRicePanicle(
                    to: paniclesRoot,
                    base: SCNVector3(cos(angle) * 0.025, 0.038, sin(angle) * 0.025),
                    height: 0.46 + Float(index % 4) * 0.022,
                    yaw: angle,
                    mass: 0.52,
                    response: 0.48,
                    phase: Float(index) * 0.47
                )
                panicleMaterials.append(mat)
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // MARK: Stage 5 – Harvested rice on a bamboo rack
        // ════════════════════════════════════════════════════════════════════

        /// The field's golden rice becomes three bound sheaves. Posts rise
        /// from the soil, the crossbar opens, then the sheaves settle below it.
        private func buildLeuitRack() {
            leuitRoot.name = "leuitRiceRack"
            leuitRoot.position = SCNVector3(0, soilY, -0.10)
            leuitRoot.scale = SCNVector3(0.88, 0.88, 0.88)
            leuitRoot.opacity = 0
            leuitRoot.isHidden = true
            scene.rootNode.addChildNode(leuitRoot)

            let bamboo = SCNMaterial()
            bamboo.lightingModel = .physicallyBased
            bamboo.diffuse.contents = UIColor(red: 0.86, green: 0.58, blue: 0.20, alpha: 1)
            bamboo.roughness.contents = 0.86
            bamboo.metalness.contents = 0

            let joint = bamboo.copy() as! SCNMaterial
            joint.diffuse.contents = UIColor(red: 0.66, green: 0.39, blue: 0.12, alpha: 1)

            let tieMaterial = SCNMaterial()
            tieMaterial.lightingModel = .physicallyBased
            tieMaterial.diffuse.contents = UIColor(red: 0.94, green: 0.84, blue: 0.57, alpha: 1)
            tieMaterial.roughness.contents = 1

            let postHeight: Float = 0.62
            for x: Float in [-0.245, 0.245] {
                let postGeometry = SCNCylinder(radius: 0.016, height: CGFloat(postHeight))
                postGeometry.radialSegmentCount = 12
                postGeometry.materials = [bamboo]
                let post = SCNNode(geometry: postGeometry)
                post.name = x < 0 ? "leftBambooPost" : "rightBambooPost"
                post.position = SCNVector3(x, postHeight * 0.5, 0)
                leuitRoot.addChildNode(post)
                rackPosts.append(post)

                // Raised rings make the poles read as segmented bamboo.
                for y: Float in [-0.20, -0.04, 0.12, 0.28] {
                    let ringGeometry = SCNCylinder(radius: 0.018, height: 0.009)
                    ringGeometry.radialSegmentCount = 12
                    ringGeometry.materials = [joint]
                    let ring = SCNNode(geometry: ringGeometry)
                    ring.position.y = y
                    post.addChildNode(ring)
                }
            }

            let beamGeometry = SCNCylinder(radius: 0.020, height: 0.55)
            beamGeometry.radialSegmentCount = 12
            beamGeometry.materials = [bamboo]
            rackBeam.name = "bambooCrossbar"
            rackBeam.geometry = beamGeometry
            rackBeam.eulerAngles.z = .pi / 2
            rackBeam.position.y = postHeight
            leuitRoot.addChildNode(rackBeam)
            for side: Float in [-1, 1] {
                let brace = branch(
                    from: SIMD3<Float>(side * 0.245, 0.43, 0),
                    to: SIMD3<Float>(side * 0.15, postHeight, 0),
                    radius: 0.009,
                    material: bamboo
                )
                brace.name = side < 0 ? "leftBambooBrace" : "rightBambooBrace"
                leuitRoot.addChildNode(brace)
                rackBraces.append(brace)
            }
            let harvestedPanicles = paniclesRoot.childNodes.filter { $0.geometry != nil }
            for x: Float in [-0.15, 0, 0.15] {
                let bundleIndex = hangingBundles.count
                let bundle = makeHangingRiceBundle(from: harvestedPanicles, tie: tieMaterial)
                bundle.name = "hangingRiceBundle_\(bundleIndex)"
                bundle.position = SCNVector3(x, postHeight, 0.025)
                leuitRoot.addChildNode(bundle)
                hangingBundles.append(bundle)
            }

            // Temporary harvested stalks travel from the ripe field into the
            // exact positions of the final tied sheaves. The mature crop and
            // these copies overlap at the start, so the handoff reads as one
            // continuous harvest instead of a sudden replacement.
            for (index, source) in harvestedPanicles.enumerated() {
                guard source.geometry != nil, !hangingBundles.isEmpty else { continue }
                let bundleIndex = index % hangingBundles.count
                let targetIndex = harvestedPanicles.count + index
                guard hangingBundles[bundleIndex].childNodes.indices.contains(targetIndex) else { continue }
                let target = hangingBundles[bundleIndex].childNodes[targetIndex]
                let movingStalk = SCNNode(geometry: source.geometry)
                movingStalk.name = "harvestTransfer_\(index)"
                movingStalk.simdWorldPosition = source.simdWorldPosition
                movingStalk.simdWorldOrientation = source.simdWorldOrientation
                movingStalk.simdScale = source.simdScale
                movingStalk.opacity = 0
                movingStalk.isHidden = true
                scene.rootNode.addChildNode(movingStalk)
                harvestTransferNodes.append((
                    node: movingStalk,
                    target: target,
                    startPosition: source.simdWorldPosition,
                    startOrientation: source.simdWorldOrientation,
                    startScale: source.simdScale,
                    delay: Float(index % 4) * 0.045
                ))
            }
            buildRackDirectionalShadows()
        }

        private func buildRackDirectionalShadows() {
            rackShadowRoot.name = "rackDirectionalShadows"
            rackShadowRoot.renderingOrder = -2
            rackShadowRoot.castsShadow = false
            leuitRoot.addChildNode(rackShadowRoot)

            // 1. Post contact shadow material (deep dark occlusion at ground entrance)
            let contactShadowMat = SCNMaterial()
            contactShadowMat.lightingModel = .constant
            contactShadowMat.diffuse.contents = UIColor(red: 0.04, green: 0.02, blue: 0.01, alpha: 1)
            contactShadowMat.isDoubleSided = true
            contactShadowMat.writesToDepthBuffer = false
            contactShadowMat.shaderModifiers = [.fragment: """
            #pragma transparent
            #pragma body
            float2 d = (_surface.diffuseTexcoord - float2(0.5)) * 2.0;
            float r = length(d);
            _output.color.a *= (1.0 - smoothstep(0.35, 1.0, r)) * 0.88;
            """]

            // 2. Directional post shadow material (thick, elongated shadow extending forward)
            let postShadowMat = SCNMaterial()
            postShadowMat.lightingModel = .constant
            postShadowMat.diffuse.contents = UIColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 1)
            postShadowMat.isDoubleSided = true
            postShadowMat.writesToDepthBuffer = false
            postShadowMat.shaderModifiers = [.fragment: """
            #pragma transparent
            #pragma body
            float dx = abs(_surface.diffuseTexcoord.x - 0.5) * 2.0;
            float dy = abs(_surface.diffuseTexcoord.y - 0.5) * 2.0;
            float edgeX = 1.0 - smoothstep(0.35, 1.0, dx);
            float edgeY = 1.0 - smoothstep(0.85, 1.0, dy);
            _output.color.a *= edgeX * edgeY * 0.82;
            """]

            // 3. Directional crossbar shadow material (solid horizontal stroke)
            let beamShadowMat = SCNMaterial()
            beamShadowMat.lightingModel = .constant
            beamShadowMat.diffuse.contents = UIColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 1)
            beamShadowMat.isDoubleSided = true
            beamShadowMat.writesToDepthBuffer = false
            beamShadowMat.shaderModifiers = [.fragment: """
            #pragma transparent
            #pragma body
            float dx = abs(_surface.diffuseTexcoord.x - 0.5) * 2.0;
            float dy = abs(_surface.diffuseTexcoord.y - 0.5) * 2.0;
            float edgeX = 1.0 - smoothstep(0.88, 1.0, dx);
            float edgeY = 1.0 - smoothstep(0.35, 1.0, dy);
            _output.color.a *= edgeX * edgeY * 0.78;
            """]

            // 4. Directional rice bundle shadow material (rich teardrop-shaped sheaf silhouettes)
            let bundleShadowMat = SCNMaterial()
            bundleShadowMat.lightingModel = .constant
            bundleShadowMat.diffuse.contents = UIColor(red: 0.06, green: 0.04, blue: 0.02, alpha: 1)
            bundleShadowMat.isDoubleSided = true
            bundleShadowMat.writesToDepthBuffer = false
            bundleShadowMat.shaderModifiers = [.fragment: """
            #pragma transparent
            #pragma body
            float2 uv = _surface.diffuseTexcoord;
            float widthScale = 0.52 + 0.48 * uv.y;
            float dx = abs(uv.x - 0.5) * 2.0 / widthScale;
            float dy = abs(uv.y - 0.5) * 2.0;
            float r = sqrt(dx * dx + dy * dy);
            _output.color.a *= (1.0 - smoothstep(0.40, 1.0, r)) * 0.75;
            """]

            // Build Post Shadows (Left & Right)
            for x: Float in [-0.245, 0.245] {
                let contactGeo = SCNPlane(width: 0.075, height: 0.065)
                contactGeo.materials = [contactShadowMat]
                let contactNode = SCNNode(geometry: contactGeo)
                contactNode.name = x < 0 ? "leftPostContactShadow" : "rightPostContactShadow"
                contactNode.eulerAngles.x = -.pi / 2
                contactNode.position = SCNVector3(x, 0.0004, 0)
                contactNode.castsShadow = false
                rackShadowRoot.addChildNode(contactNode)
                rackPostContactShadows.append(contactNode)

                let postShadowGeo = SCNPlane(width: 0.054, height: 0.52)
                postShadowGeo.materials = [postShadowMat]
                let postShadowNode = SCNNode(geometry: postShadowGeo)
                postShadowNode.name = x < 0 ? "leftPostDirectionalShadow" : "rightPostDirectionalShadow"
                postShadowNode.eulerAngles.x = -.pi / 2
                postShadowNode.position = SCNVector3(x, 0.0006, 0.26)
                postShadowNode.castsShadow = false
                rackShadowRoot.addChildNode(postShadowNode)
                rackPostShadows.append(postShadowNode)
            }

            // Build Crossbar Shadow
            let beamShadowGeo = SCNPlane(width: 0.58, height: 0.065)
            beamShadowGeo.materials = [beamShadowMat]
            rackBeamShadow.name = "bambooBeamDirectionalShadow"
            rackBeamShadow.geometry = beamShadowGeo
            rackBeamShadow.eulerAngles.x = -.pi / 2
            rackBeamShadow.position = SCNVector3(0, 0.0007, 0.50)
            rackBeamShadow.castsShadow = false
            rackShadowRoot.addChildNode(rackBeamShadow)

            // Build Rice Sheaf Shadows (Three Bundles)
            for (index, x) in [-0.15, 0.0, 0.15].enumerated() {
                let bundleShadowGeo = SCNPlane(width: 0.13, height: 0.26)
                bundleShadowGeo.materials = [bundleShadowMat]
                let bundleShadowNode = SCNNode(geometry: bundleShadowGeo)
                bundleShadowNode.name = "hangingBundleShadow_\(index)"
                bundleShadowNode.eulerAngles.x = -.pi / 2
                bundleShadowNode.position = SCNVector3(Float(x), 0.0008, 0.32)
                bundleShadowNode.castsShadow = false
                rackShadowRoot.addChildNode(bundleShadowNode)
                rackBundleShadows.append(bundleShadowNode)
            }
        }

        /// Reuses the exact golden panicle geometry grown in DIBUAT, arranged
        /// into three inverted sheaves. Only the tie is new to the drying rack.
        private func makeHangingRiceBundle(from panicles: [SCNNode], tie: SCNMaterial) -> SCNNode {
            let bundle = SCNNode()
            // Three close layers make each sheaf full at the tied neck, then
            // fan outward below it like the reference drying bundles.
            for layer in 0..<3 {
                for index in panicles.indices {
                    guard let geometry = panicles[index].geometry else { continue }
                    let stalk = SCNNode(geometry: geometry)
                    let lane = Float(index % 5 - 2)
                    let depth = Float(index / 5 - 1)
                    let layerOffset = Float(layer - 1)
                    let fan = lane * 0.105 + Float((index + layer) % 3 - 1) * 0.035
                    stalk.position = SCNVector3(
                        lane * 0.003 + layerOffset * 0.002,
                        -0.004 - Float((index + layer) % 3) * 0.002,
                        depth * 0.004 + layerOffset * 0.003
                    )
                    stalk.eulerAngles = SCNVector3(
                        depth * 0.09,
                        Float(index) * 0.31 + Float(layer) * 0.42,
                        .pi + fan
                    )
                    stalk.scale = SCNVector3(0.88, 0.70, 0.86)
                    bundle.addChildNode(stalk)
                }
            }
            let collarGeometry = SCNCylinder(radius: 0.018, height: 0.022)
            collarGeometry.radialSegmentCount = 12
            collarGeometry.materials = [tie]
            let collar = SCNNode(geometry: collarGeometry)
            collar.position.y = -0.018
            bundle.addChildNode(collar)
            return bundle
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
                applyProgress(displayedProgress)
            }
        }

        private func applyProgress(_ progress: CGFloat) {
            let fullP = Float(min(1, max(0, progress)))
            updateHarvestLighting(progress: CGFloat(fullP))
            // Keep the original farming choreography intact through DIBUAT
            // at 75% of the timeline. The final quarter forms the drying rack
            // and transfers the harvested rice into hanging bundles.
            let p = min(1, fullP / 0.75)
            let time = Float(CACurrentMediaTime() - animationEpoch)

            // ── 1. Forest visibility & tree falling (p 0.00 → 0.33) ─────────
            // Keep the original tree cards readable while the fall begins,
            // then blend them into the radial 3D crown over the longer
            // cinematic clearing interval.
            let forestOpacity = 1 - smoothstep(0.29, 0.36, p)
            setVisibility(forestRoot, opacity: forestOpacity)
            // Clear all cut wood before the Ngaseuk target (p ≈ 0.444).
            rootFlareRoot.opacity = CGFloat(1 - smoothstep(0.29, 0.37, p))
            rootFlareRoot.isHidden = rootFlareRoot.opacity < 0.005
            setVisibility(riceSoilRoot, opacity: smoothstep(0.42, 0.52, p))
            shadowRoot.opacity = CGFloat(forestOpacity)
            setVisibility(wildRoot, opacity: 1 - smoothstep(0.28, 0.37, p))
            // Cut stumps must not be present in the untouched Nukuh state.
            // Reveal them only as the tree finishes its fall, then let the
            // burn transition hide them again with the rest of the field.
            let cutReveal = smoothstep(0.12, 0.19, p)
            let stumpFade = 1 - smoothstep(0.29, 0.37, p)
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
                let fallDuration: Float = 0.145 + Float(index % 3) * 0.012
                let fallEnd: Float = fallStart + fallDuration
                let fallT = max(0, min(1, (p - fallStart) / (fallEnd - fallStart)))
                // Root flares stay planted; only their matching pixels on
                // the falling tree sprite fade away.
                // One rigid body pivots at its fixed base, accelerating
                // smoothly into ground contact without artificial shaking.
                let contactTime: Float = 0.84
                let groundAngle: Float = 1.49
                let fractureReveal = smoothstep(0.12, 0.28, fallT)
                fracturePairs[index].base.opacity = CGFloat(fractureReveal)
                fracturePairs[index].falling.opacity = CGFloat(fractureReveal)
                if fallT >= 0.22 && !crackedTrees.contains(index) {
                    crackedTrees.insert(index)
                    if isWindEnabled { emitCutSplinters(at: entry.origin) }
                } else if fallT < 0.12 {
                    crackedTrees.remove(index)
                }
                let release = smoothstep(0, 0.10, fallT) * 0.012
                let descent = max(0, min(1, (fallT - 0.10) / (contactTime - 0.10)))
                let angle = release + (groundAngle - 0.012) * descent * descent
                // Fall mostly across the screen, with a smaller forward roll
                // so the deepened crown shell exposes its side instead of
                // becoming an edge-on paper strip.
                trunk.eulerAngles.x = angle * 0.34
                trunk.eulerAngles.z = -angle * 0.94
                trunk.position = entry.origin
                let treeFade = 1 - smoothstep(contactTime, 0.97, fallT)
                trunk.opacity = CGFloat(treeFade)
                trunk.isHidden = treeFade < 0.005

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
                        material.setValue(smoothstep(0.10, 0.45, fallT),
                                          forKey: "rootSeparation")
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
                // Directional tree shadow sits behind the object and tracks celestial sun orbit
                let treeSunPhase = HomeCelestialCycle.phase(progress: progress)
                let treeShadowYaw = Float(sin(treeSunPhase)) * -0.35
                entry.shadow.eulerAngles.y = treeShadowYaw
                entry.shadow.opacity = CGFloat(0.55 * treeFade * (1.0 - descent * 0.85))
                entry.shadow.isHidden = treeFade < 0.005

                entry.canopy.childNode(withName: "treeSilhouette", recursively: false)?
                    .geometry?.materials.last?.transparency = 0
                if fallT >= contactTime && !impactedTrees.contains(index) {
                    impactedTrees.insert(index)
                    if isWindEnabled {
                        emitDust(at: entry.origin)
                        emitTreeDebris(at: entry.origin, phase: Float(index) * 0.73)
                    }
                } else if fallT < 0.75 {
                    impactedTrees.remove(index)
                }
            }

            // ── 2. Fire / burning (ends before NGASEUK at timeline p ≈ 0.44) ─
            let fireT = smoothstep(0.27, 0.31, p) * (1 - smoothstep(0.38, 0.44, p))
            fireRoot.opacity = CGFloat(fireT)
            let flicker = 0.90 + 0.06 * sin(time * 4.1) + 0.04 * sin(time * 7.3)
            fireLight.intensity = CGFloat(fireT * flicker * 42)
            for sparks in sparkSystems { sparks.birthRate = isWindEnabled ? CGFloat(fireT * 14) : 0 }
            for smoke in smokeSystems { smoke.birthRate = isWindEnabled ? CGFloat(fireT * 7) : 0 }
            for system in flameSystems {
                system.birthRate = isWindEnabled ? CGFloat(fireT * 40) : 0
            }

            // Soft glowing ground ember disks beneath the burning trees
            for glowNode in groundGlowNodes {
                glowNode.opacity = CGFloat(fireT * flicker * 0.95)
                glowNode.isHidden = fireT < 0.005
            }

            // Incandescent heat glow on the wood surface where fire touches it:
            let heatIntensity = CGFloat(fireT * flicker)
            let heatEmission = UIColor(
                red: heatIntensity * 0.95,
                green: heatIntensity * 0.42,
                blue: heatIntensity * 0.06,
                alpha: 1.0
            )
            rootFlareRoot.enumerateChildNodes { node, _ in
                node.geometry?.materials.forEach { mat in
                    mat.emission.contents = heatEmission
                }
            }
            for pair in fracturePairs {
                pair.base.geometry?.materials.forEach { $0.emission.contents = heatEmission }
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
            let transfer = smoothstep(0.75, 0.91, fullP)
            setVisibility(leavesRoot, opacity: riceGrowth * (1 - transfer))

            // ── 8. Panicles – Tumbuh bersamaan dengan tanaman padi (p 0.90 → 0.98)
            let panicleGrowth = riceGrowth
            paniclesRoot.scale = SCNVector3(panicleGrowth, panicleGrowth, panicleGrowth)
            setVisibility(paniclesRoot, opacity: panicleGrowth * (1 - transfer))

            // Stagger the cut stalks into their hanging positions with a
            // small lift on the way, then hand them off to the bound bundles.
            for transferStalk in harvestTransferNodes {
                let start = 0.75 + transferStalk.delay * 0.15
                let end = 0.90 + transferStalk.delay * 0.15
                let t = smoothstep(start, end, fullP)
                let targetPosition = transferStalk.target.simdWorldPosition
                let position = transferStalk.startPosition
                    + (targetPosition - transferStalk.startPosition) * t
                transferStalk.node.simdWorldPosition = position
                let hangT = smoothstep(0.78, 1, t)
                transferStalk.node.simdWorldOrientation = simd_slerp(
                    transferStalk.startOrientation,
                    transferStalk.target.simdWorldOrientation,
                    hangT
                )
                transferStalk.node.simdScale = simd_mix(
                    transferStalk.startScale,
                    transferStalk.target.simdScale * leuitRoot.simdScale,
                    SIMD3<Float>(repeating: t)
                )
                let appear = smoothstep(0.75 + transferStalk.delay * 0.15,
                                        0.79 + transferStalk.delay * 0.15, fullP)
                let handoff = 1 - smoothstep(0.88 + transferStalk.delay * 0.15,
                                             0.92 + transferStalk.delay * 0.15, fullP)
                let opacity = appear * handoff
                transferStalk.node.opacity = CGFloat(opacity)
                transferStalk.node.isHidden = opacity < 0.005
            }

            // ── 9. Rice colour-lerp green → gold ────────────────────────────
            let green    = SIMD3<Float>(0.82, 0.94, 0.70)
            let gold     = SIMD3<Float>(1.00, 0.84, 0.34)
            // Begin tinting as Ngored starts so the stalks visibly mature
            // from green to yellow across the whole Ngored → Dibuat change.
            let ripeness = smoothstep(0.88, 1.0, p)
            let mixed    = simd_mix(green, gold, SIMD3<Float>(repeating: ripeness))
            let tint     = UIColor(
                red: CGFloat(mixed.x),
                green: CGFloat(mixed.y),
                blue: CGFloat(mixed.z),
                alpha: 1)
            leafMaterials.forEach { $0.multiply.contents = tint }
            panicleMaterials.forEach { $0.multiply.contents = tint }

            // ── 10. Bamboo rises; harvested sheaves hang beneath it ───────
            let postRise = smoothstep(0.76, 0.88, fullP)
            let beamGrow = smoothstep(0.84, 0.92, fullP)
            setVisibility(leuitRoot, opacity: postRise)
            for post in rackPosts {
                post.scale.y = postRise
                post.position.y = 0.31 * postRise
            }
            rackBeam.scale.y = max(0.001, beamGrow)
            setVisibility(rackBeam, opacity: beamGrow)
            for brace in rackBraces {
                setVisibility(brace, opacity: beamGrow)
            }
            for (index, bundle) in hangingBundles.enumerated() {
                let offset = Float(index) * 0.014
                let drop = smoothstep(0.88 + offset, 0.96 + offset, fullP)
                bundle.position.y = 0.62
                setVisibility(bundle, opacity: drop)
            }

            // Directional sunlight shadows tracking post rise, beam expansion, and hanging sheaves
            let rackSunPhase = HomeCelestialCycle.phase(progress: progress)
            let rackShadowYaw = Float(sin(rackSunPhase)) * -0.35
            rackShadowRoot.eulerAngles.y = rackShadowYaw

            for shadow in rackPostContactShadows {
                shadow.opacity = CGFloat(postRise)
            }
            for shadow in rackPostShadows {
                shadow.scale.y = max(0.001, postRise)
                shadow.position.z = 0.26 * postRise
                shadow.opacity = CGFloat(postRise)
            }
            rackBeamShadow.scale.x = max(0.001, beamGrow)
            rackBeamShadow.position.z = 0.50 * postRise
            rackBeamShadow.opacity = CGFloat(beamGrow * postRise)
            for (index, bundleShadow) in rackBundleShadows.enumerated() {
                let offset = Float(index) * 0.014
                let drop = smoothstep(0.88 + offset, 0.96 + offset, fullP)
                bundleShadow.position.z = 0.32 * postRise
                bundleShadow.opacity = CGFloat(drop)
            }

            setVisibility(riceSoilRoot, opacity: smoothstep(0.42, 0.52, p) * (1 - transfer))
            // Hold the rack in the middle of the open field above the text card.
            cameraNode.position = SCNVector3(0, 0.52, 1.75)
            cameraNode.look(at: SCNVector3(0, 0.10 + 0.12 * postRise, 0))
        }

        /// Mirrors the background's five complete day/night cycles
        /// while the preview moves from Ngored to Dibuat.
        private func updateHarvestLighting(progress: CGFloat) {
            let phase = HomeCelestialCycle.phase(progress: progress)
            let altitude = cos(phase)
            let night = CGFloat((1 - altitude) / 2)
            let sunStrength = CGFloat(min(1, max(0, altitude * 5)))
            let moonStrength = CGFloat(min(1, max(0, -altitude * 5)))
            sunOrbitNode.position = SCNVector3(Float(sin(phase) * 4),
                                              Float(altitude * 3) + soilY, -2.4)
            moonOrbitNode.position = SCNVector3(Float(-sin(phase) * 4),
                                               Float(-altitude * 3) + soilY, -2.4)
            sunOrbitNode.look(at: SCNVector3(0, soilY, 0))
            moonOrbitNode.look(at: SCNVector3(0, soilY, 0))
            sunKeyLight.intensity = 155 * sunStrength
            moonLight.intensity = 55 * moonStrength
            sunKeyLight.castsShadow = sunStrength > 0
            moonLight.castsShadow = moonStrength > 0
            sunKeyLight.color = blendColor(
                UIColor(red: 1.0, green: 0.88, blue: 0.70, alpha: 1),
                UIColor(red: 1.0, green: 0.65, blue: 0.40, alpha: 1),
                amount: CGFloat(1 - max(0, altitude))
            )
            skyAmbientLight.intensity = 65 - 53 * night
            skyAmbientLight.color = blendColor(
                UIColor(red: 0.88, green: 0.82, blue: 0.70, alpha: 1),
                UIColor(red: 0.32, green: 0.40, blue: 0.62, alpha: 1), amount: night
            )
            sunsetRimLight.intensity = 0
            let stage5Progress = CGFloat(smoothstep(0.74, 0.85, Float(progress)))
            // Soft front bounce fill: reduced to ~25% of key light so the scene retains
            // rich depth and contrast without being washed out by harsh bounce light.
            let bounceMultiplier: CGFloat = 0.25 * (1.0 - 0.60 * stage5Progress)
            warmFillLight.intensity = (sunKeyLight.intensity * bounceMultiplier)
                + moonLight.intensity * 0.20 * (1.0 - 0.5 * stage5Progress)
            warmFillLight.color = blendColor(
                UIColor(red: 1.0, green: 0.94, blue: 0.86, alpha: 1),
                UIColor(red: 0.62, green: 0.72, blue: 0.90, alpha: 1),
                amount: night
            )
        }

        private func blendColor(_ day: UIColor, _ night: UIColor, amount: CGFloat) -> UIColor {
            var dr: CGFloat = 0, dg: CGFloat = 0, db: CGFloat = 0, da: CGFloat = 0
            var nr: CGFloat = 0, ng: CGFloat = 0, nb: CGFloat = 0, na: CGFloat = 0
            day.getRed(&dr, green: &dg, blue: &db, alpha: &da)
            night.getRed(&nr, green: &ng, blue: &nb, alpha: &na)
            return UIColor(
                red: dr + (nr - dr) * amount,
                green: dg + (ng - dg) * amount,
                blue: db + (nb - db) * amount,
                alpha: da + (na - da) * amount
            )
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

        private func addRicePanicle(
            to root: SCNNode,
            base: SCNVector3,
            height: Float,
            yaw: Float,
            mass: CGFloat,
            response: Float,
            phase: Float
        ) -> SCNMaterial {
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.normal.contents = leafNormal
            material.normal.intensity = 0.12
            material.diffuse.contents = UIImage(named: "HumaYoungRice")
                ?? UIColor(red: 0.94, green: 0.78, blue: 0.26, alpha: 1)
            material.multiply.contents = UIColor(red: 0.96, green: 0.82, blue: 0.32, alpha: 1)
            material.roughness.contents = 0.58
            material.metalness.contents = 0.02
            material.isDoubleSided = true
            material.writesToDepthBuffer = true
            smoothTextureSampling(material.diffuse)

            let geometry = makeRicePanicleGeometry(
                height: height,
                droopArch: height * 0.32,
                material: material
            )
            let pivot = SCNNode(geometry: geometry)
            pivot.name = "ricePanicle"
            pivot.position = base
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

        private func makeRicePanicleGeometry(
            height: Float,
            droopArch: Float,
            material: SCNMaterial
        ) -> SCNGeometry {
            var vertices: [SCNVector3] = []
            var normals: [SCNVector3] = []
            var uvs: [CGPoint] = []
            var indices: [UInt32] = []

            // 1. Central arching rachis / stalk (tangkai malai padi)
            let stemSegments = 20
            func stalkCurve(_ t: Float) -> SIMD3<Float> {
                let y: Float
                let z: Float
                if t <= 0.45 {
                    let u = t / 0.45
                    y = height * 0.58 * u
                    z = 0.012 * u * u
                } else {
                    let u = (t - 0.45) / 0.55
                    y = height * (0.58 + 0.28 * u - 0.22 * u * u)
                    z = 0.012 + droopArch * (0.35 * u + 0.65 * u * u)
                }
                let x: Float = 0.008 * sin(t * .pi * 1.5)
                return SIMD3<Float>(x, y, z)
            }

            let stemSides = 4
            for seg in 0...stemSegments {
                let t = Float(seg) / Float(stemSegments)
                let center = stalkCurve(t)
                let nextCenter = stalkCurve(min(1.0, t + 0.02))
                let prevCenter = stalkCurve(max(0.0, t - 0.02))
                let tangent = simd_normalize(nextCenter - prevCenter)
                let up = SIMD3<Float>(0, 1, 0)
                let right = simd_normalize(simd_cross(tangent, up))
                let fwd = simd_normalize(simd_cross(right, tangent))
                let radius = max(0.0010, 0.0028 * (1.0 - 0.58 * t))

                for side in 0...stemSides {
                    let angle = Float(side) / Float(stemSides) * 2.0 * .pi
                    let n = right * cos(angle) + fwd * sin(angle)
                    let p = center + n * radius
                    vertices.append(SCNVector3(p))
                    normals.append(SCNVector3(n))
                    uvs.append(CGPoint(x: Double(side) / Double(stemSides), y: Double(t)))

                    if seg < stemSegments && side < stemSides {
                        let b = UInt32(seg * (stemSides + 1) + side)
                        let nxt = b + UInt32(stemSides + 1)
                        indices += [b, nxt, b + 1, b + 1, nxt, nxt + 1]
                    }
                }
            }

            // 2. 3D Golden Rice Grains (Bulir Padi / Gabah) clustered along the drooping panicle
            let grainCount = 22
            let grainLength: Float = 0.0155
            let grainWidth: Float = 0.0042
            let grainDepth: Float = 0.0035

            let grainRings = 5
            let grainSides = 6

            for g in 0..<grainCount {
                let gt = 0.42 + 0.54 * (Float(g) / Float(grainCount - 1))
                let stemPos = stalkCurve(gt)
                let tangent = simd_normalize(stalkCurve(min(1.0, gt + 0.02)) - stalkCurve(max(0.0, gt - 0.02)))
                let up = SIMD3<Float>(0, 1, 0)
                let stemRight = simd_normalize(simd_cross(tangent, up))
                let stemFwd = simd_normalize(simd_cross(stemRight, tangent))

                let sideSign: Float = g.isMultiple(of: 2) ? 1.0 : -1.0
                let splayAngle = 0.42 + 0.12 * sin(Float(g) * 1.8)
                let droopBias = 0.48 + 0.15 * cos(Float(g) * 2.1)

                let grainDir = simd_normalize(
                    tangent * droopBias +
                    stemRight * (sideSign * splayAngle) +
                    stemFwd * 0.35
                )

                let grainSideAxis = simd_normalize(simd_cross(grainDir, tangent))
                let grainNormAxis = simd_normalize(simd_cross(grainSideAxis, grainDir))

                let pedicelOffset: Float = 0.0035
                let grainCenter = stemPos + grainDir * (pedicelOffset + grainLength * 0.5)

                let baseVertIndex = UInt32(vertices.count)

                for r in 0...grainRings {
                    let s = Float(r) / Float(grainRings) * 2.0 - 1.0
                    let radiusProfile = sqrt(max(0.0, 1.0 - s * s)) * (1.0 - 0.16 * s)
                    let curveBelly = 0.0012 * (1.0 - s * s)
                    let ringCenter = grainCenter + grainDir * (s * grainLength * 0.5) + grainNormAxis * curveBelly

                    for slice in 0...grainSides {
                        let phi = Float(slice) / Float(grainSides) * 2.0 * .pi
                        let localOffset = (grainSideAxis * cos(phi) * grainWidth + grainNormAxis * sin(phi) * grainDepth) * radiusProfile
                        let pos = ringCenter + localOffset
                        let norm = simd_normalize(localOffset + grainDir * (s * 0.002))

                        vertices.append(SCNVector3(pos))
                        normals.append(SCNVector3(norm))
                        uvs.append(CGPoint(x: Double(slice) / Double(grainSides), y: Double(r) / Double(grainRings)))

                        if r < grainRings && slice < grainSides {
                            let b = baseVertIndex + UInt32(r * (grainSides + 1) + slice)
                            let nxt = b + UInt32(grainSides + 1)
                            indices += [b, nxt, b + 1, b + 1, nxt, nxt + 1]
                        }
                    }
                }
            }

            let geometry = SCNGeometry(
                sources: [
                    SCNGeometrySource(vertices: vertices),
                    SCNGeometrySource(normals: normals),
                    SCNGeometrySource(textureCoordinates: uvs)
                ],
                elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
            )
            geometry.materials = [material]
            return geometry
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

        private lazy var flameTongueSprite: UIImage = NgahumaMaterials.makeFlameTongueSprite()

        private func makeProceduralFlameSheetMaterial(phase: Float) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.blendMode = .alpha
            mat.writesToDepthBuffer = false
            mat.readsFromDepthBuffer = true
            mat.isDoubleSided = true
            mat.shaderModifiers = [.fragment: """
            #pragma arguments
            float flameTime;
            float flameIntensity;
            float flamePhase;
            #pragma transparent
            #pragma body
            float2 uv = _surface.diffuseTexcoord;
            float h = 1.0 - uv.y;
            float x = (uv.x - 0.5) * 2.0;

            float t = flameTime * 2.6 + flamePhase;
            float sway = sin(h * 4.8 - t * 1.5 + flamePhase) * (0.20 * h)
                       + sin(h * 9.6 - t * 2.5 + x * 2.8) * (0.12 * h * h)
                       + cos(h * 15.5 - t * 3.8 - x * 3.5) * (0.07 * h);
            float wx = x + sway;

            float mainTongue = abs(wx) / max(0.06, (1.0 - h * 0.85) * (0.58 + 0.28 * sin(h * 3.14159)));
            float sideL = abs(wx + 0.28 * (1.0 - h * 0.48) + 0.07 * sin(t * 2.2 + h * 6.2)) / max(0.05, max(0.02, 0.74 - h) * 0.42);
            float sideR = abs(wx - 0.26 * (1.0 - h * 0.45) + 0.07 * cos(t * 2.0 + h * 5.8)) / max(0.05, max(0.02, 0.70 - h) * 0.40);
            float shape = min(mainTongue, min(sideL, sideR));

            float n1 = sin(wx * 7.0 + sin(h * 8.5 - t * 2.8)) * cos(h * 11.0 - t * 3.3 + wx * 4.2);
            float n2 = sin(wx * 14.0 - cos(h * 17.0 - t * 4.6)) * 0.5;
            float turb = (n1 + n2) * (0.24 + 0.50 * h);

            float flameMask = 1.0 - smoothstep(0.22, 0.96, shape + turb + h * 0.26);
            float baseMask = smoothstep(0.0, 0.12, h) * (1.0 - smoothstep(0.70, 0.98, h));
            float alpha = clamp(flameMask * baseMask * flameIntensity, 0.0, 1.0);

            float core = clamp(1.0 - shape * 0.82 - h * 0.52 + turb * 0.25, 0.0, 1.0);
            float3 tipColor  = float3(0.72, 0.20, 0.045);
            float3 midColor  = float3(1.0, 0.52, 0.16);
            float3 coreColor = float3(1.20, 1.03, 0.70);
            float3 col = mix(tipColor, midColor, smoothstep(0.0, 0.46, core));
            col = mix(col, coreColor, smoothstep(0.46, 0.86, core));

            _output.color.rgb = col;
            _output.color.a = alpha;
            """]
            mat.setValue(Float(0), forKey: "flameTime")
            mat.setValue(Float(0), forKey: "flameIntensity")
            mat.setValue(phase, forKey: "flamePhase")
            return mat
        }

        private func makeFlames() -> SCNParticleSystem {
            let system = SCNParticleSystem()
            system.birthRate = 0
            system.particleLifeSpan = 0.75
            system.particleLifeSpanVariation = 0.18
            system.particleSize = 0.175
            system.particleSizeVariation = 0.045
            system.particleVelocity = 0.30
            system.particleVelocityVariation = 0.08
            system.emittingDirection = SCNVector3(0, 1, 0)
            system.spreadingAngle = 21
            system.particleAngleVariation = 23
            system.acceleration = SCNVector3(0.015, 0.18, 0)
            system.emitterShape = SCNBox(width: 0.08, height: 0.010, length: 0.08, chamferRadius: 0)
            system.particleImage = flameTongueSprite
            system.blendMode = .additive
            system.orientationMode = .billboardYAligned
            system.isLightingEnabled = false
            system.writesToDepthBuffer = false

            let color = CAKeyframeAnimation()
            color.values = [
                UIColor(red: 1.0, green: 0.96, blue: 0.72, alpha: 0.35),
                UIColor(red: 1.0, green: 0.98, blue: 0.82, alpha: 0.95),
                UIColor(red: 1.0, green: 0.65, blue: 0.10, alpha: 0.88),
                UIColor(red: 0.90, green: 0.20, blue: 0.03, alpha: 0.55),
                UIColor(red: 0.38, green: 0.04, blue: 0.0, alpha: 0.0)
            ]
            color.keyTimes = [0, 0.10, 0.32, 0.70, 1]

            let size = CAKeyframeAnimation()
            size.values = [0.055, 0.18, 0.24, 0.14, 0.03]
            size.keyTimes = [0, 0.12, 0.38, 0.72, 1]

            system.propertyControllers = [
                .color: SCNParticlePropertyController(animation: color),
                .size: SCNParticlePropertyController(animation: size)
            ]
            return system
        }

        private func makeSmoke() -> SCNParticleSystem {
            let system = SCNParticleSystem()
            system.birthRate = 0
            system.particleImage = particleSprite
            system.blendMode = .alpha
            system.isLightingEnabled = false
            system.writesToDepthBuffer = false
            system.particleLifeSpan = 2.1
            system.particleLifeSpanVariation = 0.45
            system.particleSize = 0.17
            system.particleSizeVariation = 0.06
            system.particleVelocity = 0.12
            system.particleVelocityVariation = 0.04
            system.emittingDirection = SCNVector3(0, 1, 0)
            system.acceleration = SCNVector3(0.020, 0.050, 0)
            system.spreadingAngle = 22
            system.particleColor = UIColor(red: 0.38, green: 0.35, blue: 0.30, alpha: 0.18)

            let smokeSize = CAKeyframeAnimation()
            smokeSize.values = [0.055, 0.18, 0.36]
            smokeSize.keyTimes = [0, 0.5, 1]

            let smokeFade = CAKeyframeAnimation()
            smokeFade.values = [0, 0.18, 0.09, 0]
            smokeFade.keyTimes = [0, 0.15, 0.6, 1]

            system.propertyControllers = [
                .size: SCNParticlePropertyController(animation: smokeSize),
                .opacity: SCNParticlePropertyController(animation: smokeFade)
            ]
            return system
        }

        private func emitDust(at position: SCNVector3) {
            let node = SCNNode()
            node.position = position
            let dust = SCNParticleSystem()
            dust.loops = false
            dust.emissionDuration = 0.1
            dust.birthRate = 78
            dust.particleLifeSpan = 0.65
            dust.particleSize = 0.012
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

        /// Short impact burst: light leaves scatter broadly while heavier
        /// wooden splinters travel lower and closer to the fallen trunk.
        private func makeFractureSurface(seed: Int) -> SCNNode {
            let root = SCNNode()
            let wood = SCNMaterial()
            wood.lightingModel = .constant
            wood.diffuse.contents = UIColor(red: 0.88, green: 0.68, blue: 0.45, alpha: 1)
            wood.isDoubleSided = true
            let count = 13
            var vertices = [SCNVector3(0, 0.001, 0)]
            var indices: [Int32] = []
            for i in 0..<count {
                let angle = Float(i) / Float(count) * .pi * 2
                let irregularity = 0.85 + 0.15 * sin(Float(i * 7 + seed))
                vertices.append(SCNVector3(cos(angle) * 0.011 * irregularity,
                                           0.001 + 0.0015 * sin(Float(i * 3 + seed)),
                                           sin(angle) * 0.006 * irregularity))
                indices += [0, Int32(i + 1), Int32((i + 1) % count + 1)]
            }
            let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices)],
                                       elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
            geometry.materials = [wood]
            root.addChildNode(SCNNode(geometry: geometry))
            // Small tapered fibers keep the edge irregular without enlarging
            // the trunk silhouette or adding another stump over the photo.
            for i in 0..<6 {
                let angle = Float(i) * 2.39996 + Float(seed)
                let length = 0.003 + Float(i % 3) * 0.0015
                let fiber = SCNCone(topRadius: 0, bottomRadius: 0.0008, height: CGFloat(length))
                fiber.materials = [wood]
                let node = SCNNode(geometry: fiber)
                node.position = SCNVector3(cos(angle) * 0.007, length * 0.5, sin(angle) * 0.004)
                node.eulerAngles.z = sin(angle) * 0.28
                root.addChildNode(node)
            }
            return root
        }

        private func emitCutSplinters(at position: SCNVector3) {
            let node = SCNNode()
            node.position = position
            let particles = SCNParticleSystem()
            particles.loops = false
            particles.emissionDuration = 0.06
            particles.birthRate = 55
            particles.particleLifeSpan = 0.45
            particles.particleSize = 0.006
            particles.particleSizeVariation = 0.003
            particles.particleVelocity = 0.09
            particles.particleVelocityVariation = 0.04
            particles.emittingDirection = SCNVector3(1, 0.3, 0)
            particles.spreadingAngle = 65
            particles.acceleration = SCNVector3(0, -0.35, 0)
            particles.particleImage = Self.woodSplinterSprite
            particles.particleColor = .white
            particles.isLightingEnabled = false
            particles.blendMode = .alpha
            node.addParticleSystem(particles)
            scene.rootNode.addChildNode(node)
            node.runAction(.sequence([.wait(duration: 0.8), .removeFromParentNode()]))
        }

        private func emitTreeDebris(at position: SCNVector3, phase: Float) {
            let splintersNode = SCNNode()
            splintersNode.position = SCNVector3(position.x, position.y + 0.025, position.z)
            let splinters = SCNParticleSystem()
            splinters.loops = false
            splinters.emissionDuration = 0.08
            splinters.birthRate = 36
            splinters.particleLifeSpan = 1.15
            splinters.particleLifeSpanVariation = 0.28
            splinters.particleSize = 0.015
            splinters.particleSizeVariation = 0.006
            splinters.particleVelocity = 0.22
            splinters.particleVelocityVariation = 0.14
            splinters.emittingDirection = SCNVector3(cos(phase), 1.1, sin(phase))
            splinters.spreadingAngle = 78
            splinters.acceleration = SCNVector3(0, -0.32, 0)
            splinters.particleAngularVelocity = 7
            splinters.particleAngularVelocityVariation = 9
            splinters.particleColor = .white
            splinters.particleColorVariation = SCNVector4(0.03, 0.08, 0.12, 0)
            splinters.particleImage = Self.woodSplinterSprite
            splinters.blendMode = .alpha
            splinters.isLightingEnabled = true
            splintersNode.addParticleSystem(splinters)
            scene.rootNode.addChildNode(splintersNode)
            splintersNode.runAction(.sequence([.wait(duration: 2.2), .removeFromParentNode()]))

            let chipsNode = SCNNode()
            chipsNode.position = SCNVector3(position.x, position.y + 0.018, position.z)
            let chips = SCNParticleSystem()
            chips.loops = false
            chips.emissionDuration = 0.045
            chips.birthRate = 16
            chips.particleLifeSpan = 0.68
            chips.particleLifeSpanVariation = 0.18
            chips.particleSize = 0.010
            chips.particleSizeVariation = 0.004
            chips.particleVelocity = 0.17
            chips.particleVelocityVariation = 0.12
            chips.emittingDirection = SCNVector3(-sin(phase), 0.48, cos(phase))
            chips.spreadingAngle = 54
            chips.acceleration = SCNVector3(0, -0.48, 0)
            chips.particleAngularVelocity = 4
            chips.particleAngularVelocityVariation = 7
            chips.particleColor = .white
            chips.particleColorVariation = SCNVector4(0.02, 0.06, 0.12, 0)
            chips.particleImage = Self.woodChipSprite
            chips.blendMode = .alpha
            chips.isLightingEnabled = true
            chipsNode.addParticleSystem(chips)
            scene.rootNode.addChildNode(chipsNode)
            chipsNode.runAction(.sequence([.wait(duration: 1.8), .removeFromParentNode()]))

            // Brief grazing light at the impact makes the wood fragments
            // pick up warm highlights and a little contrast as they scatter.
            let impactLight = SCNLight()
            impactLight.type = .omni
            impactLight.color = UIColor(red: 1.0, green: 0.72, blue: 0.40, alpha: 1)
            impactLight.intensity = 42
            impactLight.attenuationStartDistance = 0.03
            impactLight.attenuationEndDistance = 0.72
            let impactNode = SCNNode()
            impactNode.light = impactLight
            impactNode.position = SCNVector3(position.x, position.y + 0.12, position.z)
            scene.rootNode.addChildNode(impactNode)
            impactNode.runAction(.sequence([
                .customAction(duration: 0.55) { node, elapsed in
                    guard let light = node.light else { return }
                    light.intensity = 42 * CGFloat(max(0, 1 - elapsed / 0.55))
                },
                .removeFromParentNode()
            ]))
        }

        private static let woodSplinterSprite: UIImage = {
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            format.scale = 2
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 46, height: 18), format: format)
            return renderer.image { context in
                let cg = context.cgContext
                let shard = UIBezierPath()
                shard.move(to: CGPoint(x: 1, y: 12))
                shard.addLine(to: CGPoint(x: 9, y: 7))
                shard.addLine(to: CGPoint(x: 42, y: 2))
                shard.addLine(to: CGPoint(x: 37, y: 9))
                shard.addLine(to: CGPoint(x: 45, y: 13))
                shard.addLine(to: CGPoint(x: 11, y: 14))
                shard.close()
                UIColor(red: 0.56, green: 0.34, blue: 0.17, alpha: 1).setFill()
                shard.fill()
                cg.saveGState()
                shard.addClip()
                for index in 0..<5 {
                    let y = CGFloat(index) * 3 + 3
                    cg.setStrokeColor((index.isMultiple(of: 2)
                        ? UIColor(red: 0.88, green: 0.67, blue: 0.40, alpha: 0.8)
                        : UIColor(red: 0.24, green: 0.12, blue: 0.05, alpha: 0.7)).cgColor)
                    cg.setLineWidth(0.9)
                    cg.move(to: CGPoint(x: 3, y: y + 2))
                    cg.addLine(to: CGPoint(x: 44, y: y - 3))
                    cg.strokePath()
                }
                cg.restoreGState()
            }
        }()

        private static let woodChipSprite: UIImage = {
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            format.scale = 2
            format.preferredRange = .standard
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 14), format: format)
            return renderer.image { context in
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 2, y: 8))
                path.addLine(to: CGPoint(x: 8, y: 4))
                path.addLine(to: CGPoint(x: 35, y: 2))
                path.addLine(to: CGPoint(x: 39, y: 6))
                path.addLine(to: CGPoint(x: 33, y: 10))
                path.addLine(to: CGPoint(x: 5, y: 12))
                path.close()
                UIColor(red: 0.68, green: 0.46, blue: 0.25, alpha: 1).setFill()
                path.fill()
                context.cgContext.saveGState()
                path.addClip()
                // Narrow alternating fibers, clipped to the broken silhouette.
                for i in 0..<12 {
                    let y = CGFloat(i) * 1.15
                    context.cgContext.setStrokeColor((i % 3 == 0
                        ? UIColor(red: 0.86, green: 0.67, blue: 0.42, alpha: 0.75)
                        : UIColor(red: 0.29, green: 0.18, blue: 0.09, alpha: 0.48)).cgColor)
                    context.cgContext.setLineWidth(i % 3 == 0 ? 0.55 : 0.8)
                    context.cgContext.move(to: CGPoint(x: 0, y: y + 3))
                    context.cgContext.addCurve(to: CGPoint(x: 40, y: y - 1),
                        control1: CGPoint(x: 12, y: y), control2: CGPoint(x: 26, y: y + 2))
                    context.cgContext.strokePath()
                }
                context.cgContext.restoreGState()
                context.cgContext.setStrokeColor(UIColor(red: 0.25, green: 0.14, blue: 0.07, alpha: 0.9).cgColor)
                context.cgContext.setLineWidth(1)
                context.cgContext.move(to: CGPoint(x: 6, y: 8))
                context.cgContext.addLine(to: CGPoint(x: 34, y: 5))
                context.cgContext.move(to: CGPoint(x: 13, y: 7))
                context.cgContext.addLine(to: CGPoint(x: 18, y: 4))
                context.cgContext.move(to: CGPoint(x: 23, y: 6))
                context.cgContext.addLine(to: CGPoint(x: 28, y: 3))
                context.cgContext.strokePath()
            }
        }()

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
