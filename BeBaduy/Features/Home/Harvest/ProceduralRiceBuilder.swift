//
//  ProceduralRiceBuilder.swift
//  PoCPadi
//
//  Procedural 3D geometry generator for BeBaduy in RealityKit.
//  Builds a low-profile flat-topped agricultural plot, scattered wild weeds (Step 1),
//  planting dibble holes with young sprouts (Step 2), and growing/golden rice crops (Steps 3 & 4).
//

import UIKit
import RealityKit
import simd

@MainActor
enum ProceduralRiceBuilder {
    
    static func filteredTexture(_ resource: TextureResource) -> MaterialParameters.Texture {
        var sampler = MaterialParameters.Texture.Sampler()
        sampler.modify {
            $0.minFilter = .linear
            $0.magFilter = .linear
            $0.mipFilter = .linear
            $0.maxAnisotropy = 8
            $0.sAddressMode = .repeat
            $0.tAddressMode = .repeat
        }
        return .init(resource, sampler: sampler)
    }

    // MARK: - 1. Low-Profile Natural Agricultural Plot (Flat-Topped Swidden Bed)
    
    /// Generates a natural, low-profile, flat-topped agricultural plot (huma ground surface)
    /// replacing steep mounds with a gentle, realistic soil bed that sits in the foreground.
    static func makeLowProfilePlotMesh(radius: Float = 0.52, peakHeight: Float = 0.038) throws -> MeshResource {
        let radialSegments = 14
        let angularSegments = 32
        
        var positions: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        
        // Apex vertex (center top)
        positions.append(SIMD3<Float>(0, peakHeight, 0))
        uvs.append(SIMD2<Float>(0.5, 0.5))
        
        // Concentric rings forming the flat-topped bed
        for r in 1...radialSegments {
            let normalizedR = Float(r) / Float(radialSegments)
            let ringRadius = radius * normalizedR
            // Flat-topped profile: broad level center that tapers gently at the rim
            let profile = max(0.0, 1.0 - pow(normalizedR, 3.2))
            let baseH = peakHeight * profile
            
            for a in 0..<angularSegments {
                let angle = (Float(a) / Float(angularSegments)) * 2.0 * .pi
                // Subtle organic soil micro-roughness
                let noise = (sin(angle * 3.0) * 0.003 + cos(angle * 5.0) * 0.002) * (1.0 - normalizedR * 0.5)
                let h = max(0.0005, baseH + noise)
                
                positions.append(SIMD3<Float>(cos(angle) * ringRadius, h, sin(angle) * ringRadius))
                uvs.append(SIMD2<Float>(0.5 + 0.5 * cos(angle) * normalizedR,
                                       0.5 + 0.5 * sin(angle) * normalizedR))
            }
        }
        
        // Center cap triangles
        for a in 0..<angularSegments {
            let current = UInt32(1 + a)
            let next = UInt32(1 + (a + 1) % angularSegments)
            indices.append(contentsOf: [0, next, current])
        }
        
        // Quad strips
        for r in 1..<radialSegments {
            let innerStart = UInt32(1 + (r - 1) * angularSegments)
            let outerStart = UInt32(1 + r * angularSegments)
            for a in 0..<angularSegments {
                let nextA = (a + 1) % angularSegments
                let i0 = innerStart + UInt32(a)
                let i1 = innerStart + UInt32(nextA)
                let o0 = outerStart + UInt32(a)
                let o1 = outerStart + UInt32(nextA)
                indices.append(contentsOf: [i0, i1, o0, i1, o1, o0])
            }
        }
        
        // Closed bottom disk
        let bottomCenterIndex = UInt32(positions.count)
        positions.append(SIMD3<Float>(0, -0.008, 0))
        uvs.append(SIMD2<Float>(0.5, 0.5))
        let outermostStart = UInt32(1 + (radialSegments - 1) * angularSegments)
        for a in 0..<angularSegments {
            let current = outermostStart + UInt32(a)
            let next = outermostStart + UInt32((a + 1) % angularSegments)
            indices.append(contentsOf: [bottomCenterIndex, current, next])
        }
        
        var descriptor = MeshDescriptor(name: "LowProfilePlot")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)
        
        var normals = Array(repeating: SIMD3<Float>.zero, count: positions.count)
        for i in stride(from: 0, to: indices.count, by: 3) {
            let iA = Int(indices[i]), iB = Int(indices[i + 1]), iC = Int(indices[i + 2])
            let n = simd_cross(positions[iB] - positions[iA], positions[iC] - positions[iA])
            normals[iA] += n; normals[iB] += n; normals[iC] += n
        }
        descriptor.normals = MeshBuffers.Normals(normals.map {
            simd_length_squared($0) > 1e-16 ? simd_normalize($0) : SIMD3<Float>(0, 1, 0)
        })
        
        return try MeshResource.generate(from: [descriptor])
    }
    
    // MARK: - 2. Step 1 (NUKUH): Procedural Wild Weeds & Uncultivated Grass
    
    /// Populates the agricultural plot with scattered wild weeds, savanna grass, and wild shoots
    /// representing the uncultivated Kanekes land before slashing & burning.
    static func buildWildWeeds(parent: Entity, grassTexture: TextureResource?) {
        let weedBladeMesh = try? makeRiceBladeMesh(length: 0.28, arch: 0.16)
        guard let mesh = weedBladeMesh else { return }
        
        let weedCount = 52
        
        for i in 0..<weedCount {
            let angle = Float(i) * 2.3999 // Golden ratio radial distribution
            let dist = 0.08 + Float((i * 13) % 31) * 0.012
            let x = cos(angle) * dist
            let z = sin(angle) * dist
            
            var weedMaterial = PhysicallyBasedMaterial()
            weedMaterial.faceCulling = .none
            weedMaterial.roughness = .init(floatLiteral: 0.85)
            
            // Mix of dry uncultivated weeds, wild yellow-green grasses, and sage shoots
            let tintIndex = i % 4
            let tintColor: UIColor
            switch tintIndex {
            case 0:
                tintColor = UIColor(red: 0.56, green: 0.58, blue: 0.24, alpha: 1.0) // Dry savanna weed
            case 1:
                tintColor = UIColor(red: 0.38, green: 0.54, blue: 0.18, alpha: 1.0) // Wild weed green
            case 2:
                tintColor = UIColor(red: 0.62, green: 0.52, blue: 0.28, alpha: 1.0) // Straw weed
            default:
                tintColor = UIColor(red: 0.46, green: 0.50, blue: 0.26, alpha: 1.0) // Forest undergrowth
            }
            
            if let tex = grassTexture {
                weedMaterial.baseColor = .init(tint: tintColor, texture: filteredTexture(tex))
                weedMaterial.textureCoordinateTransform = .init(scale: [0.04, 1.0])
            } else {
                weedMaterial.baseColor = .init(tint: tintColor)
            }
            
            let blade = ModelEntity(mesh: mesh, materials: [weedMaterial])
            let randomScale = 0.55 + Float(i % 7) * 0.10
            blade.scale = SIMD3(repeating: randomScale)
            
            let tilt = 0.18 + Float(i % 5) * 0.08
            blade.orientation = simd_quatf(angle: angle + Float(i), axis: [0, 1, 0]) * simd_quatf(angle: tilt, axis: [1, 0, 0])
            blade.position = [x, 0.035, z]
            parent.addChild(blade)
        }
    }
    
    // MARK: - 3. Step 2 (NGASEUK): Planting Dibble Holes (Lubang Aseuk) & Sprouts
    
    /// Populates the cleared plot with Baduy planting holes (lubang aseuk) made by wooden dibble sticks,
    /// each housing tiny emerging rice sprouts.
    static func buildPlantingHoles(parent: Entity, grassTexture: TextureResource?) {
        let holeMesh = MeshResource.generateSphere(radius: 0.022)
        let sproutBladeMesh = try? makeRiceBladeMesh(length: 0.11, arch: 0.04)
        
        var holeMaterial = PhysicallyBasedMaterial()
        holeMaterial.roughness = .init(floatLiteral: 0.98)
        holeMaterial.baseColor = .init(tint: UIColor(red: 0.14, green: 0.09, blue: 0.05, alpha: 1.0)) // Deep dark planting cavity
        
        var sproutMaterial = PhysicallyBasedMaterial()
        sproutMaterial.faceCulling = .none
        sproutMaterial.roughness = .init(floatLiteral: 0.65)
        let tenderGreen = UIColor(red: 0.48, green: 0.82, blue: 0.24, alpha: 1.0)
        if let tex = grassTexture {
            sproutMaterial.baseColor = .init(tint: tenderGreen, texture: filteredTexture(tex))
            sproutMaterial.textureCoordinateTransform = .init(scale: [0.03, 1.0])
        } else {
            sproutMaterial.baseColor = .init(tint: tenderGreen)
        }
        
        // 9-11 planting dibble holes in a traditional swidden arc/cluster
        let holePositions: [SIMD3<Float>] = [
            [0.0, 0.035, 0.0],
            [-0.08, 0.035, -0.06],
            [0.08, 0.035, -0.06],
            [-0.14, 0.034, 0.02],
            [0.14, 0.034, 0.02],
            [0.0, 0.034, 0.09],
            [-0.07, 0.033, 0.12],
            [0.07, 0.033, 0.12],
            [-0.20, 0.032, -0.05],
            [0.20, 0.032, -0.05]
        ]
        
        for (idx, pos) in holePositions.enumerated() {
            let holeEntity = Entity()
            holeEntity.name = "hole_\(idx)"
            holeEntity.position = pos
            
            // Indented planting hole
            let holeModel = ModelEntity(mesh: holeMesh, materials: [holeMaterial])
            holeModel.scale = [1.0, 0.22, 1.0]
            holeModel.position = [0, -0.004, 0]
            holeEntity.addChild(holeModel)
            
            // Cluster of 3 tender young green rice sprouts emerging from each hole
            if let sproutMesh = sproutBladeMesh {
                for s in 0..<3 {
                    let sprout = ModelEntity(mesh: sproutMesh, materials: [sproutMaterial])
                    sprout.name = "sprout"
                    let sproutAngle = Float(s) * 2.094 + Float(idx) * 0.4
                    sprout.orientation = simd_quatf(angle: sproutAngle, axis: [0, 1, 0]) * simd_quatf(angle: 0.12, axis: [1, 0, 0])
                    sprout.position = [0, 0.002, 0]
                    sprout.scale = [0.8, 0.9, 0.8]
                    holeEntity.addChild(sprout)
                }
            }
            
            parent.addChild(holeEntity)
        }
    }
    
    // MARK: - 4. Curved Rice Blade Mesh (Steps 3 & 4)
    
    static func makeRiceBladeMesh(length: Float = 0.50, arch: Float = 0.14) throws -> MeshResource {
        let segments = 16
        var positions: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        
        for i in 0...segments {
            let t = Float(i) / Float(segments)
            let width = max(0.0012, sin(t * .pi) * 0.013 * (1.0 - t * 0.26))
            let y = length * (t - 0.12 * t * t * t)
            let z = arch * t * t * (1.0 + 0.3 * t)
            let cup: Float = 0.0018 * sin(t * .pi)
            
            positions.append(SIMD3<Float>(-width, y, z - cup))
            positions.append(SIMD3<Float>(0, y, z))
            positions.append(SIMD3<Float>(width, y, z - cup))
            uvs.append(SIMD2<Float>(0.0, t))
            uvs.append(SIMD2<Float>(0.5, t))
            uvs.append(SIMD2<Float>(1.0, t))
            
            if i < segments {
                for column in 0..<2 {
                    let n = UInt32(i * 3 + column)
                    indices.append(contentsOf: [n, n + 3, n + 1, n + 1, n + 3, n + 4])
                }
            }
        }
        
        var descriptor = MeshDescriptor(name: "RiceBlade")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)
        
        var normals = Array(repeating: SIMD3<Float>.zero, count: positions.count)
        for i in stride(from: 0, to: indices.count, by: 3) {
            let iA = Int(indices[i]), iB = Int(indices[i + 1]), iC = Int(indices[i + 2])
            let n = simd_cross(positions[iB] - positions[iA], positions[iC] - positions[iA])
            normals[iA] += n; normals[iB] += n; normals[iC] += n
        }
        descriptor.normals = MeshBuffers.Normals(normals.map {
            simd_length_squared($0) > 1e-16 ? simd_normalize($0) : SIMD3<Float>(0, 0, -1)
        })
        
        return try MeshResource.generate(from: [descriptor])
    }
    
    // MARK: - 5. Golden Panicle Cluster & Grains (Step 4)
    
    static func buildPanicleCluster(paniclesRoot: Entity, grainMaterial: PhysicallyBasedMaterial) {
        let stalkCount = 12
        let segmentsPerStalk = 15
        let grainMesh = MeshResource.generateSphere(radius: 0.009)
        
        for stalkIndex in 0..<stalkCount {
            let stalkEntity = Entity()
            let angle = Float(stalkIndex) * 2.3999
            let direction = SIMD3<Float>(cos(angle), 0, sin(angle))
            var prevPoint = SIMD3<Float>(0, 0.03, 0)
            let baseHeight: Float = 0.45 + Float(stalkIndex % 3) * 0.04
            let reachFactor: Float = 0.24 + Float(stalkIndex % 2) * 0.03
            
            for seg in 1...segmentsPerStalk {
                let t = Float(seg) / Float(segmentsPerStalk)
                let vert = baseHeight * sin(t * 1.8) - (t > 0.60 ? pow(t - 0.60, 2.0) * 0.28 : 0)
                let currentPoint = direction * (reachFactor * t * (1.0 + 0.42 * t)) + SIMD3<Float>(0, vert, 0)
                
                let delta = currentPoint - prevPoint
                let segLength = simd_length(delta)
                if segLength > 0.001 {
                    let stem = ModelEntity(mesh: .generateBox(size: [0.003, segLength, 0.003]), materials: [grainMaterial])
                    stem.position = (currentPoint + prevPoint) * 0.5
                    stem.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(delta))
                    stalkEntity.addChild(stem)
                }
                
                if seg >= 4 {
                    for side: Float in [-1.0, 1.0] {
                        let grain = ModelEntity(mesh: grainMesh, materials: [grainMaterial])
                        grain.scale = [0.46, 1.45, 0.46]
                        let lateralAxis = SIMD3<Float>(-sin(angle), 0, cos(angle))
                        grain.position = currentPoint + lateralAxis * (side * 0.013) + SIMD3<Float>(0, -0.004, 0)
                        grain.orientation = simd_quatf(angle: side * 0.45, axis: direction)
                        stalkEntity.addChild(grain)
                    }
                }
                prevPoint = currentPoint
            }
            paniclesRoot.addChild(stalkEntity)
        }
    }
    
    // MARK: - 6. Botanical Color Interpolation
    
    static func interpolatedLeafColor(for progress: CGFloat) -> UIColor {
        let p = Float(min(1.0, max(0.0, progress)))
        let sproutRGB = SIMD3<Float>(0.46, 0.76, 0.22)
        let matureVegetativeRGB = SIMD3<Float>(0.24, 0.55, 0.15)
        let harvestGoldenRGB = SIMD3<Float>(0.92, 0.74, 0.20)
        
        let resultRGB = p < 0.66
            ? simd_mix(sproutRGB, matureVegetativeRGB, SIMD3<Float>(repeating: p / 0.66))
            : simd_mix(matureVegetativeRGB, harvestGoldenRGB, SIMD3<Float>(repeating: (p - 0.66) / 0.34))
        
        return UIColor(red: CGFloat(resultRGB.x),
                       green: CGFloat(resultRGB.y),
                       blue: CGFloat(resultRGB.z),
                       alpha: 1.0)
    }
}
