import SwiftUI
import UIKit

enum LaunchSplashStyle {
    /// Fallback matches the warm taupe edge of the splash background artwork.
    static let backgroundColor = Color(red: 0.80, green: 0.69, blue: 0.63)
    /// Deep paddy-leaf olive green sampled from the rice leaves (`#5B651D`).
    static let wordmarkColor = Color(red: 0.357, green: 0.396, blue: 0.114)
    /// Mark frame sized so the visible rice (73% of canvas) sits at ~1.65x the 34pt wordmark cap height.
    static let logoSize: CGFloat = 54
    static let wordmarkSize: CGFloat = 34
    /// 4pt layout gap + 6.3pt canvas right margin = ~10.3pt optical gap (~0.43x cap height).
    static let lockupSpacing: CGFloat = 4
    /// Compensates for the rice mark's 10% left canvas padding so visible ink centers optically.
    static let lockupHorizontalOpticalOffset: CGFloat = -3
    static let lockupVerticalFraction: CGFloat = 0.44
    static let homeRiceVerticalFraction: CGFloat = 0.40
    static let footerHeightFraction: CGFloat = 0.55

    static let wordmarkWidth: CGFloat = {
        let font = UIFont.boldSystemFont(ofSize: wordmarkSize)
        return ceil(("BeBaduy" as NSString).size(withAttributes: [.font: font]).width)
    }()

    static func lockupGeometry(in size: CGSize) -> (riceCenter: CGPoint, wordmarkCenter: CGPoint) {
        let totalWidth = logoSize + lockupSpacing + wordmarkWidth
        let leadingX = size.width / 2 + lockupHorizontalOpticalOffset - totalWidth / 2
        let centerY = size.height * lockupVerticalFraction
        let riceCenter = CGPoint(x: leadingX + logoSize / 2, y: centerY)
        let wordmarkCenter = CGPoint(x: leadingX + logoSize + lockupSpacing + wordmarkWidth / 2, y: centerY)
        return (riceCenter, wordmarkCenter)
    }
}

/// Matches the native launch screen (`LaunchScreen.storyboard`) pixel-for-pixel.
struct LaunchSplashView: View {
    var body: some View {
        GeometryReader { geometry in
            let layout = LaunchSplashStyle.lockupGeometry(in: geometry.size)
            ZStack(alignment: .top) {
                LaunchSplashStyle.backgroundColor
                    .ignoresSafeArea()

                if let background = UIImage(named: "LaunchSplashBackground.jpg") {
                    Image(uiImage: background)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .accessibilityHidden(true)
                }

                if let waves = UIImage(named: "LaunchSplashWaves.png") {
                    Image(uiImage: waves)
                        .resizable()
                        .frame(width: geometry.size.width,
                               height: geometry.size.width * LaunchSplashStyle.footerHeightFraction)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
                        .accessibilityHidden(true)
                }

                if let rice = UIImage(named: "LaunchSplashRice.png") {
                    Image(uiImage: rice)
                        .resizable()
                        .scaledToFit()
                        .frame(width: LaunchSplashStyle.logoSize, height: LaunchSplashStyle.logoSize)
                        .position(layout.riceCenter)
                        .accessibilityHidden(true)
                }

                Text("BeBaduy")
                    .font(.system(size: LaunchSplashStyle.wordmarkSize, weight: .bold))
                    .foregroundStyle(LaunchSplashStyle.wordmarkColor)
                    .fixedSize()
                    .position(layout.wordmarkCenter)
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
