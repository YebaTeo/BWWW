import SwiftUI

enum LaunchSplashStyle {
    /// Exact warm cream interior background color sampled from `OnboardingLogo` (`#FDF7F0`).
    static let backgroundColor = Color(red: 0.992, green: 0.970, blue: 0.942)
    static let wordmarkColor = Color(red: 0.30, green: 0.25, blue: 0.16)
    static let logoSize: CGFloat = 120
    static let logoVerticalFraction: CGFloat = 0.40
    static let wordmarkSpacing: CGFloat = 14
}

/// Matches the native launch screen (`LaunchScreen.storyboard`) pixel-for-pixel.
struct LaunchSplashView: View {
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height * LaunchSplashStyle.logoVerticalFraction
            ZStack(alignment: .top) {
                LaunchSplashStyle.backgroundColor
                    .ignoresSafeArea()

                Image("OnboardingLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: LaunchSplashStyle.logoSize, height: LaunchSplashStyle.logoSize)
                    .position(x: centerX, y: centerY)
                    .accessibilityHidden(true)

                Text("BeBaduy")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(LaunchSplashStyle.wordmarkColor)
                    .frame(maxWidth: .infinity)
                    .offset(y: centerY + LaunchSplashStyle.logoSize / 2 + LaunchSplashStyle.wordmarkSpacing)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(LaunchSplashStyle.backgroundColor)
        .ignoresSafeArea()
        .preferredColorScheme(.light)
    }
}

struct LaunchLoadingIndicator: View {
    var message: LocalizedStringKey = "Menyiapkan perjalanan…"

    var body: some View {
        ReusableLoadingView(message: message, style: .card)
    }
}

#Preview {
    LaunchSplashView()
}
