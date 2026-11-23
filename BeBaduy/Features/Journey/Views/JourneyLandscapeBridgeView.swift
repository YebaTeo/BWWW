import SwiftUI

/// One continuous grass-to-soil backdrop used by both sides of the Home landing-to-menu slide.
struct JourneyLandscapeBridgeView: View {
    let width: CGFloat
    let viewportHeight: CGFloat
    var hidesRiceEmblem = false

    private let skyHaze = Color(red: 0.78, green: 0.69, blue: 0.63)
    private let sunlitHaze = Color(red: 1, green: 0.96, blue: 0.87)
    static let riceGlow = Color(red: 1, green: 0.85, blue: 0.58)

    static func riceEmblemSize(width: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        min(width * 0.55, viewportHeight * 0.32)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Image("JourneyLandscapeSoil")
                .resizable()
                .frame(width: width, height: viewportHeight * 1.97)
                .offset(y: -viewportHeight * 0.07)

            // Carry the existing grass band across the Home/Menu boundary at one viewport height.
            Image("JourneyLandscapeSoil")
                .resizable()
                .frame(width: width, height: viewportHeight * 1.97)
                .offset(y: viewportHeight * 0.13)
                .frame(width: width, height: viewportHeight * 1.9, alignment: .top)
                .clipped()
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.37),
                        .init(color: .white, location: 0.46),
                        .init(color: .white, location: 0.58),
                        .init(color: .clear, location: 0.71)
                    ], startPoint: .top, endPoint: .bottom)
                }

            LinearGradient(stops: [
                .init(color: skyHaze.opacity(0.97), location: 0),
                .init(color: skyHaze.opacity(0.94), location: 0.47),
                .init(color: skyHaze.opacity(0.76), location: 0.61),
                .init(color: .clear, location: 0.80)
            ], startPoint: .top, endPoint: .bottom)
            .frame(width: width, height: viewportHeight)

            RadialGradient(stops: [
                .init(color: .white.opacity(0.92), location: 0),
                .init(color: sunlitHaze.opacity(0.84), location: 0.24),
                .init(color: sunlitHaze.opacity(0.54), location: 0.52),
                .init(color: sunlitHaze.opacity(0.16), location: 0.78),
                .init(color: .clear, location: 1)
            ], center: .center, startRadius: 0, endRadius: width * 0.68)
            .frame(width: width * 1.36, height: width * 1.36)
            .frame(width: width, height: viewportHeight * 0.72)
            .offset(y: viewportHeight * 0.04)

            Image("JourneyLogoRice")
                .resizable()
                .scaledToFit()
                .frame(width: Self.riceEmblemSize(width: width, viewportHeight: viewportHeight))
                .saturation(0.68)
                .brightness(0.08)
                .opacity(hidesRiceEmblem ? 0 : 0.94)
                .shadow(color: .white.opacity(0.72), radius: 10)
                .shadow(color: Self.riceGlow.opacity(0.48), radius: 28)
                .frame(width: width, height: viewportHeight * 0.72)
                .offset(y: viewportHeight * 0.04)
        }
        .frame(width: width, height: viewportHeight * 1.9, alignment: .top)
        .accessibilityHidden(true)
    }
}


