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

                VStack(spacing: 12) {
                    Image("OnboardingLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 76, height: 76)
                        .accessibilityHidden(true)
                    Text("BeBaduy")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(red: 0.19, green: 0.20, blue: 0.15))
        .ignoresSafeArea()
        .preferredColorScheme(.light)
    }
}

struct LaunchLoadingIndicator: View {
    var message: LocalizedStringKey = "Menyiapkan perjalanan…"

    var body: some View {
        ProgressView(message)
            .tint(.white)
            .foregroundStyle(.white)
            .padding(24)
            .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    LaunchSplashView()
}
