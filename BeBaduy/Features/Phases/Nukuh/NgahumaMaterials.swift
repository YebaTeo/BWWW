import RealityKit
import UIKit

/// Generated color textures are shared by all instances. These are not measured PBR scans.
@MainActor
struct NgahumaMaterials {
    let soil: TextureResource
    let ash: TextureResource
    let grass: TextureResource
    let panorama: TextureResource
    let flame: TextureResource
    let tree: TextureResource

    static func load() async throws -> Self {
        func texture(_ name: String, resourceFallback: String? = nil) async throws -> TextureResource {
            if let image = UIImage(named: name), let cgImage = image.cgImage {
                return try await TextureResource(image: cgImage, options: .init(semantic: .color))
            }
            guard let resourceFallback,
                  let url = Bundle.main.url(forResource: resourceFallback, withExtension: "png") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try await TextureResource(contentsOf: url, options: .init(semantic: .color))
        }

        func texture(_ cgImage: CGImage) async throws -> TextureResource {
            return try await TextureResource(image: cgImage, options: .init(semantic: .color))
        }

        guard let environment = UIImage(named: "HumaEnvironment"),
              let envCG = environment.cgImage else {
            throw CocoaError(.fileNoSuchFile)
        }

        // 1. Soil texture: match the rich warm reddish-brown soil of Home (#6A4B33)
        // using HumaTerrainTexture color-graded to Home's earth tone.
        let rawTerrain = UIImage(named: "HumaTerrainTexture")?.cgImage
            ?? UIImage(contentsOfFile: Bundle.main.path(forResource: "ngahuma-soil", ofType: "png") ?? "")?.cgImage
        let soilCG = rawTerrain.flatMap(Self.createHomeMatchedSoil) ?? rawTerrain
        let soil: TextureResource
        if let soilCG {
            soil = try await texture(soilCG)
        } else {
            soil = try await texture("HumaTerrainTexture", resourceFallback: "ngahuma-soil")
        }

        let ash = try await texture("ngahuma-ash", resourceFallback: "ngahuma-ash")

        // 2. Grass texture: using Home's HumaGrassTexture with natural green tufts
        let grass = try await texture("HumaGrassTexture", resourceFallback: "ngahuma-grass")

        // 3. 360 Panorama background: built from HumaEnvironment's sky and distant landscape (langit dan objek jauh)
        guard let panoCG = Self.build360Panorama(from: envCG) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let panorama = try await texture(panoCG)

        let flame = try await texture("ngahuma-flame", resourceFallback: "ngahuma-flame")
        let tree = try await texture("HumaTreeNatural", resourceFallback: "HumaTree")

        return Self(
            soil: soil,
            ash: ash,
            grass: grass,
            panorama: panorama,
            flame: flame,
            tree: tree
        )
    }

    /// Produces a rich, warm upland soil texture matching Home (#6A4B33)
    /// by infusing HumaTerrainTexture with the warm Baduy earth tone.
    static func createHomeMatchedSoil(from terrainImage: CGImage) -> CGImage? {
        let w = terrainImage.width
        let h = terrainImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(terrainImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        // Color-grade with Home's photographic soil tone #6A4B33 (RGB: 106, 75, 51)
        ctx.setBlendMode(.multiply)
        ctx.setFillColor(CGColor(red: 112.0 / 255.0, green: 80.0 / 255.0, blue: 54.0 / 255.0, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Subtle warm golden earth highlight
        ctx.setBlendMode(.colorDodge)
        ctx.setFillColor(CGColor(red: 0.16, green: 0.11, blue: 0.06, alpha: 0.35))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        return ctx.makeImage()
    }

    /// Generates a seamless 360° equirectangular panoramic texture using the sky, sun glow,
    /// and distant mountain vista ("langit dan objek jauh") from the Huma landscape artwork.
    static func build360Panorama(from source: CGImage) -> CGImage? {
        let panoW = 2048
        let panoH = 1024
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: panoW,
            height: panoH,
            bitsPerComponent: 8,
            bytesPerRow: panoW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // 1. Sky gradient from zenith (+90°, top) down through horizon (0°, middle) to nadir (-90°, bottom)
        let skyColors = [
            CGColor(red: 0.58, green: 0.60, blue: 0.66, alpha: 1.0), // Zenith
            CGColor(red: 0.70, green: 0.71, blue: 0.73, alpha: 1.0), // Upper sky
            CGColor(red: 0.84, green: 0.78, blue: 0.72, alpha: 1.0), // Mid sky
            CGColor(red: 0.76, green: 0.70, blue: 0.63, alpha: 1.0), // Horizon sky
            CGColor(red: 0.38, green: 0.34, blue: 0.27, alpha: 1.0), // Below horizon (ground haze)
            CGColor(red: 0.26, green: 0.20, blue: 0.15, alpha: 1.0)  // Nadir (deep soil tone)
        ] as CFArray
        let skyLocations: [CGFloat] = [0.0, 0.28, 0.50, 0.58, 0.78, 1.0]
        if let skyGrad = CGGradient(colorsSpace: colorSpace, colors: skyColors, locations: skyLocations) {
            context.drawLinearGradient(
                skyGrad,
                start: CGPoint(x: 0, y: CGFloat(panoH)),
                end: CGPoint(x: 0, y: 0),
                options: []
            )
        }

        // 2. Sunrise glow in east direction (centered at x = 35% of 360° width)
        let sunColors = [
            CGColor(red: 1.0, green: 0.94, blue: 0.82, alpha: 0.65),
            CGColor(red: 0.98, green: 0.85, blue: 0.70, alpha: 0.35),
            CGColor(red: 0.95, green: 0.80, blue: 0.65, alpha: 0.0)
        ] as CFArray
        if let sunGrad = CGGradient(colorsSpace: colorSpace, colors: sunColors, locations: [0.0, 0.45, 1.0]) {
            context.drawRadialGradient(
                sunGrad,
                startCenter: CGPoint(x: CGFloat(panoW) * 0.35, y: CGFloat(panoH) * 0.58),
                startRadius: 10,
                endCenter: CGPoint(x: CGFloat(panoW) * 0.35, y: CGFloat(panoH) * 0.58),
                endRadius: CGFloat(panoW) * 0.30,
                options: []
            )
        }

        // 3. Pristine distant mountain vista (x: 180, y: 175, width: 660, height: 405)
        let vistaRect = CGRect(x: 180, y: 175, width: 660, height: 405)
        guard let vista = source.cropping(to: vistaRect) else { return nil }

        let tileW = CGFloat(panoW) / 2.0
        let targetH = CGFloat(panoH) * 0.36
        let targetY = CGFloat(panoH) * 0.38

        // Draw tile 0 (facing forward)
        context.saveGState()
        context.draw(vista, in: CGRect(x: 0, y: targetY, width: tileW, height: targetH))
        context.restoreGState()

        // Draw tile 1 (flipped horizontally for a mathematically seamless 360 loop)
        context.saveGState()
        context.translateBy(x: CGFloat(panoW), y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(vista, in: CGRect(x: 0, y: targetY, width: tileW, height: targetH))
        context.restoreGState()

        // 4. Soft upper sky blend for the mountains so clouds blend naturally into the sky
        let upperSkyColors = [
            CGColor(red: 0.84, green: 0.78, blue: 0.72, alpha: 0.95),
            CGColor(red: 0.84, green: 0.78, blue: 0.72, alpha: 0.0)
        ] as CFArray
        if let upperGrad = CGGradient(colorsSpace: colorSpace, colors: upperSkyColors, locations: [0.0, 1.0]) {
            context.drawLinearGradient(
                upperGrad,
                start: CGPoint(x: 0, y: targetY + targetH),
                end: CGPoint(x: 0, y: targetY + targetH - 60),
                options: []
            )
        }

        // 5. Soft mist / haze along the base of the mountains to merge seamlessly into 3D terrain
        let mistColors = [
            CGColor(red: 0.76, green: 0.72, blue: 0.68, alpha: 0.0),
            CGColor(red: 0.65, green: 0.60, blue: 0.55, alpha: 0.45),
            CGColor(red: 0.40, green: 0.34, blue: 0.26, alpha: 0.85),
            CGColor(red: 0.26, green: 0.20, blue: 0.15, alpha: 1.0)
        ] as CFArray
        let mistLocations: [CGFloat] = [0.0, 0.30, 0.65, 1.0]
        if let mistGrad = CGGradient(colorsSpace: colorSpace, colors: mistColors, locations: mistLocations) {
            context.drawLinearGradient(
                mistGrad,
                start: CGPoint(x: 0, y: targetY + 60),
                end: CGPoint(x: 0, y: targetY - 100),
                options: []
            )
        }

        return context.makeImage()
    }

    func addSpatialEnvironment(to root: Entity) {
        var skyMaterial = UnlitMaterial()
        skyMaterial.color = .init(tint: .white, texture: .init(panorama))
        skyMaterial.faceCulling = .none
        let sphere = ModelEntity(mesh: .generateSphere(radius: 65), materials: [skyMaterial])
        sphere.position = [0, 1.5, 0]
        sphere.scale = [-1, 1, 1]
        root.addChild(sphere)
    }

    func earth(burned: Bool = false) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .white, texture: .init(burned ? ash : soil))
        material.roughness = .init(floatLiteral: 0.95)
        material.specular = .init(floatLiteral: 0.08)
        return material
    }

    func foliage(tint: UIColor = .white) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: tint, texture: .init(grass))
        material.roughness = .init(floatLiteral: 0.92)
        material.specular = .init(floatLiteral: 0.10)
        material.faceCulling = .none
        material.opacityThreshold = 0.16
        return material
    }

    func treeCard(height: Float) -> Entity {
        let treeEntity = Entity()
        let width = height * 0.82
        let mesh = MeshResource.generatePlane(width: width, height: height)
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .white, texture: .init(tree))
        material.roughness = .init(floatLiteral: 0.92)
        material.faceCulling = .none
        material.opacityThreshold = 0.16
        for index in 0..<2 {
            let card = ModelEntity(mesh: mesh, materials: [material])
            card.position.y = height * 0.5
            card.orientation = simd_quatf(angle: Float(index) * .pi / 2, axis: [0, 1, 0])
            treeEntity.addChild(card)
        }
        return treeEntity
    }

    func clump(height: Float, variant: Int = 0) -> Entity {
        let clump = Entity()
        let tint: UIColor
        switch variant % 3 {
        case 0: tint = UIColor(red: 0.95, green: 1.0, blue: 0.90, alpha: 1) // Fresh tropical green
        case 1: tint = UIColor(red: 1.0, green: 0.96, blue: 0.82, alpha: 1) // Warm sunlit grass
        default: tint = UIColor(red: 0.88, green: 0.94, blue: 0.80, alpha: 1) // Natural undergrowth
        }
        let material = foliage(tint: tint)
        let mesh = MeshResource.generatePlane(width: height, height: height)
        for index in 0..<3 {
            let card = ModelEntity(mesh: mesh, materials: [material])
            card.position.y = height * 0.48
            card.orientation = simd_quatf(angle: Float(index) * .pi / 3, axis: [0, 1, 0])
            clump.addChild(card)
        }
        return clump
    }

    /// A low-amplitude mesh with metre-scaled UVs, keeping the interactive ring level.
    func terrain() throws -> ModelEntity {
        let steps = 64
        let span: Float = 80
        var vertices: [SIMD3<Float>] = []
        var uv: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        for z in 0...steps {
            for x in 0...steps {
                let px = Float(x) / Float(steps) * span - span / 2
                let pz = Float(z) / Float(steps) * span - span / 2
                let radius = sqrt(px * px + pz * pz)
                let amplitude = min(1, max(0, (radius - 3.5) / 8))
                let height = amplitude * (sin(px * 0.41) * cos(pz * 0.32) * 0.28 - 0.35)
                vertices.append([px, height - 0.012, pz])
                uv.append([px / 4.0, pz / 4.0])
                if x < steps && z < steps {
                    let a = UInt32(z * (steps + 1) + x)
                    let b = a + UInt32(steps + 1)
                    indices += [a, b, a + 1, a + 1, b, b + 1]
                }
            }
        }
        var descriptor = MeshDescriptor(name: "Ngahuma earth")
        descriptor.positions = MeshBuffers.Positions(vertices)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uv)
        descriptor.primitives = .triangles(indices)
        return ModelEntity(mesh: try MeshResource.generate(from: [descriptor]), materials: [earth()])
    }
}
