//
//  RiceCropRealityView.swift
//  PoCPadi
//
//  RealityKit 3D scene for BeBaduy with natural low-profile agricultural ground.
//  Renders the 4-step huma agricultural transformation:
//  - Step 1 (Nukuh): Uncultivated ground with procedural wild grass & weeds
//  - Step 2 (Ngaseuk): Cleared soil with traditional dibble holes (lubang aseuk) & young sprouts
//  - Step 3 (Ngored): Lush tall green vegetative rice clump
//  - Step 4 (Dibuat): Mature golden rice with heavy drooping panicles
//

import SwiftUI
import RealityKit

struct RiceCropRealityView: View {
    /// Normalized growth progress value [0.0 ... 1.0]
    let progress: CGFloat
    var isActive = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var wind: VegetationPhysics?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        RealityView { content in
            content.camera = .virtual
            
            let sceneRoot = Entity()
            sceneRoot.name = "cropSceneRoot"
            content.add(sceneRoot)
            
            // MARK: - 1. Virtual Perspective Camera
            let camera = PerspectiveCamera()
            camera.name = "mainCamera"
            camera.camera.fieldOfViewInDegrees = 38
            // Positioned at eye level looking across the low-profile agricultural plot
            camera.position = [0, 0.52, 1.75]
            camera.look(at: [0, 0.10, 0], from: camera.position, relativeTo: nil)
            sceneRoot.addChild(camera)
            
            // MARK: - 2. Cinematic Sunset Three-Point Lighting
            let sun = DirectionalLight()
            sun.name = "sunKeyLight"
            sun.light.intensity = 3800
            sun.light.color = UIColor(red: 1.0, green: 0.90, blue: 0.68, alpha: 1.0)
            sun.shadow = DirectionalLightComponent.Shadow()
            sun.look(at: [0, 0.10, 0], from: [2.2, 3.4, 1.5], relativeTo: nil)
            sceneRoot.addChild(sun)
            
            let rimLight = DirectionalLight()
            rimLight.name = "sunRimLight"
            rimLight.light.intensity = 2600
            rimLight.light.color = UIColor(red: 1.0, green: 0.62, blue: 0.32, alpha: 1.0)
            rimLight.look(at: [0, 0.15, 0], from: [-0.6, 2.2, -2.5], relativeTo: nil)
            sceneRoot.addChild(rimLight)
            
            let fillLight = PointLight()
            fillLight.name = "earthFillLight"
            fillLight.light.intensity = 650
            fillLight.light.color = UIColor(red: 0.88, green: 0.60, blue: 0.42, alpha: 1.0)
            fillLight.light.attenuationRadius = 4.0
            fillLight.position = [0, 0.15, 0.85]
            sceneRoot.addChild(fillLight)
            
            // MARK: - 3. Load Photographic Textures
            let terrainTexture = try? await TextureResource(named: "HumaTerrainTexture")
            let grassTexture = try? await TextureResource(named: "HumaGrassTexture")
            
            // MARK: - 4. Natural Low-Profile Flat-Topped Agricultural Plot
            let groundPlotEntity = Entity()
            groundPlotEntity.name = "groundPlot"
            groundPlotEntity.position = [0, 0, 0]
            
            var plotMaterial = PhysicallyBasedMaterial()
            plotMaterial.faceCulling = .none
            plotMaterial.roughness = .init(floatLiteral: 0.96)
            if let terrainTex = terrainTexture {
                // Tint to seamlessly match the reddish-brown Kanekes earth path
                plotMaterial.baseColor = .init(
                    tint: UIColor(red: 0.65, green: 0.48, blue: 0.36, alpha: 1.0),
                    texture: ProceduralRiceBuilder.filteredTexture(terrainTex)
                )
                plotMaterial.textureCoordinateTransform = .init(scale: [2.25, 2.25])
            } else {
                plotMaterial.baseColor = .init(tint: UIColor(red: 0.30, green: 0.18, blue: 0.11, alpha: 1.0))
            }
            
            if let plotMesh = try? ProceduralRiceBuilder.makeLowProfilePlotMesh(radius: 0.52, peakHeight: 0.038) {
                let plotModel = ModelEntity(mesh: plotMesh, materials: [plotMaterial])
                groundPlotEntity.addChild(plotModel)
            }
            sceneRoot.addChild(groundPlotEntity)
            
            // MARK: - 5. Step 1 (NUKUH): Wild Grass & Uncultivated Weeds Entity
            let wildWeedsRoot = Entity()
            wildWeedsRoot.name = "wildWeedsRoot"
            ProceduralRiceBuilder.buildWildWeeds(parent: wildWeedsRoot, grassTexture: grassTexture)
            sceneRoot.addChild(wildWeedsRoot)
            
            // MARK: - 6. Step 2 (NGASEUK): Dibble Stick Holes & Sprouts Entity
            let plantingHolesRoot = Entity()
            plantingHolesRoot.name = "plantingHolesRoot"
            ProceduralRiceBuilder.buildPlantingHoles(parent: plantingHolesRoot, grassTexture: grassTexture)
            sceneRoot.addChild(plantingHolesRoot)
            
            // MARK: - 7. Steps 3 & 4 (NGORED & DIBUAT): Full Growing Rice Clump Entity
            let plantRoot = Entity()
            plantRoot.name = "ricePlantRoot"
            plantRoot.position = [0, 0.035, 0] // Sits directly atop the flat-topped plot
            
            let leavesRoot = Entity()
            leavesRoot.name = "leavesRoot"
            
            let meshTier1 = try? ProceduralRiceBuilder.makeRiceBladeMesh(length: 0.40, arch: 0.08)
            let meshTier2 = try? ProceduralRiceBuilder.makeRiceBladeMesh(length: 0.46, arch: 0.12)
            let meshTier3 = try? ProceduralRiceBuilder.makeRiceBladeMesh(length: 0.52, arch: 0.18)
            let meshTier4 = try? ProceduralRiceBuilder.makeRiceBladeMesh(length: 0.56, arch: 0.24)
            
            let tiers: [(count: Int, mesh: MeshResource?, spreadAngle: Float, lengthScale: Float)] = [
                (count: 6, mesh: meshTier1, spreadAngle: 0.11, lengthScale: 0.86),
                (count: 8, mesh: meshTier2, spreadAngle: 0.22, lengthScale: 0.95),
                (count: 8, mesh: meshTier3, spreadAngle: 0.36, lengthScale: 1.02),
                (count: 8, mesh: meshTier4, spreadAngle: 0.48, lengthScale: 1.06)
            ]
            
            var bladeGlobalIndex = 0
            for tier in tiers {
                guard let mesh = tier.mesh else { continue }
                let angleStep: Float = (2.0 * Float.pi) / Float(tier.count)
                for i in 0..<tier.count {
                    var bladeMaterial = PhysicallyBasedMaterial()
                    bladeMaterial.faceCulling = .none
                    bladeMaterial.roughness = .init(floatLiteral: 0.84)
                    
                    if let grassTex = grassTexture {
                        bladeMaterial.baseColor = .init(
                            tint: ProceduralRiceBuilder.interpolatedLeafColor(for: progress),
                            texture: ProceduralRiceBuilder.filteredTexture(grassTex)
                        )
                        let uOffset = Float(bladeGlobalIndex % 14) * 0.045
                        bladeMaterial.textureCoordinateTransform = .init(offset: [uOffset, 0.0], scale: [0.035, 1.0])
                    } else {
                        bladeMaterial.baseColor = .init(tint: ProceduralRiceBuilder.interpolatedLeafColor(for: progress))
                    }
                    
                    let leafModel = ModelEntity(mesh: mesh, materials: [bladeMaterial])
                    leafModel.name = "blade_\(bladeGlobalIndex)"
                    bladeGlobalIndex += 1
                    
                    let azimuth: Float = Float(i) * angleStep + Float(bladeGlobalIndex) * 0.22
                    let tilt: Float = tier.spreadAngle + Float((bladeGlobalIndex * 7) % 5) * 0.015
                    
                    let tiltQuat = simd_quatf(angle: tilt, axis: [1, 0, 0])
                    let rotYQuat = simd_quatf(angle: azimuth, axis: [0, 1, 0])
                    leafModel.orientation = rotYQuat * tiltQuat
                    leafModel.scale = SIMD3(repeating: tier.lengthScale)
                    leavesRoot.addChild(leafModel)
                }
            }
            plantRoot.addChild(leavesRoot)
            
            // Panicles (golden drooping grains) sub-hierarchy
            let paniclesRoot = Entity()
            paniclesRoot.name = "paniclesRoot"
            
            var grainMaterial = PhysicallyBasedMaterial()
            grainMaterial.roughness = .init(floatLiteral: 0.8)
            grainMaterial.metallic = .init(floatLiteral: 0)
            if let grassTex = grassTexture {
                grainMaterial.baseColor = .init(
                    tint: UIColor(red: 0.95, green: 0.78, blue: 0.22, alpha: 1.0),
                    texture: ProceduralRiceBuilder.filteredTexture(grassTex)
                )
                grainMaterial.textureCoordinateTransform = .init(scale: [0.04, 1.0])
            } else {
                grainMaterial.baseColor = .init(tint: UIColor(red: 0.95, green: 0.78, blue: 0.22, alpha: 1.0))
            }
            
            ProceduralRiceBuilder.buildPanicleCluster(paniclesRoot: paniclesRoot, grainMaterial: grainMaterial)
            plantRoot.addChild(paniclesRoot)
            
            sceneRoot.addChild(plantRoot)
            
            let physics = VegetationPhysics()
            physics.bind(Array(wildWeedsRoot.children), mass: 0.22)
            physics.bind(plantingHolesRoot.children.flatMap { $0.children.filter { $0.name == "sprout" } }, mass: 0.16)
            physics.bind(Array(leavesRoot.children), mass: 0.38)
            physics.bind(Array(paniclesRoot.children), mass: 0.65)
            physics.isPaused = reduceMotion || !isActive || scenePhase != .active
            wind = physics
            physics.subscription = content.subscribe(to: SceneEvents.Update.self) { [weak physics] event in
                physics?.advance(by: event.deltaTime)
            }

            // Initial state evaluation
            applyProgressUpdate(sceneRoot: sceneRoot, p: Float(progress))
        } update: { content in
            wind?.isPaused = reduceMotion || !isActive || scenePhase != .active
            if let sceneRoot = content.entities.first(where: { $0.name == "cropSceneRoot" }) {
                applyProgressUpdate(sceneRoot: sceneRoot, p: Float(progress))
            }
        }
        .onDisappear { wind?.isPaused = true }
    }
    
    // MARK: - Dynamic Step Progression Scrubbing
    
    /// Binds normalized progress [0.0 ... 1.0] across the 4 Baduy agricultural stages:
    /// - 0.00 ... 0.33: Step 1 (Nukuh) wild weeds dissolve -> Step 2 (Ngaseuk) dibble holes appear
    /// - 0.33 ... 0.66: Step 2 holes transition -> Step 3 (Ngored) lush green rice clump flourishes
    /// - 0.66 ... 1.00: Step 3 green rice -> Step 4 (Dibuat) golden harvest rice with drooping panicles
    private func applyProgressUpdate(sceneRoot: Entity, p: Float) {
        guard let wildWeedsRoot = sceneRoot.findEntity(named: "wildWeedsRoot"),
              let plantingHolesRoot = sceneRoot.findEntity(named: "plantingHolesRoot"),
              let plantRoot = sceneRoot.findEntity(named: "ricePlantRoot"),
              let leavesRoot = plantRoot.findEntity(named: "leavesRoot"),
              let paniclesRoot = plantRoot.findEntity(named: "paniclesRoot") else {
            return
        }
        
        let clampedP = min(1.0, max(0.0, p))
        
        // 1. Step 1 (NUKUH): Wild Weeds & Uncultivated Texture
        // Fully visible at 0.0, fades and shrinks to 0.001 as we move towards 0.30
        if clampedP <= 0.05 {
            wildWeedsRoot.scale = SIMD3(repeating: 1.0)
        } else if clampedP < 0.28 {
            let t = (clampedP - 0.05) / 0.23
            let weedScale = max(0.001, (1.0 - t))
            wildWeedsRoot.scale = [weedScale, weedScale * (1.0 - t * 0.5), weedScale]
        } else {
            wildWeedsRoot.scale = SIMD3(repeating: 0.001)
        }
        
        // 2. Step 2 (NGASEUK): Dibble Stick Holes & Emerging Sprouts
        // Appears as weeds clear (0.15 ... 0.33), then yields to mature clump after 0.45
        if clampedP < 0.12 {
            plantingHolesRoot.scale = SIMD3(repeating: 0.001)
        } else if clampedP <= 0.33 {
            let t = (clampedP - 0.12) / 0.21
            let s = max(0.001, t)
            plantingHolesRoot.scale = [s, s, s]
        } else if clampedP < 0.52 {
            let t = (clampedP - 0.33) / 0.19
            let s = max(0.001, 1.0 - t)
            plantingHolesRoot.scale = [s, s, s]
        } else {
            plantingHolesRoot.scale = SIMD3(repeating: 0.001)
        }
        
        // 3. Steps 3 & 4 (NGORED & DIBUAT): Rice Clump Growth & Transformation
        if clampedP < 0.26 {
            plantRoot.scale = SIMD3(repeating: 0.001)
            paniclesRoot.scale = SIMD3(repeating: 0.001)
        } else if clampedP < 0.66 {
            // Vegetative growth phase
            let t = (clampedP - 0.26) / 0.40
            let smoothT = t * t * (3.0 - 2.0 * t)
            let currentScale = 0.20 + smoothT * 0.78
            plantRoot.scale = [currentScale * 0.95, currentScale * 1.02, currentScale * 0.95]
            paniclesRoot.scale = SIMD3(repeating: 0.001)
        } else {
            // Maturing into golden harvest
            let t = (clampedP - 0.66) / 0.34
            let smoothT = t * t * (3.0 - 2.0 * t)
            let currentScale = 0.98 + smoothT * 0.06
            plantRoot.scale = [currentScale * 0.95, currentScale * 1.04, currentScale * 0.95]
            
            // Panicles emerge and droop with ripe golden grains
            let panicleScale = max(0.001, smoothT * 0.98)
            paniclesRoot.scale = SIMD3(repeating: panicleScale)
            let droopAngle = smoothT * 0.16
            paniclesRoot.orientation = simd_quatf(angle: droopAngle, axis: [1, 0, 0])
        }
        
        // 4. Leaf Material Color Scrubbing
        let leafColor = ProceduralRiceBuilder.interpolatedLeafColor(for: CGFloat(clampedP))
        for leaf in leavesRoot.children {
            if let model = leaf as? ModelEntity,
               var mat = model.model?.materials.first as? PhysicallyBasedMaterial {
                mat.baseColor = .init(tint: leafColor, texture: mat.baseColor.texture)
                model.model?.materials = [mat]
            }
        }
    }
}
