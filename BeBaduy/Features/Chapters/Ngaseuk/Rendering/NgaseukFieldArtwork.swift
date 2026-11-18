import SwiftUI

/// 3D Traditional Baduy Aseuk (wooden dibble stick) with procedural PBR materials and realistic lighting.
struct AseukTool: View {
    var interactive: Bool = false
    var autoRotate: Bool = false
    var rotationSpeed: Float = 0.55
    var pitch: Float = 0.22
    var yaw: Float = 0.45
    var roll: Float = -0.08

    var body: some View {
        Aseuk3DView(interactive: interactive, autoRotate: autoRotate, rotationSpeed: rotationSpeed,
                    defaultPitch: pitch, defaultYaw: yaw, defaultRoll: roll)
            .accessibilityHidden(true)
    }
}

struct NgaseukSoilMark: View {
    let digCount: Int
    let seeded: Bool
    let focused: Bool
    var body: some View {
        DibbleHole3DView(digCount: digCount, seeded: seeded, focused: focused)
            .contentShape(Rectangle())
    }
}
