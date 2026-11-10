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
            ZStack(alignment: .top) {
                ForEach(0..<5) { index in
                    MipitPlantArtwork(showsLeaves: false)
                        .rotationEffect(.degrees(180 + Double(index - 2) * 8))
                        .offset(x: CGFloat(index - 2) * geometry.size.width * 0.09)
                }
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.48, green: 0.32, blue: 0.14))
                    .frame(width: geometry.size.width * 0.30, height: max(3, geometry.size.height * 0.045))
                    .offset(y: geometry.size.height * 0.18)
            }
        }.accessibilityHidden(true)
    }
}
