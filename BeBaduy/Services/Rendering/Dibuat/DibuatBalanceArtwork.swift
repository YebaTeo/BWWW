import SwiftUI

struct DibuatBalanceArtwork: View {
    let balance: Double
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack(alignment: .top) {
                Rectangle().fill(.white.opacity(0.65)).frame(height: 1).padding(.top, 18)
                ZStack(alignment: .top) {
                    Capsule().fill(LinearGradient(colors: [
                        Color(red: 0.83, green: 0.72, blue: 0.46),
                        Color(red: 0.47, green: 0.34, blue: 0.18)
                    ], startPoint: .top, endPoint: .bottom))
                    .frame(height: 19).padding(.top, 9)
                    HStack(spacing: width * 0.045) {
                        ForEach(0..<3) { index in
                            DibuatRiceBundle()
                                .frame(width: width * 0.24, height: height * 0.88)
                                .rotationEffect(.degrees(reduceMotion ? 0 : -balance * Double(7 + index)), anchor: .top)
                        }
                    }
                }
                .rotationEffect(.degrees(reduceMotion ? 0 : balance * 12), anchor: UnitPoint(x: 0.5, y: 0.08))
            }
        }.accessibilityHidden(true)
    }
}

struct DibuatRiceBundle: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            Image("drying_rice_after").resizable()
                .frame(width: width / 0.26, height: height / 0.32)
                .offset(x: -width * 0.19 / 0.26, y: -height * 0.36 / 0.32)
                .frame(width: width, height: height, alignment: .topLeading)
                .mask {
                    Path { path in
                        let points: [(CGFloat, CGFloat)] = [(0.18, 0), (0.45, 0.01), (0.49, 0.22), (0.66, 0.34),
                            (0.85, 0.49), (0.96, 0.84), (0.85, 0.97), (0.61, 1), (0.39, 0.95),
                            (0.18, 0.98), (0.02, 0.82), (0.05, 0.57), (0.13, 0.34), (0.25, 0.23)]
                        path.addLines(points.map { CGPoint(x: $0.0 * width, y: $0.1 * height) })
                        path.closeSubpath()
                    }
                }
        }
    }
}
