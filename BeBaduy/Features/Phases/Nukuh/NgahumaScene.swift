import AVFoundation
import Observation
import SceneKit
import UIKit

/// SceneKit-powered spatial AR experience for Nukuh, unifying HomeView's Nukuh rendering
/// (full root-to-crown 3D relief trees that split at the trunk leaving the rooted stump,
/// arched grass blades, sun lighting, and 3-layer spatial Huma environment)
/// with 360° tree placement, look-around, and interactive tree-clearing & burning.
@MainActor
@Observable
final class NgahumaScene: NSObject, UIGestureRecognizerDelegate {
    enum Stage: Int { case entering, clearing, prepared, burning, complete }

    var onCut: ((Int) -> Void)?
    var onBurnFinished: (() -> Void)?

    private(set) var stage: Stage = .entering
    private(set) var count = 0
    private(set) var progress: Double = 0
    private(set) var tracking = "Menyiapkan lingkungan 360°. Geser layar untuk melihat sekeliling."
    var muted = false {
        didSet {
            audioPlayer?.volume = muted ? 0 : 0.45
        }
    }

    private weak var view: SCNView?
    private let scnScene = SCNScene()
    private let worldRoot = SCNNode()
    private let skyLayerRoot = SCNNode()
    private let sunSystemRoot = SCNNode()
    private let mountainLayerRoot = SCNNode()
    private let horizonGrassLayerRoot = SCNNode()
    private let forestRoot = SCNNode()
    private let wildRoot = SCNNode()
    private let fireRoot = SCNNode()
    private let ashRoot = SCNNode()
    private let cameraNode = SCNNode()

    private let sunKeyLight = SCNLight()
    private let sunCoronaLight = SCNLight()
    private let skyAmbientLight = SCNLight()
    private let warmFillLight = SCNLight()
    private let sunsetRimLight = SCNLight()
    private let fireLight = SCNLight()
    private let fireGlowNode = SCNNode()

    private var groundMaterial: SCNMaterial?

    private final class Blade {
        let pivot: SCNNode
        let phase: Float
        let response: Float
        let restYaw: Float

        init(pivot: SCNNode, phase: Float, response: Float, restYaw: Float) {
            self.pivot = pivot
            self.phase = phase
            self.response = response
            self.restYaw = restYaw
        }
    }

    private struct TreeEntry {
        let holder: SCNNode
        let trunk: SCNNode
        let canopy: SCNNode
        let rootAnchor: SCNNode
        let shadow: SCNNode
        let directionalShadow: SCNNode
        let baseFracture: SCNNode
        let fallingFracture: SCNNode
        let pivotOrigin: SCNVector3
        let worldBasePosition: SCNVector3
        let fallDirection: Float
    }

    private var treeEntries: [TreeEntry] = []
    private var treeCutStartTimes: [Int: Double] = [:]
    private var crackedTrees = Set<Int>()
    private var impactedTrees = Set<Int>()
    private var charredPatches = Set<Int>()
    private var blades: [Blade] = []
    private var patchPositions: [SCNVector3] = []
    private var flameSystems: [SCNParticleSystem] = []
    private var smokeSystems: [SCNParticleSystem] = []
    private var emberNodes: [(node: SCNNode, baseX: Float, baseZ: Float, phase: Float, patchIndex: Int)] = []
    private var ashNodes: [SCNNode] = []

    private var completed = Set<Int>()
    private(set) var assetError: String?
    private(set) var loadingAssets = true
    private var materials: NgahumaMaterials?
    var reduceMotion = false {
        didSet {
            updateWindState()
        }
    }
    private(set) var suspended = false
    private var windTime: Float = 0
    private var elapsed: Double = 0
    private var audioPlayer: AVAudioPlayer?
    private var audioURL: URL?

    private var tap: UITapGestureRecognizer?
    private var pan: UIPanGestureRecognizer?
    private(set) var motionOrientation = simd_quatf(angle: 0, axis: [0, 1, 0])
    private var motionReference = simd_quatf(angle: 0, axis: [0, 1, 0])
    private var yaw: Float = 0
    private var pitch: Float = -0.14
    private let feedback = UIImpactFeedbackGenerator(style: .medium)

    private let soilY: Float = 0.038
    private static let windActionKey = "vegetation.breeze"

    @MainActor
    private final class FrameTarget: NSObject {
        weak var owner: NgahumaScene?
        @objc func tick(_ link: CADisplayLink) {
            owner?.advanceFrame(link)
        }
    }
    private let frameTarget = FrameTarget()
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval = 0

    var title: String {
        switch stage {
        case .entering: "Masuki lingkungan"
        case .clearing: "Siapkan lahan"
        case .prepared: "Lahan siap"
        case .burning: "Amati perubahan"
        case .complete: "Lahan kembali tumbuh"
        }
    }

    var instruction: String {
        switch stage {
        case .entering: "Lingkungan 3D sedang disiapkan. Kamera perangkat tidak digunakan."
        case .clearing: "Geser untuk melihat sekeliling dan ketuk pohon untuk merapikan vegetasi. \(count)/6"
        case .prepared: "Mulai adegan pembakaran virtual dan amati perubahan lahan."
        case .burning: "Api, bara, dan asap bergerak di atas lahan virtual."
        case .complete: "Anda telah menyelesaikan rangkaian simulasi ngahuma."
        }
    }

    // MARK: - View Attachment & Lifecycle

    func attach(_ view: SCNView) {
        self.view = view
        configureRenderer(view)
        configureCamera()

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        view.addGestureRecognizer(tap)
        self.tap = tap

        let pan = UIPanGestureRecognizer(target: self, action: #selector(lookAround(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
        self.pan = pan

        startDisplayLink()
        if materials != nil {
            reset()
        }
    }

    private func configureRenderer(_ view: SCNView) {
        scnScene.background.contents = UIColor(red: 0.42, green: 0.30, blue: 0.20, alpha: 1)
        scnScene.physicsWorld.gravity = SCNVector3Zero

        view.scene = scnScene
        view.backgroundColor = UIColor(red: 0.42, green: 0.30, blue: 0.20, alpha: 1)
        view.isOpaque = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling2X
        view.isJitteringEnabled = false
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.isPlaying = !suspended
        view.allowsCameraControl = false
    }

    private func configureCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 42
        camera.zNear = 0.02
        camera.zFar = 40.0
        // Match HomeView's exact HDR exposure, whitePoint, SSAO, and bloom (SceneKitCropView lines 245-254)
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = -1.05
        camera.whitePoint = 1.8
        camera.screenSpaceAmbientOcclusionIntensity = 0.42
        camera.screenSpaceAmbientOcclusionRadius = 0.035
        camera.screenSpaceAmbientOcclusionBias = 0.002
        camera.bloomThreshold = 1.2
        camera.bloomIntensity = 0.12
        camera.bloomBlurRadius = 3.0

        cameraNode.name = "nukuhARCamera"
        cameraNode.camera = camera
        if cameraNode.parent == nil {
            scnScene.rootNode.addChildNode(cameraNode)
        }
        updatePreviewCamera()
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        frameTarget.owner = self
        let link = CADisplayLink(target: frameTarget, selector: #selector(FrameTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        link.isPaused = suspended
        displayLink = link
    }

    func prepareAssets() async {
        guard materials == nil else {
            if stage == .entering {
                buildScene()
            }
            return
        }
        loadingAssets = true
        assetError = nil
        defer { loadingAssets = false }
        do {
            let loaded = try await NgahumaMaterials.load()
            try Task.checkCancellation()
            materials = loaded
            buildScene()
        } catch is CancellationError {
            return
        } catch {
            assetError = "Tekstur belum dapat dimuat. Ketuk coba lagi."
        }
    }

    func loadAudio() async {
        guard let url = Bundle.main.url(forResource: "ngahuma-fire", withExtension: "wav") else { return }
        audioURL = url
        guard !Task.isCancelled else { return }
        if stage == .burning {
            startAudio()
        }
    }

    // MARK: - Scene Construction (3 Spatial Layers + SceneKit Sun + 360° HomeView Grass & Trees)

    private func buildScene() {
        guard let materials else { return }

        worldRoot.childNodes.forEach { $0.removeFromParentNode() }
        if worldRoot.parent == nil {
            scnScene.rootNode.addChildNode(worldRoot)
        }

        skyLayerRoot.childNodes.forEach { $0.removeFromParentNode() }
        sunSystemRoot.childNodes.forEach { $0.removeFromParentNode() }
        mountainLayerRoot.childNodes.forEach { $0.removeFromParentNode() }
        horizonGrassLayerRoot.childNodes.forEach { $0.removeFromParentNode() }
        forestRoot.childNodes.forEach { $0.removeFromParentNode() }
        wildRoot.childNodes.forEach { $0.removeFromParentNode() }
        fireRoot.childNodes.forEach { $0.removeFromParentNode() }
        ashRoot.childNodes.forEach { $0.removeFromParentNode() }

        treeEntries.removeAll()
        treeCutStartTimes.removeAll()
        crackedTrees.removeAll()
        impactedTrees.removeAll()
        charredPatches.removeAll()
        blades.removeAll()
        patchPositions.removeAll()
        flameSystems.removeAll()
        smokeSystems.removeAll()
        emberNodes.removeAll()
        ashNodes.removeAll()

        // 1. Spatial 3-Layer Environment + 3D SceneKit Sun Light Source
        buildSpatialLayersAndSun(using: materials)

        // 2. Unified 3D Ground & Shadow Receiver (matching HomeView, no extra disks under trees)
        buildGround(using: materials)

        // 3. HomeView 3D Trees spread 360° around the scene (loaded down to roots, splitting at cut line)
        buildForest(using: materials)

        // 4. HomeView 3D Wild Grass Blades distributed 360° around the huma clearing
        buildWildGrass(using: materials)

        // 5. Fire, Embers & Ash Clods (for the burning phase)
        buildFireAndAsh(using: materials)

        stage = .clearing
        tracking = ""
    }

    private func buildSpatialLayersAndSun(using materials: NgahumaMaterials) {
        // ── Layer 1 (Outermost Back): 360° Sky Layer ("layer langit") ─────────
        skyLayerRoot.name = "spatialSkyLayer"
        let skyGeometry = NgahumaMaterials.makeSkyDome(radius: 24.0, texture: materials.skyTexture)
        let skyNode = SCNNode(geometry: skyGeometry)
        skyNode.position = SCNVector3(0, 0.52, 0)
        skyNode.renderingOrder = -30
        skyNode.castsShadow = false
        skyLayerRoot.addChildNode(skyNode)
        worldRoot.addChildNode(skyLayerRoot)

        // ── 3D Sun Rendered in SceneKit as the Primary Light Source ──────────
        sunSystemRoot.name = "spatialSunLightSource"
        // Positioned above the central mountain ridge matching HomeView's Stage 1 sun (orbitPhase = 0)
        let sunPosition = SCNVector3(0.0, 2.75, -15.5)
        sunSystemRoot.position = sunPosition

        // HomeView-style sun: one camera-facing sprite reproducing Home's
        // celestialBody (27 pt disk inside a 90 pt glow frame).
        let sunPlane = SCNPlane(width: 1.45, height: 1.45)
        let sunMaterial = SCNMaterial()
        sunMaterial.lightingModel = .constant
        sunMaterial.diffuse.contents = materials.sunHaloSprite
        sunMaterial.multiply.contents = UIColor(red: 1.48, green: 1.45, blue: 1.38, alpha: 1)
        sunMaterial.blendMode = .alpha
        sunMaterial.writesToDepthBuffer = false
        sunMaterial.readsFromDepthBuffer = false
        sunMaterial.isDoubleSided = true
        sunPlane.materials = [sunMaterial]
        let sunDiskNode = SCNNode(geometry: sunPlane)
        sunDiskNode.name = "homeSunDisk"
        let sunBillboard = SCNBillboardConstraint()
        sunBillboard.freeAxes = .all
        sunDiskNode.constraints = [sunBillboard]
        sunDiskNode.renderingOrder = -25
        sunDiskNode.castsShadow = false
        sunSystemRoot.addChildNode(sunDiskNode)

        // Home's broad daylight glow (radial, endRadius ≈ 0.78 × screen width).
        let haloPlane = SCNPlane(width: 14.0, height: 14.0)
        let haloMaterial = SCNMaterial()
        haloMaterial.lightingModel = .constant
        haloMaterial.diffuse.contents = materials.sunSkyGlowSprite
        haloMaterial.multiply.contents = UIColor(red: 1.48, green: 1.45, blue: 1.38, alpha: 1)
        haloMaterial.blendMode = .screen
        haloMaterial.writesToDepthBuffer = false
        haloMaterial.readsFromDepthBuffer = false
        haloMaterial.isDoubleSided = true
        haloPlane.materials = [haloMaterial]
        let haloNode = SCNNode(geometry: haloPlane)
        haloNode.name = "homeSunSkyGlow"
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        haloNode.constraints = [billboard]
        haloNode.renderingOrder = -26
        haloNode.castsShadow = false
        sunSystemRoot.addChildNode(haloNode)

        // Directional Sun Key Light matching HomeView (SceneKitCropView lines 282-298 & 1726-1734)
        sunKeyLight.type = .directional
        sunKeyLight.color = UIColor(red: 1.0, green: 0.88, blue: 0.70, alpha: 1)
        sunKeyLight.intensity = 155
        sunKeyLight.castsShadow = false
        let sunLightNode = SCNNode()
        sunLightNode.light = sunKeyLight
        sunLightNode.position = .init(0, 0, 0)
        sunLightNode.look(at: SCNVector3(-sunPosition.x, soilY - sunPosition.y, -sunPosition.z))
        sunSystemRoot.addChildNode(sunLightNode)

        sunCoronaLight.type = .omni
        sunCoronaLight.color = UIColor(red: 1.0, green: 0.88, blue: 0.70, alpha: 1)
        sunCoronaLight.intensity = 0
        let sunOmniNode = SCNNode()
        sunOmniNode.light = sunCoronaLight
        sunSystemRoot.addChildNode(sunOmniNode)

        worldRoot.addChildNode(sunSystemRoot)

        // Fill – Sky Ambient matching HomeView (SceneKitCropView lines 301-307 & 1735-1739)
        skyAmbientLight.type = .ambient
        skyAmbientLight.color = UIColor(red: 0.88, green: 0.82, blue: 0.70, alpha: 1)
        skyAmbientLight.intensity = 65
        let ambientNode = SCNNode()
        ambientNode.light = skyAmbientLight
        worldRoot.addChildNode(ambientNode)

        // Rim – Back-light matching HomeView (SceneKitCropView line 1740)
        sunsetRimLight.type = .directional
        sunsetRimLight.color = UIColor(red: 1.0, green: 0.87, blue: 0.68, alpha: 1)
        sunsetRimLight.intensity = 0
        sunsetRimLight.castsShadow = false
        let rimNode = SCNNode()
        rimNode.light = sunsetRimLight
        rimNode.position = SCNVector3(-4.0, 3.2, 5.0)
        rimNode.look(at: SCNVector3(0, soilY, 0))
        worldRoot.addChildNode(rimNode)

        // Warm Fill matching HomeView (SceneKitCropView lines 323-333 & 1745-1751)
        warmFillLight.type = .omni
        warmFillLight.color = UIColor(red: 1.0, green: 0.94, blue: 0.86, alpha: 1)
        warmFillLight.intensity = 155
        warmFillLight.castsShadow = false
        warmFillLight.attenuationStartDistance = 2.0
        warmFillLight.attenuationEndDistance = 12.0
        let fillNode = SCNNode()
        fillNode.light = warmFillLight
        fillNode.position = SCNVector3(0, 0.70, 0)
        worldRoot.addChildNode(fillNode)

        // ── Layer 2 (Middle): 360° Mountain Ridge Layer ("gunung-gunungan") ──
        mountainLayerRoot.name = "spatialMountainLayer"
        let mountainGeometry = NgahumaMaterials.makePanoramicCylinder(
            radius: 13.5,
            bottomY: -0.45,
            topY: 4.60,
            texture: materials.mountainTexture,
            transparent: true
        )
        let mountainNode = SCNNode(geometry: mountainGeometry)
        mountainNode.renderingOrder = -20
        mountainNode.castsShadow = false
        mountainLayerRoot.addChildNode(mountainNode)
        worldRoot.addChildNode(mountainLayerRoot)

        // ── Layer 3a (Foreground Horizon): 360° Grass & Soil Rim Layer ───────
        horizonGrassLayerRoot.name = "spatialHorizonGrassLayer"
        let horizonGeometry = NgahumaMaterials.makePanoramicCylinder(
            radius: 12.2,
            bottomY: -0.50,
            topY: 1.50,
            texture: materials.horizonGrassTexture,
            transparent: true
        )
        let horizonNode = SCNNode(geometry: horizonGeometry)
        horizonNode.renderingOrder = -10
        horizonNode.castsShadow = false
        horizonGrassLayerRoot.addChildNode(horizonNode)
        worldRoot.addChildNode(horizonGrassLayerRoot)
    }

    private func buildGround(using materials: NgahumaMaterials) {
        let (terrainGeometry, terrainMat) = NgahumaMaterials.makeTerrainMesh(
            span: 24.5,
            steps: 80,
            soilY: soilY,
            texture: materials.soilTexture
        )
        groundMaterial = terrainMat
        let terrainNode = SCNNode(geometry: terrainGeometry)
        terrainNode.name = "humaTerrain"
        terrainNode.castsShadow = false
        worldRoot.addChildNode(terrainNode)
    }

    // MARK: - HomeView 3D Forest Spread Across All 360° (Full Root-to-Crown + Split Stump)

    private func buildForest(using materials: NgahumaMaterials) {
        forestRoot.name = "forest"
        worldRoot.addChildNode(forestRoot)

        // Spread the 6 interactive trees around all 360° of the AR clearing,
        // with natural variations in azimuth, distance, and balanced tree scale (~1.25m - 1.40m).
        let placements: [(angle: Float, distance: Float, yawOffset: Float, scale: Float)] = [
            ( 0.00 * .pi, 1.84, -0.06, 2.25), // Tree 1: Front (0°) - ~1.26m tall
            ( 0.34 * .pi, 1.98,  0.08, 2.45), // Tree 2: Front-Right (~61°) - ~1.37m tall
            ( 0.68 * .pi, 1.86, -0.09, 2.15), // Tree 3: Back-Right (~122°) - ~1.20m tall
            ( 1.02 * .pi, 1.95,  0.07, 2.38), // Tree 4: Back (~184°) - ~1.33m tall
            ( 1.35 * .pi, 1.85, -0.08, 2.20), // Tree 5: Back-Left (~243°) - ~1.23m tall
            ( 1.68 * .pi, 1.94,  0.09, 2.42)  // Tree 6: Front-Left (~302°) - ~1.36m tall
        ]

        let sharedUpperTreeGeo = makeTreeSectionGeometry(from: materials.treeTexture, startRow: 6, endRow: 40, includeWind: true)
        let sharedRootBaseGeo = makeTreeSectionGeometry(from: materials.treeTexture, startRow: 0, endRow: 6, includeWind: false)
        let sharedCrownGeo = makeRadialCrownGeometry()

        for (index, placement) in placements.enumerated() {
            let worldX = sin(placement.angle) * placement.distance
            let worldZ = -cos(placement.angle) * placement.distance
            let worldPos = SCNVector3(worldX, soilY, worldZ)
            patchPositions.append(worldPos)

            addTexturedTree(
                index: index,
                worldPosition: worldPos,
                facingYaw: -placement.angle + placement.yawOffset,
                scale: placement.scale,
                materials: materials,
                upperTreeGeometry: sharedUpperTreeGeo,
                rootBaseGeometry: sharedRootBaseGeo,
                radialCrownGeometry: sharedCrownGeo
            )
        }
    }

    private func addTexturedTree(
        index: Int,
        worldPosition: SCNVector3,
        facingYaw: Float,
        scale: Float,
        materials: NgahumaMaterials,
        upperTreeGeometry: SCNGeometry,
        rootBaseGeometry: SCNGeometry,
        radialCrownGeometry: SCNGeometry
    ) {
        // 6 of 40 mesh rows (bottom 15% = root flare & lower stump, top 85% = falling trunk & crown).
        // At height = 0.56m, row 6 sits at 0.15 * 0.56 = 0.084m.
        // Bottom of row 0 sits flush at y = soilY (nothing extends below the ground).
        let cutHeight: Float = 0.084

        // Holder node at the tree's ground coordinate oriented toward the central viewer
        let holder = SCNNode()
        holder.name = "patch-\(index)"
        holder.position = worldPosition
        holder.eulerAngles.y = facingYaw
        forestRoot.addChildNode(holder)

        // 1. Lower 15% Root Flare & Stump Base (rows 0..<6): stays planted on the soil
        let rootAnchor = SCNNode()
        rootAnchor.name = "patch-\(index)"
        rootAnchor.position = SCNVector3(0, 0, 0)
        rootAnchor.scale = SCNVector3(scale, scale, scale)

        let rootMeshCopy = rootBaseGeometry.copy() as! SCNGeometry
        rootMeshCopy.materials = rootBaseGeometry.materials.map { $0.copy() as! SCNMaterial }
        let rootMeshNode = SCNNode(geometry: rootMeshCopy)
        rootMeshNode.name = "patch-\(index)"
        rootMeshNode.castsShadow = false
        rootAnchor.addChildNode(rootMeshNode)

        // Jagged wood fracture surface on top of the rooted stump (revealed when tree splits)
        let baseFracture = makeFractureSurface(seed: index)
        baseFracture.position = SCNVector3(-0.001, cutHeight, -0.006)
        baseFracture.opacity = 0
        rootAnchor.addChildNode(baseFracture)
        holder.addChildNode(rootAnchor)

        // 2. Upper 85% Trunk & Crown (rows 6..<40): pivots at the exact top of rootAnchor (cutHeight * scale)
        let pivot = SCNNode()
        pivot.name = "patch-\(index)"
        pivot.position = SCNVector3(0, cutHeight * scale, 0)
        pivot.scale = SCNVector3(scale, scale, scale)
        pivot.castsShadow = false

        let wood = stumpMaterial(using: materials)
        let upperMeshCopy = upperTreeGeometry.copy() as! SCNGeometry
        upperMeshCopy.materials = upperTreeGeometry.materials.map { $0.copy() as! SCNMaterial }

        let canopy = SCNNode()
        canopy.name = "treeSprite_\(index)"
        // Shift by -cutHeight so row 6 (y = 0.075 in mesh space) sits at y = 0 of pivot
        canopy.position.y = -cutHeight
        canopy.castsShadow = false

        let front = SCNNode(geometry: upperMeshCopy)
        front.name = "treeSilhouette"
        front.position.z = 0
        front.castsShadow = false
        canopy.addChildNode(front)

        let radial = SCNNode(geometry: radialCrownGeometry.copy() as? SCNGeometry)
        radial.name = "radialFoliage"
        let radialMaterial = SCNMaterial()
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
        for i in 0..<12 {
            let a = Float(i) * 2.39996
            let direction = SIMD3<Float>(cos(a), 0, sin(a))
            let p0 = SIMD3<Float>(0, 0.255, -0.012)
            let p1 = direction * 0.045 + SIMD3<Float>(0, 0.305, -0.038)
            let p2 = direction * 0.092 + SIMD3<Float>(0, 0.355, -0.058)
            let p3 = direction * 0.135 + SIMD3<Float>(0, 0.382, -0.062)
            supports.addChildNode(branch(from: p0, to: p1, radius: 0.0034, material: wood))
            supports.addChildNode(branch(from: p1, to: p2, radius: 0.0025, material: wood))
            supports.addChildNode(branch(from: p2, to: p3, radius: 0.0017, material: wood))
            for twig in 0..<2 {
                let side: Float = twig == 0 ? 1.0 : -1.0
                let tangent = SIMD3<Float>(-sin(a) * side, 0, cos(a) * side)
                let twigStart = p2 + tangent * 0.004
                let twigEnd = p2 + direction * 0.036 + tangent * 0.026 + SIMD3<Float>(0, 0.018, 0)
                supports.addChildNode(branch(from: twigStart, to: twigEnd, radius: 0.00115, material: wood))
            }
        }
        let rearBranches = supports.flattenedClone()
        rearBranches.name = "radialBranches"
        rearBranches.opacity = 0
        rearBranches.isHidden = true
        canopy.addChildNode(rearBranches)

        // Hit-test proxy box for responsive direct tapping on the 3D tree
        let hitBox = SCNBox(width: 0.38, height: 0.58, length: 0.24, chamferRadius: 0)
        let hitMat = SCNMaterial()
        hitMat.lightingModel = .constant
        hitMat.diffuse.contents = UIColor.clear
        hitMat.writesToDepthBuffer = false
        hitBox.materials = [hitMat]
        let hitNode = SCNNode(geometry: hitBox)
        hitNode.name = "patch-\(index)"
        hitNode.position = SCNVector3(0, 0.27, 0)
        hitNode.opacity = 0.001
        hitNode.castsShadow = false
        canopy.addChildNode(hitNode)

        pivot.addChildNode(canopy)

        // Matching fracture surface on the bottom of the falling upper trunk
        let fallingFracture = makeFractureSurface(seed: index)
        fallingFracture.position = SCNVector3(-0.001, 0, -0.006)
        fallingFracture.eulerAngles.z = .pi
        fallingFracture.opacity = 0
        pivot.addChildNode(fallingFracture)

        holder.addChildNode(pivot)

        // A. 3D organic soil collar that rises 6.8 mm at the bark and feathers outward
        let soilCollar = buildRootSoilCollar(scale: scale, materials: materials)
        holder.addChildNode(soilCollar)

        // Shadows hidden in AR world to keep the tree and ground clean
        let shadow = SCNNode()
        shadow.opacity = 0
        shadow.isHidden = true
        holder.addChildNode(shadow)

        let directionalShadowRoot = SCNNode()
        directionalShadowRoot.name = "directionalShadow_\(index)"
        directionalShadowRoot.opacity = 0
        directionalShadowRoot.isHidden = true
        holder.addChildNode(directionalShadowRoot)

        // E. Lush HomeView-matched clusters of wild grass blades rooted around the trunk
        for grassIdx in 0..<18 {
            let grassAngle = Float(grassIdx) * 2.3999 + Float(index) * 0.35
            let grassDist = (0.048 + Float((grassIdx * 7) % 15) * 0.012) * scale
            let grassBase = SCNVector3(
                worldPosition.x + sin(grassAngle) * grassDist,
                soilY + 0.001,
                worldPosition.z + cos(grassAngle) * grassDist
            )
            let bladeHeight = (0.072 + Float(grassIdx % 7) * 0.012) * scale
            let bladeTint: UIColor = grassIdx.isMultiple(of: 3)
                ? UIColor(red: 0.55, green: 0.58, blue: 0.23, alpha: 1)
                : UIColor(red: 0.32, green: 0.48, blue: 0.16, alpha: 1)
            addBlade(
                to: wildRoot,
                base: grassBase,
                height: bladeHeight,
                width: 0.018 * scale,
                yaw: grassAngle + Float(grassIdx % 5) * 0.21,
                mass: 0.16,
                response: 1.0,
                tint: bladeTint,
                phase: Float(index * 9 + grassIdx) * 0.42,
                materials: materials
            )
        }

        let fallDir: Float = index.isMultiple(of: 2) ? 1.0 : -1.0
        treeEntries.append(
            TreeEntry(
                holder: holder,
                trunk: pivot,
                canopy: canopy,
                rootAnchor: rootAnchor,
                shadow: shadow,
                directionalShadow: directionalShadowRoot,
                baseFracture: baseFracture,
                fallingFracture: fallingFracture,
                pivotOrigin: pivot.position,
                worldBasePosition: worldPosition,
                fallDirection: fallDir
            )
        )
    }

    private func buildRootSoilCollar(scale: Float, materials: NgahumaMaterials) -> SCNNode {
        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var coords: [CGPoint] = []
        var triangles: [UInt32] = []
        let sides = 32
        let rings = 3
        let baseRadius: Float = 0.085 * scale
        for ring in 0...rings {
            let t = Float(ring) / Float(rings)
            for j in 0...sides {
                let a = Float(j) / Float(sides) * 2.0 * .pi
                let wobble = 1.0 + 0.14 * sin(a * 5.0) + 0.08 * cos(a * 8.0)
                let r = t * baseRadius * wobble
                let y = (0.0068 * scale) * (1.0 - t * t)
                positions.append(SCNVector3(cos(a) * r, y, sin(a) * r))
                normals.append(SCNVector3(0, 1, 0))
                coords.append(CGPoint(x: CGFloat(cos(a) * t * 0.5 + 0.5), y: CGFloat(sin(a) * t * 0.5 + 0.5)))
                if ring < rings && j < sides {
                    let b = UInt32(ring * (sides + 1) + j)
                    let n = b + UInt32(sides + 1)
                    triangles += [b, b + 1, n, b + 1, n + 1, n]
                }
            }
        }
        let soil = SCNMaterial()
        soil.lightingModel = .constant
        soil.diffuse.contents = materials.soilTexture
        soil.diffuse.wrapS = .repeat
        soil.diffuse.wrapT = .repeat
        soil.multiply.contents = UIColor(red: 0.68, green: 0.56, blue: 0.46, alpha: 1)
        soil.isDoubleSided = true
        soil.transparencyMode = .default
        soil.writesToDepthBuffer = false
        soil.shaderModifiers = [.fragment: """
        #pragma transparent
        #pragma body
        float r = length(_surface.diffuseTexcoord - float2(0.5));
        _output.color.a *= 1.0 - smoothstep(0.28, 0.50, r);
        if (_output.color.a < 0.02) { discard_fragment(); }
        """]
        let mesh = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: positions),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: coords)
            ],
            elements: [SCNGeometryElement(indices: triangles, primitiveType: .triangles)]
        )
        mesh.materials = [soil]
        let lipNode = SCNNode(geometry: mesh)
        lipNode.name = "rootSoilLip"
        lipNode.position = SCNVector3(0, 0.0006, 0)
        lipNode.castsShadow = false
        return lipNode
    }

    // MARK: - HomeView 3D Wild Grass Blades Distributed 360°

    private func buildWildGrass(using materials: NgahumaMaterials) {
        wildRoot.name = "wildGrass"
        worldRoot.addChildNode(wildRoot)

        // 1. Inner 360° clearing grass blades (matching HomeView's arched undergrowth at AR scale)
        for index in 0..<96 {
            let angle = Float(index) * 2.3999
            let distance = 0.82 + Float((index * 13) % 37) * 0.036
            let base = SCNVector3(
                sin(angle) * distance,
                soilY,
                -cos(angle) * distance
            )
            let height = 0.13 + Float(index % 7) * 0.018
            let tint: UIColor = index.isMultiple(of: 3)
                ? UIColor(red: 0.55, green: 0.58, blue: 0.23, alpha: 1)
                : UIColor(red: 0.32, green: 0.48, blue: 0.16, alpha: 1)
            addBlade(
                to: wildRoot,
                base: base,
                height: height,
                width: 0.030,
                yaw: angle + Float(index % 5) * 0.21,
                mass: 0.16,
                response: 1.0,
                tint: tint,
                phase: Float(index % 9) * 0.42,
                materials: materials
            )
        }

        // 2. Outer 360° meadow grass blades extending toward the horizon grass rim
        for index in 0..<120 {
            let angle = Float(index) * 2.399963
            let radius = 2.15 + Float((index * 11) % 31) * 0.14
            let base = SCNVector3(sin(angle) * radius, soilY, -cos(angle) * radius)
            let height = 0.16 + Float(index % 6) * 0.024
            let tint: UIColor = index.isMultiple(of: 3)
                ? UIColor(red: 0.55, green: 0.58, blue: 0.23, alpha: 1)
                : UIColor(red: 0.34, green: 0.50, blue: 0.17, alpha: 1)
            addBlade(
                to: wildRoot,
                base: base,
                height: height,
                width: 0.034,
                yaw: angle + Float(index % 7) * 0.19,
                mass: 0.18,
                response: 0.95,
                tint: tint,
                phase: Float(index % 11) * 0.37,
                materials: materials
            )
        }

        // 3. Perimeter horizon grass blades (radius 8.8 to 11.5m) seamlessly blending the terrain floor into the 360° cylinder
        for index in 0..<56 {
            let angle = Float(index) * (2.0 * .pi / 56.0) + Float(index % 5) * 0.04
            let radius = 8.8 + Float((index * 17) % 29) * 0.095
            let py = soilY + min(1.0, max(0.0, (radius - 7.5) / 4.5)) * 0.22
            let base = SCNVector3(sin(angle) * radius, py, -cos(angle) * radius)
            let height = 0.22 + Float(index % 7) * 0.028
            let tint: UIColor = index.isMultiple(of: 2)
                ? UIColor(red: 0.58, green: 0.60, blue: 0.24, alpha: 1)
                : UIColor(red: 0.36, green: 0.52, blue: 0.18, alpha: 1)
            addBlade(
                to: wildRoot,
                base: base,
                height: height,
                width: 0.038,
                yaw: angle + Float(index % 7) * 0.22,
                mass: 0.22,
                response: 0.88,
                tint: tint,
                phase: Float(index % 13) * 0.31,
                materials: materials
            )
        }
    }

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
        phase: Float,
        materials: NgahumaMaterials
    ) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.normal.contents = materials.leafNormal
        material.normal.intensity = 0.08
        material.diffuse.contents = materials.grassBladeTexture
        // Match HomeView (SceneKitCropView lines 1783-1801)
        material.multiply.contents = UIColor(white: 0.96, alpha: 1)
        material.emission.intensity = 0
        material.roughness.contents = 0.92
        material.metalness.contents = 0.0
        material.isDoubleSided = true
        material.transparencyMode = .aOne
        material.writesToDepthBuffer = true
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .clamp
        NgahumaMaterials.smoothTextureSampling(material.diffuse)

        let geometry = makeBladeGeometry(
            height: height,
            width: width,
            arch: height * (0.20 + response * 0.05),
            material: material
        )
        let pivot = SCNNode(geometry: geometry)
        pivot.name = "blade"
        pivot.position = base
        pivot.eulerAngles.y = yaw
        pivot.castsShadow = false
        root.addChildNode(pivot)

        let blade = Blade(
            pivot: pivot,
            phase: phase,
            response: response / Float(max(mass, 0.08)),
            restYaw: yaw
        )
        blades.append(blade)
        startBreeze(on: blade)
        return material
    }

    private func startBreeze(on blade: Blade) {
        guard !reduceMotion && !suspended,
              blade.pivot.action(forKey: Self.windActionKey) == nil else { return }
        let amplitude = CGFloat(min(0.065, 0.035 + blade.response * 0.004))
        let halfPeriod = 2.8 + Double(blade.phase.truncatingRemainder(dividingBy: 1.4))
        let direction: CGFloat = sin(blade.phase) >= 0 ? 1 : -1

        func lean(_ amount: CGFloat, duration: TimeInterval) -> SCNAction {
            let a = SCNAction.rotateTo(
                x: amount * 0.25,
                y: CGFloat(blade.restYaw),
                z: amount,
                duration: duration,
                usesShortestUnitArc: true
            )
            a.timingMode = .easeInEaseOut
            return a
        }
        let loop = SCNAction.sequence([
            lean(-amplitude * direction, duration: halfPeriod),
            lean(amplitude * direction, duration: halfPeriod)
        ])
        blade.pivot.runAction(.sequence([
            lean(amplitude * direction, duration: halfPeriod / 2),
            .repeatForever(loop)
        ]), forKey: Self.windActionKey)
    }

    private func updateWindState() {
        let active = !reduceMotion && !suspended
        for blade in blades {
            if active {
                startBreeze(on: blade)
            } else {
                blade.pivot.removeAction(forKey: Self.windActionKey)
                blade.pivot.eulerAngles = SCNVector3(0, blade.restYaw, 0)
            }
        }
    }

    // MARK: - HomeView Fire, Embers & Ash Clods

    private func buildFireAndAsh(using materials: NgahumaMaterials) {
        fireRoot.name = "fire"
        ashRoot.name = "ash"
        worldRoot.addChildNode(fireRoot)
        worldRoot.addChildNode(ashRoot)

        fireLight.type = .omni
        fireLight.color = UIColor(red: 1.0, green: 0.48, blue: 0.12, alpha: 1)
        fireLight.intensity = 0
        fireLight.attenuationStartDistance = 0.2
        fireLight.attenuationEndDistance = 5.5
        fireGlowNode.light = fireLight
        fireGlowNode.position = SCNVector3(0, soilY + 0.32, -1.7)
        fireRoot.addChildNode(fireGlowNode)

        for (patchIndex, patchPos) in patchPositions.enumerated() {
            // 1. Primary stump & root-collar fire emitter
            let stumpEmitter = SCNNode()
            stumpEmitter.position = SCNVector3(patchPos.x, soilY + 0.04, patchPos.z)
            let stumpFlames = makeFlames(sprite: materials.particleSprite)
            let stumpSmoke = makeSmoke(sprite: materials.particleSprite)
            stumpEmitter.addParticleSystem(stumpFlames)
            stumpEmitter.addParticleSystem(stumpSmoke)
            fireRoot.addChildNode(stumpEmitter)
            flameSystems.append(stumpFlames)
            smokeSystems.append(stumpSmoke)

            // 2. Surrounding wild-grass bed fire emitters so the undergrowth catches fire too
            let patchAngle = atan2(patchPos.x, -patchPos.z)
            for g in 0..<2 {
                let grassFireAngle = patchAngle + (g == 0 ? -0.24 : 0.26)
                let grassFireRadius: Float = g == 0 ? 1.38 : 1.68
                let gx = sin(grassFireAngle) * grassFireRadius
                let gz = -cos(grassFireAngle) * grassFireRadius

                let grassEmitter = SCNNode()
                grassEmitter.position = SCNVector3(gx, soilY + 0.03, gz)
                let grassFlames = makeFlames(sprite: materials.particleSprite)
                let grassSmoke = makeSmoke(sprite: materials.particleSprite)
                grassEmitter.addParticleSystem(grassFlames)
                grassEmitter.addParticleSystem(grassSmoke)
                fireRoot.addChildNode(grassEmitter)
                flameSystems.append(grassFlames)
                smokeSystems.append(grassSmoke)
            }

            // 3. HomeView-matched glowing ember spheres rising from both stump & grass
            for e in 0..<4 {
                let phase = Float(patchIndex * 4 + e) * 0.785
                let offsetAngle = Float(e) * 1.57 + Float(patchIndex) * 0.6
                let dist: Float = e < 2 ? 0.12 : 0.42
                let baseX = patchPos.x + cos(offsetAngle) * dist
                let baseZ = patchPos.z + sin(offsetAngle) * dist

                let sphere = SCNSphere(radius: 0.022)
                sphere.segmentCount = 8
                let mat = SCNMaterial()
                mat.lightingModel = .physicallyBased
                mat.diffuse.contents = UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1)
                mat.emission.contents = UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1)
                mat.emission.intensity = 2.0
                mat.roughness.contents = 0.3
                mat.metalness.contents = 0.0
                sphere.materials = [mat]

                let emberNode = SCNNode(geometry: sphere)
                emberNode.name = "ember_\(patchIndex)_\(e)"
                emberNode.position = SCNVector3(baseX, soilY + 0.06, baseZ)
                emberNode.opacity = 0
                emberNode.isHidden = true
                fireRoot.addChildNode(emberNode)
                emberNodes.append((node: emberNode, baseX: baseX, baseZ: baseZ, phase: phase, patchIndex: patchIndex))
            }

            // 4. HomeView-matched dark ash clods left behind across burned stumps & grass
            for c in 0..<5 {
                let cAngle = Float(patchIndex * 5 + c) * 1.047
                let dist: Float = 0.08 + Float(c % 3) * 0.16
                let sphere = SCNSphere(radius: 0.026)
                sphere.segmentCount = 8
                let mat = SCNMaterial()
                mat.lightingModel = .lambert
                mat.diffuse.contents = UIColor(red: 0.14, green: 0.10, blue: 0.08, alpha: 1)
                mat.roughness.contents = 0.98
                sphere.materials = [mat]

                let clod = SCNNode(geometry: sphere)
                clod.position = SCNVector3(
                    patchPos.x + cos(cAngle) * dist,
                    soilY,
                    patchPos.z + sin(cAngle) * dist
                )
                clod.opacity = 0
                clod.isHidden = true
                ashRoot.addChildNode(clod)
                ashNodes.append(clod)
            }
        }
    }

    // MARK: - User Interactions (Tap to Cut Tree, Pan & Motion to Look 360°, Ignite & Burn)

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        guard let view, stage == .clearing else { return }
        let location = gesture.location(in: view)
        let hits = view.hitTest(location, options: [
            SCNHitTestOption.boundingBoxOnly: true,
            SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue
        ])
        for hit in hits {
            var current: SCNNode? = hit.node
            while let node = current {
                if let name = node.name, name.hasPrefix("patch-"),
                   let index = Int(name.dropFirst(6)) {
                    interact(index)
                    return
                }
                current = node.parent
            }
        }
    }

    func interact(_ index: Int) {
        guard stage == .clearing,
              (0..<6).contains(index),
              completed.insert(index).inserted else { return }

        feedback.impactOccurred(intensity: 0.65)
        treeCutStartTimes[index] = CACurrentMediaTime()

        if reduceMotion, treeEntries.indices.contains(index) {
            applyTreeFallState(index: index, fallT: 1.0)
        }

        count = completed.count
        onCut?(index)
        if count == 6 {
            stage = .prepared
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        return abs(velocity.x) > abs(velocity.y)
    }

    @objc private func lookAround(_ gesture: UIPanGestureRecognizer) {
        guard let view else { return }
        let movement = gesture.translation(in: view)
        yaw -= Float(movement.x) * 0.005
        pitch = min(0.75, max(-0.95, pitch + Float(movement.y) * 0.005))
        gesture.setTranslation(.zero, in: view)
        updatePreviewCamera()
    }

    func beginMotionLook() {
        motionReference = motionOrientation
    }

    func applyMotionLook(_ relative: simd_quatf) {
        guard !suspended else { return }
        motionOrientation = simd_normalize(motionReference * relative)
        updatePreviewCamera()
    }

    func recenterLook() {
        yaw = 0
        pitch = -0.14
        motionOrientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        motionReference = motionOrientation
        updatePreviewCamera()
    }

    private func updatePreviewCamera() {
        let combinedOrientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            * simd_quatf(angle: pitch, axis: [1, 0, 0])
            * motionOrientation
        cameraNode.simdOrientation = combinedOrientation

        let forward = combinedOrientation.act(SIMD3<Float>(0, 0, -1))
        let parallaxOffset = SIMD3<Float>(-forward.x * 0.14, 0, -forward.z * 0.10)
        cameraNode.simdPosition = SIMD3<Float>(0, 0.54, 0) + parallaxOffset
    }

    // MARK: - Burning & Frame Update Loop

    func ignite() {
        guard stage == .prepared else { return }
        elapsed = 0
        stage = .burning
        if reduceMotion {
            finishBurn()
            return
        }
        startAudio()
        feedback.impactOccurred()
    }

    private func startAudio() {
        guard let url = audioURL ?? Bundle.main.url(forResource: "ngahuma-fire", withExtension: "wav"),
              audioPlayer == nil else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = muted ? 0 : 0.45
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            audioPlayer = nil
        }
    }

    private func advanceFrame(_ link: CADisplayLink) {
        let dt = lastFrameTimestamp == 0 ? 1.0 / 60.0 : min(link.timestamp - lastFrameTimestamp, 0.1)
        lastFrameTimestamp = link.timestamp
        update(dt)
    }

    private func update(_ delta: Double) {
        guard !suspended else { return }
        windTime += Float(min(delta, 0.1))
        let now = CACurrentMediaTime()

        // 1. Update HomeView tree wind shader & individual falling animations
        for index in treeEntries.indices {
            let fallT: Float
            if let cutStart = treeCutStartTimes[index] {
                let duration: Double = reduceMotion ? 0.01 : 0.95
                fallT = Float(min(1.0, max(0.0, (now - cutStart) / duration)))
            } else {
                fallT = 0
            }
            applyTreeFallState(index: index, fallT: fallT)
        }

        // 2. Update burning choreography
        guard stage == .burning else { return }

        if audioPlayer?.isPlaying == false && !muted {
            audioPlayer?.play()
        }

        elapsed += min(delta, 0.1)
        progress = min(elapsed / 18.0, 1.0)

        let activePatch = min(5, max(0, Int(elapsed / 0.85)))
        if patchPositions.indices.contains(activePatch) {
            let pos = patchPositions[activePatch]
            fireGlowNode.position = SCNVector3(pos.x, soilY + 0.35, pos.z)
        }

        let flicker = 0.90 + 0.06 * sin(windTime * 8.2) + 0.04 * sin(windTime * 14.5)
        var overallFireIntensity = Float(min(1.0, elapsed / 1.5)) * flicker * 180.0
        if elapsed > 14.0 {
            overallFireIntensity *= Float(max(0.0, (17.5 - elapsed) / 3.5))
        }
        fireLight.intensity = CGFloat(overallFireIntensity)

        for index in 0..<6 {
            let localTime = elapsed - Double(index) * 0.85
            let isBurningPatch = localTime > 0 && localTime < 7.5
            let isSmokingPatch = localTime > 0 && localTime < 11.0

            // Each patch owns 3 emitters (1 stump + 2 surrounding wild-grass emitters)
            let baseEmitterIdx = index * 3
            for sub in 0..<3 {
                let sysIdx = baseEmitterIdx + sub
                let subDelay = Double(sub) * 0.25
                let subBurn = (localTime - subDelay) > 0 && (localTime - subDelay) < 7.5
                let subSmoke = (localTime - subDelay) > 0 && (localTime - subDelay) < 11.0
                if flameSystems.indices.contains(sysIdx) {
                    flameSystems[sysIdx].birthRate = (subBurn && !reduceMotion && isBurningPatch) ? 32 : 0
                }
                if smokeSystems.indices.contains(sysIdx) {
                    smokeSystems[sysIdx].birthRate = (subSmoke && !reduceMotion && isSmokingPatch) ? 14 : 0
                }
            }

            if localTime > 0 && localTime < 3.5 {
                let burnFraction = Float(min(1.0, localTime / 3.5))
                let charShade = CGFloat(1.0 - burnFraction * 0.82)
                if treeEntries.indices.contains(index) {
                    let rootAnchor = treeEntries[index].rootAnchor
                    rootAnchor.childNodes.forEach { child in
                        child.geometry?.materials.forEach { $0.multiply.contents = UIColor(white: charShade, alpha: 1) }
                    }
                    rootAnchor.opacity = CGFloat(max(0.0, 1.0 - burnFraction * 0.90))
                }
            } else if localTime >= 3.5, charredPatches.insert(index).inserted {
                if treeEntries.indices.contains(index) {
                    treeEntries[index].rootAnchor.opacity = 0
                    treeEntries[index].rootAnchor.isHidden = true
                    treeEntries[index].trunk.opacity = 0
                    treeEntries[index].trunk.isHidden = true
                    treeEntries[index].shadow.opacity = 0
                    treeEntries[index].directionalShadow.opacity = 0
                    treeEntries[index].directionalShadow.isHidden = true
                }
            }
        }

        for ember in emberNodes {
            let localTime = elapsed - Double(ember.patchIndex) * 0.85
            let active = localTime > 0 && localTime < 8.0
            let fireT: Float = active ? Float(min(1.0, localTime / 1.0) * max(0.0, (8.0 - localTime) / 2.5)) : 0
            ember.node.opacity = CGFloat(fireT * 0.72)
            ember.node.isHidden = fireT < 0.02
            if active {
                let phase = ember.phase
                ember.node.position = SCNVector3(
                    ember.baseX + sin(windTime * 2.1 + phase) * 0.035,
                    soilY + 0.06 + abs(sin(windTime * 1.8 + phase)) * 0.24 * fireT,
                    ember.baseZ + cos(windTime * 1.5 + phase) * 0.035
                )
                // Warm emission pulse matching HomeView (SceneKitCropView lines 1420-1422)
                let emitG = Float(0.4 + 0.3 * abs(sin(windTime + phase)))
                ember.node.geometry?.firstMaterial?.emission.contents =
                    UIColor(red: 1.0, green: CGFloat(emitG), blue: 0, alpha: 1)
            }
        }

        let globalBurnT = Float(min(1.0, max(0.0, elapsed / 12.0)))

        // Char, shrivel, and burn away the wild grass blades across the clearing (matching HomeView)
        for (bladeIdx, blade) in blades.enumerated() {
            let stagger = Float(bladeIdx % 6) * 0.08
            let bladeBurnT = min(1.0, max(0.0, (globalBurnT - stagger) / max(0.1, 0.72 - stagger)))
            if bladeBurnT > 0.001 {
                if bladeBurnT < 0.45 {
                    // Scorching amber-brown phase as flames engulf the grass blade
                    let t = bladeBurnT / 0.45
                    blade.pivot.geometry?.firstMaterial?.multiply.contents = UIColor(
                        red: CGFloat(0.96 - t * 0.16),
                        green: CGFloat(0.96 - t * 0.56),
                        blue: CGFloat(0.96 - t * 0.84),
                        alpha: 1
                    )
                } else {
                    // Deep charcoal blackening & curling into ash
                    let t = (bladeBurnT - 0.45) / 0.55
                    blade.pivot.geometry?.firstMaterial?.multiply.contents = UIColor(
                        red: CGFloat(0.80 - t * 0.70),
                        green: CGFloat(0.40 - t * 0.33),
                        blue: CGFloat(0.12 - t * 0.07),
                        alpha: 1
                    )
                }
                let shrinkY = max(0.18, 1.0 - bladeBurnT * 0.82)
                blade.pivot.scale = SCNVector3(1.0, shrinkY, 1.0)
            }
        }

        if let groundMat = groundMaterial {
            let soilRGB = SIMD3<Float>(1.0, 1.0, 1.0)
            let charRGB = SIMD3<Float>(0.36, 0.28, 0.22)
            let mixed = simd_mix(soilRGB, charRGB, SIMD3<Float>(repeating: globalBurnT))
            groundMat.multiply.contents = UIColor(
                red: CGFloat(mixed.x),
                green: CGFloat(mixed.y),
                blue: CGFloat(mixed.z),
                alpha: 1
            )
        }
        let ashAlpha = CGFloat(min(1.0, max(0.0, (elapsed - 2.2) / 4.5)))
        for clod in ashNodes {
            clod.opacity = ashAlpha
            clod.isHidden = ashAlpha < 0.01
        }
        // Match HomeView (SceneKitCropView line 1302): wild grass completely burns away into ash
        let grassFade = max(0.0, 1.0 - smoothstep(0.35, 0.88, globalBurnT))
        wildRoot.opacity = CGFloat(grassFade)
        wildRoot.isHidden = grassFade < 0.005

        if elapsed >= 18.0 {
            finishBurn()
        }
    }

    private func applyTreeFallState(index: Int, fallT: Float) {
        guard treeEntries.indices.contains(index) else { return }
        let entry = treeEntries[index]
        let trunk = entry.trunk

        let contactTime: Float = 0.84
        let groundAngle: Float = 1.49
        // Reveal both the standing stump's split wood cross-section (baseFracture)
        // and the falling trunk's cross-section (fallingFracture) as the tree splits.
        let fractureReveal = smoothstep(0.06, 0.22, fallT)
        entry.baseFracture.opacity = CGFloat(fractureReveal)
        entry.fallingFracture.opacity = CGFloat(fractureReveal)

        if fallT >= 0.16 && !crackedTrees.contains(index) {
            crackedTrees.insert(index)
            if !reduceMotion {
                let cutWorldPos = SCNVector3(
                    entry.worldBasePosition.x,
                    soilY + entry.pivotOrigin.y,
                    entry.worldBasePosition.z
                )
                emitCutSplinters(at: cutWorldPos)
            }
        }

        let release = smoothstep(0, 0.10, fallT) * 0.012
        let descent = max(0, min(1, (fallT - 0.10) / (contactTime - 0.10)))
        let angle = release + (groundAngle - 0.012) * descent * descent

        trunk.eulerAngles.x = angle * 0.34
        trunk.eulerAngles.z = -angle * 0.94 * entry.fallDirection
        trunk.position = entry.pivotOrigin

        // Fade only the fallen upper trunk after ground impact while keeping
        // entry.rootAnchor + entry.baseFracture (the split stump) standing!
        let upperTreeFade = 1.0 - smoothstep(contactTime, 0.98, fallT)
        if !charredPatches.contains(index) {
            trunk.opacity = CGFloat(upperTreeFade)
            trunk.isHidden = upperTreeFade < 0.005
            entry.rootAnchor.opacity = 1.0
            entry.rootAnchor.isHidden = false
        }

        if let materials = entry.canopy.childNode(withName: "treeSilhouette", recursively: false)?.geometry?.materials {
            for material in materials {
                material.setValue(windTime + Float(index) * 1.37, forKey: "treeWindTime")
                material.setValue((!reduceMotion && !suspended) ? Float(0.0038) * (1 - descent) : Float(0), forKey: "treeWindAmplitude")
                material.setValue(Float(0), forKey: "treeCrownBlend")
                material.setValue(smoothstep(0.10, 0.45, fallT), forKey: "rootSeparation")
            }
            materials.last?.transparency = 0
        }

        let reachX = abs(sin(trunk.eulerAngles.z)) * 0.32 * trunk.scale.y
        let reachZ = abs(sin(trunk.eulerAngles.x)) * 0.32 * trunk.scale.y
        let signX: Float = trunk.eulerAngles.z >= 0 ? 1 : -1
        let signZ: Float = trunk.eulerAngles.x >= 0 ? 1 : -1
        entry.shadow.opacity = 0
        entry.directionalShadow.opacity = 0
        entry.directionalShadow.isHidden = true

        if fallT >= contactTime && !impactedTrees.contains(index) {
            impactedTrees.insert(index)
            if !reduceMotion {
                let impactWorld = entry.holder.convertPosition(
                    SCNVector3(reachX * signX, 0.002, reachZ * signZ),
                    to: worldRoot
                )
                emitDust(at: impactWorld)
                emitTreeDebris(at: impactWorld, phase: Float(index) * 0.73)
            }
        }
    }

    func finishBurn() {
        guard stage == .burning else { return }
        fireLight.intensity = 0
        flameSystems.forEach { $0.birthRate = 0 }
        smokeSystems.forEach { $0.birthRate = 0 }
        emberNodes.forEach {
            $0.node.opacity = 0
            $0.node.isHidden = true
        }
        for entry in treeEntries {
            entry.trunk.opacity = 0
            entry.trunk.isHidden = true
            entry.rootAnchor.opacity = 0
            entry.rootAnchor.isHidden = true
            entry.shadow.opacity = 0
            entry.directionalShadow.opacity = 0
            entry.directionalShadow.isHidden = true
        }
        groundMaterial?.multiply.contents = UIColor(red: 0.36, green: 0.28, blue: 0.22, alpha: 1)
        for clod in ashNodes {
            clod.opacity = 1
            clod.isHidden = false
        }
        wildRoot.opacity = 0
        wildRoot.isHidden = true

        audioPlayer?.stop()
        audioPlayer = nil
        completed.removeAll()
        count = 0
        progress = 1
        stage = .complete
        onBurnFinished?()
    }

    func reset() {
        audioPlayer?.stop()
        audioPlayer = nil
        completed.removeAll()
        count = 0
        progress = 0
        elapsed = 0
        stage = .entering
        tracking = "Menyiapkan lingkungan 360°. Geser layar untuk melihat sekeliling."
        if materials != nil {
            buildScene()
        }
    }

    func setSuspended(_ value: Bool) {
        suspended = value
        displayLink?.isPaused = value
        view?.isPlaying = !value
        updateWindState()
        if value {
            audioPlayer?.pause()
        }
    }

    func interactWithNextPlot() {
        if let next = (0..<6).first(where: { !completed.contains($0) }) {
            interact(next)
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        audioPlayer?.stop()
        audioPlayer = nil
        if let pan { view?.removeGestureRecognizer(pan) }
        pan = nil
        if let tap { view?.removeGestureRecognizer(tap) }
        tap = nil
        view?.isPlaying = false
        view = nil
    }

    // MARK: - HomeView Geometry & Particle Builders (Full Root-to-Crown Split Mesh)

    /// Builds a 3D relief tree section covering `startRow..<endRow` (out of 40 vertical rows).
    /// - Rows `0..<6` form the rooted base/flare (`rootAnchor`) sitting flush at `y = 0` (`soilY`).
    /// - Rows `6..<40` form the upper trunk and crown (`pivot`) that splits off at `y = cutHeight`.
    private func makeTreeSectionGeometry(
        from image: UIImage,
        startRow: Int,
        endRow: Int,
        includeWind: Bool
    ) -> SCNGeometry {
        let size = 192
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let cg = image.cgImage else { return }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        func opaque(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, y >= 0, x < size, y < size else { return false }
            return pixels[((size - 1 - y) * size + x) * 4 + 3] > 180
        }
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

        let width: Float = 0.35, height: Float = 0.56
        // Map v=0.012 (the exact bottom-most opaque root pixel of HumaTreeNatural) to y=0.0
        // so the tree roots touch the ground directly without floating or sinking below soilY.
        let vBottomTrim: Float = 0.012
        func mapUVV(_ v: Float) -> Float {
            vBottomTrim + v * (1.0 - vBottomTrim)
        }

        for row in startRow..<endRow {
            for column in 0..<32 {
                let u0 = Float(column) / 32, u1 = Float(column + 1) / 32
                let v0 = Float(row) / 40, v1 = Float(row + 1) / 40
                let uvV0 = mapUVV(v0)
                let uvV1 = mapUVV(v1)
                quad(
                    [
                        SIMD3((u0 - 0.5) * width, v0 * height, 0),
                        SIMD3((u1 - 0.5) * width, v0 * height, 0),
                        SIMD3((u1 - 0.5) * width, v1 * height, 0),
                        SIMD3((u0 - 0.5) * width, v1 * height, 0)
                    ],
                    [
                        CGPoint(x: CGFloat(u0), y: CGFloat(1 - uvV0)),
                        CGPoint(x: CGFloat(u1), y: CGFloat(1 - uvV0)),
                        CGPoint(x: CGFloat(u1), y: CGFloat(1 - uvV1)),
                        CGPoint(x: CGFloat(u0), y: CGFloat(1 - uvV1))
                    ],
                    body: false
                )
            }
        }

        let startPixelY = Int(Float(startRow) / 40.0 * Float(size))
        let endPixelY = Int(Float(endRow) / 40.0 * Float(size))
        for y in startPixelY..<endPixelY {
            for x in 0..<size where occupied(x, y) {
                let u0 = Float(x) / Float(size), u1 = Float(x + 1) / Float(size)
                let v0 = Float(y) / Float(size), v1 = Float(y + 1) / Float(size)
                let uvV0 = mapUVV(v0)
                let uvV1 = mapUVV(v1)
                let d: Float = v0 > 0.60 ? 0.045 : 0.012
                let a = SIMD3<Float>((u0 - 0.5) * width, v0 * height, 0)
                let b = SIMD3<Float>((u1 - 0.5) * width, v0 * height, 0)
                let c = SIMD3<Float>((u1 - 0.5) * width, v1 * height, 0)
                let e = SIMD3<Float>((u0 - 0.5) * width, v1 * height, 0)
                let offset = SIMD3<Float>(0, includeWind ? (-0.24 * d) : 0, -d)
                let coords = [
                    CGPoint(x: CGFloat(u0), y: CGFloat(1 - uvV0)),
                    CGPoint(x: CGFloat(u1), y: CGFloat(1 - uvV0)),
                    CGPoint(x: CGFloat(u1), y: CGFloat(1 - uvV1)),
                    CGPoint(x: CGFloat(u0), y: CGFloat(1 - uvV1))
                ]
                let rear = coords.map {
                    CGPoint(x: $0.x * 0.92 + 0.04, y: max(0, $0.y - CGFloat(d / height)))
                }
                quad([e + offset, c + offset, b + offset, a + offset], coords.reversed(), body: true)
                if !occupied(x - 1, y) { quad([a, e, e + offset, a + offset], [coords[0], coords[3], rear[3], rear[0]], body: true) }
                if !occupied(x + 1, y) { quad([c, b, b + offset, c + offset], [coords[2], coords[1], rear[1], rear[2]], body: true) }
                if !occupied(x, y - 1) { quad([b, a, a + offset, b + offset], [coords[1], coords[0], rear[0], rear[1]], body: true) }
                if !occupied(x, y + 1) { quad([e, c, c + offset, e + offset], [coords[3], coords[2], rear[2], rear[3]], body: true) }
            }
        }

        let front = SCNMaterial()
        front.lightingModel = .constant
        front.diffuse.contents = image
        front.multiply.contents = UIColor(red: 1.48, green: 1.45, blue: 1.38, alpha: 1)
        front.isDoubleSided = true
        front.transparencyMode = .aOne
        front.writesToDepthBuffer = true
        if includeWind {
            front.shaderModifiers = [.geometry: """
            #pragma arguments
            float treeWindTime;
            float treeWindAmplitude;
            float treeCrownBlend;
            #pragma body
            float3 rest = _geometry.position.xyz;
            float crown = smoothstep(0.255, 0.355, rest.y);
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
            float crownMask = 1.0 - smoothstep(0.42, 0.55, _surface.diffuseTexcoord.y);
            _output.color.a *= 1.0 - treeCrownBlend * crownMask;
            if (_output.color.a < 0.08) { discard_fragment(); }
            """]
            front.setValue(Float(0), forKey: "treeWindTime")
            front.setValue(Float(0), forKey: "treeWindAmplitude")
            front.setValue(Float(0), forKey: "treeCrownBlend")
            front.setValue(Float(0), forKey: "rootSeparation")
        } else {
            front.shaderModifiers = [.fragment: """
            #pragma transparent
            #pragma body
            if (_output.color.a < 0.08) { discard_fragment(); }
            """]
        }
        NgahumaMaterials.smoothTextureSampling(front.diffuse)

        let body = front.copy() as! SCNMaterial
        body.lightingModel = .constant
        body.multiply.contents = UIColor(red: 1.15, green: 1.12, blue: 1.05, alpha: 1)
        body.isDoubleSided = true
        body.transparency = 0
        if includeWind {
            body.setValue(Float(0), forKey: "treeCrownBlend")
        }

        let geometry = SCNGeometry(
            sources: [
                .init(vertices: vertices),
                .init(normals: normals),
                .init(textureCoordinates: uv)
            ],
            elements: [
                .init(indices: frontIndices, primitiveType: .triangles),
                .init(indices: bodyIndices, primitiveType: .triangles)
            ]
        )
        geometry.materials = [front, body]
        return geometry
    }

    private func makeRadialCrownGeometry() -> SCNGeometry {
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
                0.355 + 0.085 * (1 - radial / 0.115) + sin(fi * 1.71) * 0.018,
                -0.050 + sin(a) * radial * 0.72 + cos(fi * 2.17) * 0.012
            )
            let rx = 0.050 + 0.012 * (0.5 + 0.5 * sin(fi * 1.53))
            let ry = 0.038 + 0.010 * (0.5 + 0.5 * cos(fi * 2.13))
            let rz = 0.048 + 0.014 * (0.5 + 0.5 * sin(fi * 2.77))
            let rotation = simd_quatf(angle: a + sin(fi * 2.01) * 0.30, axis: SIMD3<Float>(0, 1, 0))
                * simd_quatf(angle: sin(fi * 1.37) * 0.32, axis: SIMD3<Float>(1, 0, 0))
                * simd_quatf(angle: cos(fi * 2.41) * 0.28, axis: SIMD3<Float>(0, 0, 1))
            let base = UInt32(vertices.count)
            for ring in 0...rings {
                let theta = Float(ring) / Float(rings) * .pi
                for side in 0...sides {
                    let phi = Float(side) / Float(sides) * 2 * .pi
                    let unit = SIMD3<Float>(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
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

        return SCNGeometry(
            sources: [
                .init(vertices: vertices.map(SCNVector3.init)),
                .init(normals: normals.map(SCNVector3.init))
            ],
            elements: [.init(indices: indices, primitiveType: .triangles)]
        )
    }

    private func makeBladeGeometry(
        height: Float,
        width: Float,
        arch: Float,
        material: SCNMaterial
    ) -> SCNGeometry {
        let segments = 24
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var textureCoordinates: [CGPoint] = []
        var indices: [UInt32] = []

        for segment in 0...segments {
            let t = Float(segment) / Float(segments)
            let taper = max(0.08, sin(t * .pi) * (1 - t * 0.42))
            let halfWidth = width * 0.5 * taper
            let y = height * (t - 0.08 * t * t)
            let z = arch * t * t
            vertices.append(SCNVector3(-halfWidth, y, z))
            vertices.append(SCNVector3(halfWidth, y, z))
            let normal = simd_normalize(SIMD3<Float>(0, -2 * arch * t, height * (1 - 0.16 * t)))
            normals.append(SCNVector3(normal))
            normals.append(SCNVector3(normal))
            textureCoordinates.append(CGPoint(x: 0, y: CGFloat(t)))
            textureCoordinates.append(CGPoint(x: 1, y: CGFloat(t)))
            if segment < segments {
                let base = UInt32(segment * 2)
                indices += [base, base + 1, base + 2, base + 1, base + 3, base + 2]
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

    private func stumpMaterial(using materials: NgahumaMaterials) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = materials.woodTexture
        material.multiply.contents = UIColor(red: 1.25, green: 1.10, blue: 0.95, alpha: 1)
        material.roughness.contents = 1.0
        NgahumaMaterials.smoothTextureSampling(material.diffuse)
        return material
    }

    private func branch(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        radius: Float,
        material: SCNMaterial
    ) -> SCNNode {
        let vector = end - start
        let geometry = SCNCone(
            topRadius: CGFloat(radius * 0.8),
            bottomRadius: CGFloat(radius),
            height: CGFloat(simd_length(vector))
        )
        geometry.radialSegmentCount = 16
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.simdPosition = (start + end) * 0.5
        node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(vector))
        return node
    }

    private func makeFractureSurface(seed: Int) -> SCNNode {
        let root = SCNNode()
        let heartwood = SCNMaterial()
        heartwood.lightingModel = .lambert
        heartwood.diffuse.contents = UIColor(red: 0.72, green: 0.51, blue: 0.30, alpha: 1)
        heartwood.ambient.contents = UIColor(red: 0.40, green: 0.28, blue: 0.16, alpha: 1)
        heartwood.isDoubleSided = true

        let barkRim = SCNMaterial()
        barkRim.lightingModel = .lambert
        barkRim.diffuse.contents = UIColor(red: 0.46, green: 0.29, blue: 0.15, alpha: 1)
        barkRim.ambient.contents = UIColor(red: 0.26, green: 0.16, blue: 0.08, alpha: 1)
        barkRim.isDoubleSided = true

        let count = 14
        var vertices = [SCNVector3(0, 0.0015, 0)]
        var indices: [Int32] = []
        for i in 0..<count {
            let angle = Float(i) / Float(count) * .pi * 2
            let irregularity = 0.85 + 0.16 * sin(Float(i * 7 + seed))
            vertices.append(SCNVector3(
                cos(angle) * 0.013 * irregularity,
                0.0015 + 0.002 * sin(Float(i * 3 + seed)),
                sin(angle) * 0.008 * irregularity
            ))
            indices += [0, Int32(i + 1), Int32((i + 1) % count + 1)]
        }
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.materials = [heartwood]
        root.addChildNode(SCNNode(geometry: geometry))

        // Jagged splintered wood fibers around the split cut edge
        for i in 0..<8 {
            let angle = Float(i) * 2.39996 + Float(seed)
            let length = 0.0045 + Float(i % 3) * 0.0022
            let fiber = SCNCone(topRadius: 0, bottomRadius: 0.0012, height: CGFloat(length))
            fiber.materials = [i.isMultiple(of: 2) ? heartwood : barkRim]
            let node = SCNNode(geometry: fiber)
            node.position = SCNVector3(cos(angle) * 0.0085, length * 0.5, sin(angle) * 0.005)
            node.eulerAngles.z = sin(angle) * 0.28
            root.addChildNode(node)
        }
        return root
    }

    private func makeFlames(sprite: UIImage) -> SCNParticleSystem {
        let system = SCNParticleSystem()
        system.birthRate = 0
        system.particleLifeSpan = 0.65
        system.particleLifeSpanVariation = 0.15
        system.particleSize = 0.12
        system.particleSizeVariation = 0.04
        system.particleVelocity = 0.28
        system.particleVelocityVariation = 0.08
        system.emittingDirection = SCNVector3(0, 1, 0)
        system.spreadingAngle = 18
        system.acceleration = SCNVector3(0.025, 0.14, 0)
        system.emitterShape = SCNSphere(radius: 0.14)
        system.particleImage = sprite
        system.blendMode = .additive
        system.isLightingEnabled = false
        let color = CAKeyframeAnimation()
        color.values = [
            UIColor(red: 1, green: 0.95, blue: 0.55, alpha: 0.85),
            UIColor(red: 1, green: 0.48, blue: 0.04, alpha: 0.65),
            UIColor(red: 0.45, green: 0.06, blue: 0, alpha: 0)
        ]
        color.keyTimes = [0, 0.35, 1]
        system.propertyControllers = [.color: SCNParticlePropertyController(animation: color)]
        return system
    }

    private func makeSmoke(sprite: UIImage) -> SCNParticleSystem {
        let system = SCNParticleSystem()
        system.birthRate = 0
        system.particleLifeSpan = 2.0
        system.particleLifeSpanVariation = 0.4
        system.particleSize = 0.16
        system.particleSizeVariation = 0.05
        system.particleVelocity = 0.28
        system.particleVelocityVariation = 0.07
        system.emittingDirection = SCNVector3(0, 1, 0)
        system.spreadingAngle = 26
        system.acceleration = SCNVector3(0.04, 0.14, 0)
        system.emitterShape = SCNSphere(radius: 0.15)
        system.particleImage = sprite
        system.blendMode = .alpha
        system.isLightingEnabled = false
        let color = CAKeyframeAnimation()
        color.values = [
            UIColor(white: 0.42, alpha: 0.32),
            UIColor(white: 0.55, alpha: 0.18),
            UIColor(white: 0.68, alpha: 0.0)
        ]
        color.keyTimes = [0, 0.5, 1]
        system.propertyControllers = [.color: SCNParticlePropertyController(animation: color)]
        return system
    }

    private func emitCutSplinters(at position: SCNVector3) {
        guard let materials else { return }
        let node = SCNNode()
        node.position = position
        let particles = SCNParticleSystem()
        particles.loops = false
        particles.emissionDuration = 0.06
        particles.birthRate = 55
        particles.particleLifeSpan = 0.45
        particles.particleSize = 0.008
        particles.particleSizeVariation = 0.003
        particles.particleVelocity = 0.11
        particles.particleVelocityVariation = 0.04
        particles.emittingDirection = SCNVector3(1, 0.3, 0)
        particles.spreadingAngle = 65
        particles.acceleration = SCNVector3(0, -0.35, 0)
        particles.particleImage = materials.woodSplinterSprite
        particles.particleColor = .white
        particles.isLightingEnabled = false
        particles.blendMode = .alpha
        node.addParticleSystem(particles)
        worldRoot.addChildNode(node)
        node.runAction(.sequence([.wait(duration: 0.8), .removeFromParentNode()]))
    }

    private func emitDust(at position: SCNVector3) {
        guard let materials else { return }
        let node = SCNNode()
        node.position = position
        let dust = SCNParticleSystem()
        dust.loops = false
        dust.emissionDuration = 0.1
        dust.birthRate = 78
        dust.particleLifeSpan = 0.65
        dust.particleSize = 0.015
        dust.particleVelocity = 0.12
        dust.spreadingAngle = 80
        dust.emittingDirection = SCNVector3(0, 1, 0)
        dust.particleColor = UIColor(red: 0.45, green: 0.33, blue: 0.20, alpha: 0.35)
        dust.particleImage = materials.particleSprite
        dust.blendMode = .alpha
        let fade = CABasicAnimation()
        fade.fromValue = 0.35
        fade.toValue = 0
        dust.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]
        node.addParticleSystem(dust)
        worldRoot.addChildNode(node)
        node.runAction(.sequence([.wait(duration: 1.2), .removeFromParentNode()]))
    }

    private func emitTreeDebris(at position: SCNVector3, phase: Float) {
        guard let materials else { return }
        let splintersNode = SCNNode()
        splintersNode.position = SCNVector3(position.x, position.y + 0.025, position.z)
        let splinters = SCNParticleSystem()
        splinters.loops = false
        splinters.emissionDuration = 0.08
        splinters.birthRate = 36
        splinters.particleLifeSpan = 1.15
        splinters.particleLifeSpanVariation = 0.28
        splinters.particleSize = 0.016
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
        splinters.particleImage = materials.woodSplinterSprite
        splinters.blendMode = .alpha
        splinters.isLightingEnabled = true
        splintersNode.addParticleSystem(splinters)
        worldRoot.addChildNode(splintersNode)
        splintersNode.runAction(.sequence([.wait(duration: 2.2), .removeFromParentNode()]))

        let chipsNode = SCNNode()
        chipsNode.position = SCNVector3(position.x, position.y + 0.018, position.z)
        let chips = SCNParticleSystem()
        chips.loops = false
        chips.emissionDuration = 0.045
        chips.birthRate = 16
        chips.particleLifeSpan = 0.68
        chips.particleLifeSpanVariation = 0.18
        chips.particleSize = 0.011
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
        chips.particleImage = materials.woodChipSprite
        chips.blendMode = .alpha
        chips.isLightingEnabled = true
        chipsNode.addParticleSystem(chips)
        worldRoot.addChildNode(chipsNode)
        chipsNode.runAction(.sequence([.wait(duration: 1.8), .removeFromParentNode()]))
    }

    private func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
        let t = max(0, min(1, (value - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
}
