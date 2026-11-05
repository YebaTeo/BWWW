import Foundation
import RealityKit

/// Small damped wind probes animate RealityKit foliage without a second renderer.
@MainActor final class VegetationPhysics {
    private struct Probe {
        var displacement: Float = 0
        var velocity: Float = 0
        let mass: Float
    }
    private var probes: [Probe] = []
    private var bindings: [(entity: Entity, rest: simd_quatf, probe: Int)] = []
    private var time: TimeInterval = 0
    var subscription: EventSubscription?
    var isPaused = false

    func bind(_ entities: [Entity], mass: CGFloat) {
        guard !entities.isEmpty else { return }
        let start = probes.count
        probes += (0..<3).map { _ in Probe(mass: Float(mass)) }
        for (index, entity) in entities.enumerated() {
            bindings.append((entity, entity.orientation, start + index % 3))
        }
    }

    func advance(by delta: TimeInterval) {
        guard !isPaused else { return }
        let dt = Float(min(max(delta, 0), 1.0 / 30))
        time += Double(dt)
        for index in probes.indices {
            let wind = 0.035 * Float(sin(time * (2 * .pi / 20) + Double(index % 3) * 0.67))
            let acceleration = (wind - 10 * probes[index].displacement - 4.5 * probes[index].velocity) / probes[index].mass
            probes[index].velocity = min(0.025, max(-0.025, probes[index].velocity + acceleration * dt))
            probes[index].displacement = min(0.012, max(-0.012, probes[index].displacement + probes[index].velocity * dt))
        }
        for binding in bindings where binding.entity.isActive {
            binding.entity.orientation = simd_quatf(angle: probes[binding.probe].displacement, axis: [0, 0, 1]) * binding.rest
        }
    }
}
