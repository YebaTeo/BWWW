import SwiftUI

/// A shaded, tapered tool drawn at the display's resolution so its tip can enter the soil.
struct AseukTool: View {
    var body: some View {
        GeometryReader { bounds in
            AseukOutline()
                .fill(LinearGradient(colors: [Color(red: 0.27, green: 0.16, blue: 0.08), Color(red: 0.66, green: 0.47, blue: 0.27), Color(red: 0.83, green: 0.65, blue: 0.42), Color(red: 0.36, green: 0.23, blue: 0.12)], startPoint: .leading, endPoint: .trailing))
                .overlay {
                    Canvas { context, size in
                        for index in 0..<12 {
                            let x = size.width * CGFloat(index + 1) / 13
                            var grain = Path()
                            grain.move(to: CGPoint(x: x, y: 0))
                            grain.addQuadCurve(to: CGPoint(x: x * 0.8 + size.width * 0.1, y: size.height), control: CGPoint(x: x + sin(Double(index)) * 5, y: size.height * 0.5))
                            context.stroke(grain, with: .color(.black.opacity(index.isMultiple(of: 3) ? 0.24 : 0.10)), lineWidth: 0.8)
                        }
                    }.clipShape(AseukOutline())
                }
                .shadow(color: .black.opacity(0.35), radius: 3, x: 5, y: 2)
        }.accessibilityHidden(true)
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
        ZStack {
            if dug {
                Ellipse().fill(Color(red: 0.37, green: 0.23, blue: 0.12))
                    .frame(width: 63, height: 33).blur(radius: 2)
                Ellipse().fill(RadialGradient(colors: [.black, Color(red: 0.13, green: 0.07, blue: 0.03), Color(red: 0.48, green: 0.32, blue: 0.18)], center: .center, startRadius: 3, endRadius: 29))
                    .frame(width: 50, height: 24)
                ForEach(0..<9) { index in
                    Ellipse().fill(index.isMultiple(of: 2) ? Color(red: 0.47, green: 0.32, blue: 0.20) : Color(red: 0.27, green: 0.17, blue: 0.10))
                        .frame(width: CGFloat(5 + index % 3), height: 4)
                        .offset(x: cos(Double(index) * 0.7) * 31, y: sin(Double(index) * 0.7) * 17)
                }
                if seeded {
                    HStack(spacing: 3) {
                        Capsule().fill(Color(red: 0.88, green: 0.74, blue: 0.43)).frame(width: 11, height: 4).rotationEffect(.degrees(-25))
                        Capsule().fill(Color(red: 0.95, green: 0.83, blue: 0.57)).frame(width: 10, height: 4).rotationEffect(.degrees(35))
                    }
                }
            } else {
                Ellipse().strokeBorder(.white.opacity(focused ? 0.9 : 0.45), style: StrokeStyle(lineWidth: focused ? 2 : 1, dash: [3, 5]))
                    .frame(width: 52, height: 26)
                    .shadow(color: .black.opacity(0.7), radius: 2)
            }
        }.frame(width: 80, height: 64).contentShape(Rectangle())
    }
}
