import SwiftUI

/// Simplified kored: wooden grip and a short metal hoe blade at soil level.
struct KoredTool: View {
    var body: some View {
        GeometryReader { bounds in
            let size = bounds.size
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.72, y: 0))
                path.addLine(to: CGPoint(x: size.width * 0.9, y: 3))
                path.addLine(to: CGPoint(x: size.width * 0.39, y: size.height * 0.8))
                path.addLine(to: CGPoint(x: size.width * 0.24, y: size.height * 0.77))
                path.closeSubpath()
            }.fill(LinearGradient(colors: [Color(red: 0.72, green: 0.52, blue: 0.30), Color(red: 0.30, green: 0.18, blue: 0.09)], startPoint: .leading, endPoint: .trailing))
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.30, y: size.height * 0.72))
                path.addLine(to: CGPoint(x: size.width * 0.65, y: size.height * 0.81))
                path.addLine(to: CGPoint(x: size.width * 0.52, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height * 0.93))
                path.closeSubpath()
            }.fill(LinearGradient(colors: [.gray, Color(white: 0.18), Color(white: 0.52)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }.shadow(color: .black.opacity(0.4), radius: 2, x: 3, y: 3)
            .accessibilityHidden(true)
    }
}

struct NgoredWeedArtwork: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule().fill(Color(red: 0.26, green: 0.34, blue: 0.10)).frame(width: 3, height: 54)
            ForEach(0..<6) { index in
                Ellipse()
                    .fill(LinearGradient(colors: [Color(red: 0.51, green: 0.61, blue: 0.23), Color(red: 0.18, green: 0.30, blue: 0.08)], startPoint: .top, endPoint: .bottom))
                    .overlay(Ellipse().stroke(.black.opacity(0.15), lineWidth: 0.5))
                    .frame(width: 14, height: 32)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -48 : 48), anchor: .bottom)
                    .offset(x: index.isMultiple(of: 2) ? -6 : 6, y: -CGFloat(index / 2) * 14)
            }
        }.frame(width: 64, height: 76)
            .shadow(color: .black.opacity(0.35), radius: 2, x: 2, y: 3)
            .accessibilityHidden(true)
    }
}
