import RealityKit
import SwiftUI

/// The journey shortcut sits above the SceneKit landscape. RealityKit renders
/// the small rice ornament in its own transparent SwiftUI layer.
struct StageMenuButton: View {
    let stageIndex: Int
    let action: () -> Void

    private var grainCount: Int { min(max(stageIndex + 1, 1), PhaseID.allCases.count) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1, green: 0.85, blue: 0.64),
                                     Color(red: 1, green: 0.92, blue: 0.79)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Capsule().strokeBorder(.white.opacity(0.85), lineWidth: 1))
                    .shadow(color: .black.opacity(0.32), radius: 4, y: 3)
                    .frame(width: 106, height: 42)
                    .padding(.leading, 19)

                Text("Tahapan")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.16, green: 0.11, blue: 0.07))
                    .padding(.leading, 42)

                RiceGrainOrnament(grainCount: grainCount)
                    .frame(width: 125, height: 58)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(width: 125, height: 58, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tahapan")
        .accessibilityValue("\(grainCount) dari 6 biji")
        .accessibilityHint("Buka menu perjalanan Ngahuma")
        .accessibilityIdentifier("home.journey")
    }
}

private struct RiceGrainOrnament: View {
    let grainCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RealityView { (content: inout RealityViewCameraContent) in
            content.camera = .virtual
            let camera = Entity()
            var projection = OrthographicCameraComponent()
            projection.scale = 0.075
            projection.scaleDirection = .vertical
            camera.components.set(projection)
            camera.look(at: .zero, from: [0, 0, 0.2], relativeTo: nil)
            content.add(camera)

            let sprig = Entity()
            sprig.name = "grain-count-\(grainCount)"

            let stemMaterial = SimpleMaterial(color: UIColor(red: 0.54, green: 0.34, blue: 0.10, alpha: 1), isMetallic: false)
            let grainMaterial = SimpleMaterial(color: UIColor(red: 1, green: 0.69, blue: 0.13, alpha: 1), isMetallic: false)
            let stalk = [
                Self.point(x: 20, y: 42),
                Self.point(x: 24, y: 28),
                Self.point(x: 29, y: 16),
                Self.point(x: 36, y: 10)
            ]
            for index in 0..<(stalk.count - 1) {
                sprig.addChild(Self.stem(from: stalk[index], to: stalk[index + 1],
                                          radius: 0.00125, material: stemMaterial))
            }

            // The panicle bends over the capsule. Each stage grows one more
            // section of the rachis and its attached grain.
            let rachis = [
                Self.point(x: 36, y: 10), Self.point(x: 43, y: 9),
                Self.point(x: 55, y: 8), Self.point(x: 68, y: 8),
                Self.point(x: 81, y: 9), Self.point(x: 95, y: 12),
                Self.point(x: 110, y: 17)
            ]
            let grainTips = [
                Self.point(x: 46, y: 14), Self.point(x: 58, y: 6),
                Self.point(x: 71, y: 14), Self.point(x: 84, y: 6),
                Self.point(x: 98, y: 17), Self.point(x: 113, y: 14)
            ]
            for index in 0..<6 {
                let seed = Entity()
                seed.name = "seed-\(index)"
                seed.position = rachis[index]
                seed.scale = Self.scale(visible: index < grainCount)
                seed.addChild(Self.stem(from: .zero, to: rachis[index + 1] - rachis[index],
                                        radius: 0.00085, material: stemMaterial))
                seed.addChild(Self.stem(from: rachis[index + 1] - rachis[index],
                                        to: grainTips[index] - rachis[index],
                                        radius: 0.00055, material: stemMaterial))

                let grain = ModelEntity(mesh: .generateSphere(radius: 0.0043), materials: [grainMaterial])
                grain.position = grainTips[index] - rachis[index] + SIMD3<Float>(0, 0, 0.002)
                grain.orientation = simd_quatf(angle: index.isMultiple(of: 2) ? -0.25 : 0.25,
                                               axis: [0, 0, 1])
                grain.scale = [1.5, 0.72, 0.72]
                seed.addChild(grain)
                sprig.addChild(seed)
            }
            content.add(sprig)
        } update: { content in
            guard let sprig = content.entities.first(where: { $0.name.hasPrefix("grain-count-") }),
                  sprig.name != "grain-count-\(grainCount)" else { return }
            sprig.name = "grain-count-\(grainCount)"
            for index in 0..<6 {
                guard let seed = sprig.findEntity(named: "seed-\(index)") else { continue }
                var target = seed.transform
                target.scale = Self.scale(visible: index < grainCount)
                seed.move(to: target, relativeTo: sprig, duration: reduceMotion ? 0 : 0.28)
            }
        }
        .background(.clear)
    }

    private static func scale(visible: Bool) -> SIMD3<Float> {
        SIMD3<Float>(repeating: visible ? 1 : 0.001)
    }

    private static func point(x: Float, y: Float) -> SIMD3<Float> {
        // OrthographicCameraComponent.scale is the half-height of the view.
        let metersPerPoint: Float = (0.075 * 2) / 58
        return [(x - 62.5) * metersPerPoint, (29 - y) * metersPerPoint, 0]
    }

    private static func stem(from start: SIMD3<Float>, to end: SIMD3<Float>,
                             radius: Float, material: SimpleMaterial) -> ModelEntity {
        let direction = end - start
        let length = simd_length(direction)
        let segment = ModelEntity(mesh: .generateCylinder(height: length, radius: radius),
                                  materials: [material])
        segment.position = (start + end) / 2
        segment.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: direction / length)
        return segment
    }
}
