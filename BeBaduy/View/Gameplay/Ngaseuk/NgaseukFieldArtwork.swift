import SwiftUI

/// 3D Traditional Baduy Aseuk (wooden dibble stick) with procedural PBR materials and realistic lighting.
struct AseukTool: View {
    var interactive: Bool = false
    var autoRotate: Bool = false

    var body: some View {
        Aseuk3DView(interactive: interactive, autoRotate: autoRotate)
            .accessibilityHidden(true)
    }
}
private struct AseukOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.15, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.85, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.84))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.84))
        path.closeSubpath()
        return path
    }
}

struct NgaseukSoilMark: View {
    let dug: Bool
    let seeded: Bool
    let focused: Bool
    var body: some View {
        DibbleHole3DView(dug: dug, seeded: seeded, focused: focused)
            .contentShape(Rectangle())
    }
}
