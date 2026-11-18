import SceneKit
import simd

enum SceneGeometry {
    static func makeBladeGeometry(
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
}
