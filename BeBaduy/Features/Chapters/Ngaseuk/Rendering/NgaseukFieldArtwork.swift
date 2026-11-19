import SwiftUI

/// 3D Traditional Baduy Aseuk (wooden dibble stick) with procedural PBR materials and realistic lighting.
struct AseukTool: View {
    var interactive: Bool = false
    var autoRotate: Bool = false
    var rotationSpeed: Float = 0.55
    var pitch: Float = 0.22
    var yaw: Float = 0.45
    var roll: Float = -0.08
    var showsLoading = false
    @State private var isReady = false

    var body: some View {
        ZStack {
            Aseuk3DView(
                interactive: interactive,
                autoRotate: autoRotate,
                rotationSpeed: rotationSpeed,
                defaultPitch: pitch,
                defaultYaw: yaw,
                defaultRoll: roll,
                onFirstFrame: firstFrameHandler
            )
            .opacity(!showsLoading || isReady ? 1 : 0)

            if showsLoading && !isReady {
                ReusableLoadingView(message: "Memuat aseuk…", style: .compact)
            }
        }
        .accessibilityHidden(true)
        .task {
            guard showsLoading, !isReady else { return }
            try? await Task.sleep(for: .seconds(1.5))
            if !isReady { isReady = true }
        }
    }

    private var firstFrameHandler: (@MainActor () -> Void)? {
        if showsLoading { return { isReady = true } }
        return nil
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
