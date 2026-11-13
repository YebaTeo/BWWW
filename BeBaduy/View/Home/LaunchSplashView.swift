import SwiftUI

/// Matches the native launch screen while the returning user's Home scene renders.
struct LaunchSplashView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("LaunchLandscape")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityHidden(true)

                VStack(spacing: 20) {
                    Image("OnboardingLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 144, height: 144)
                        .accessibilityHidden(true)
                    Text("BeBaduy")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppTheme.cream)
                        .frame(height: 41)
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 6) {
                        ProgressView()
                            .tint(AppTheme.cream)
                            .frame(height: 21)
                            .accessibilityHidden(true)
                        Text("Menyiapkan perjalanan…")
                            .font(.system(size: 17))
                            .foregroundStyle(AppTheme.cream)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(height: 21)
                    }
                    .accessibilityIdentifier("launch.loading")
                    .alignmentGuide(.bottom) { dimensions in -dimensions.height - -30 }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(red: 0.49, green: 0.39, blue: 0.29))
        .ignoresSafeArea()
    }
}

struct LaunchLoadingIndicator: View {
    var body: some View {
        ProgressView("Menyiapkan perjalanan…")
            .tint(.white)
            .foregroundStyle(.white)
            .padding(24)
            .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    LaunchSplashView()
}
