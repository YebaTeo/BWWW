import SceneKit
import UIKit

@MainActor
enum SceneEffects {
    static func emitTreeDebris(at position: SCNVector3, phase: Float, in root: SCNNode, splinterSprite: UIImage, chipSprite: UIImage, splinterSize: CGFloat, chipSize: CGFloat) {
        let splintersNode = SCNNode()
        splintersNode.position = SCNVector3(position.x, position.y + 0.025, position.z)
        let splinters = SCNParticleSystem()
        splinters.loops = false
        splinters.emissionDuration = 0.08
        splinters.birthRate = 36
        splinters.particleLifeSpan = 1.15
        splinters.particleLifeSpanVariation = 0.28
        splinters.particleSize = splinterSize
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
        splinters.particleImage = splinterSprite
        splinters.blendMode = .alpha
        splinters.isLightingEnabled = true
        splintersNode.addParticleSystem(splinters)
        root.addChildNode(splintersNode)
        splintersNode.runAction(.sequence([.wait(duration: 2.2), .removeFromParentNode()]))

        let chipsNode = SCNNode()
        chipsNode.position = SCNVector3(position.x, position.y + 0.018, position.z)
        let chips = SCNParticleSystem()
        chips.loops = false
        chips.emissionDuration = 0.045
        chips.birthRate = 16
        chips.particleLifeSpan = 0.68
        chips.particleLifeSpanVariation = 0.18
        chips.particleSize = chipSize
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
        chips.particleImage = chipSprite
        chips.blendMode = .alpha
        chips.isLightingEnabled = true
        chipsNode.addParticleSystem(chips)
        root.addChildNode(chipsNode)
        chipsNode.runAction(.sequence([.wait(duration: 1.8), .removeFromParentNode()]))

        // Brief grazing light at the impact makes the wood fragments
        // pick up warm highlights and a little contrast as they scatter.
    }

    static func configureFlameAnimation(_ system: SCNParticleSystem, sizes: [Double]) {
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
        size.values = sizes
        size.keyTimes = [0, 0.12, 0.38, 0.72, 1]

        system.propertyControllers = [
            .color: SCNParticlePropertyController(animation: color),
            .size: SCNParticlePropertyController(animation: size)
        ]
    }
}
