import SwiftUI

/// The original journey menu landscape, shared by both main tabs.
struct MenuBackground: View {
    let progress: JourneyProgress

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.20, green: 0.12, blue: 0.08)
                CinematicAtmosphereView(
                    progress: GrowthStage.onboardingStage(for: progress).targetProgress,
                    isActive: false
                )
                .frame(width: geometry.size.width + 64, height: geometry.size.height + 64)
                .blur(radius: 16)
                Color(red: 0.20, green: 0.12, blue: 0.08).opacity(0.34)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
