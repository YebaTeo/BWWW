import SwiftUI

/// Shared loading indicator rendered across scene setup, asset preparation, navigation, and thumbnail loads.
struct ReusableLoadingView: View {
    enum Style: Equatable {
        /// Compact spinner for tight thumbnail, icon, and 3D preview slots.
        case compact
        /// Floating warm pill with status message over an active canvas.
        case card
        /// Fullscreen overlay with a neutral background.
        case fullscreen
    }

    var message: LocalizedStringKey = "Memuat…"
    var style: Style = .card
    var identifier: String? = nil

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        switch style {
        case .compact:
            ProgressView()
                .tint(AppTheme.cream)
                .accessibilityLabel(message)
                .modifier(OptionalAccessibilityIdentifier(identifier: identifier))
        case .card:
            cardView
                .modifier(OptionalAccessibilityIdentifier(identifier: identifier))
        case .fullscreen:
            ZStack {
                Color(red: 0.14, green: 0.09, blue: 0.06).ignoresSafeArea()
                cardView
                    .modifier(OptionalAccessibilityIdentifier(identifier: identifier))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }

    private var cardView: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return ProgressView(message)
            .font(.subheadline.weight(.medium))
            .tint(AppTheme.cream)
            .foregroundStyle(AppTheme.cream)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                Color(red: 0.14, green: 0.09, blue: 0.06)
                    .opacity(reduceTransparency ? 0.98 : 0.84),
                in: shape
            )
            .overlay {
                shape.strokeBorder(AppTheme.heading.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

#Preview("Card") {
    ZStack {
        LessonBackdrop(asset: "LaunchLandscape")
        ReusableLoadingView(message: "Menyiapkan tahap…", style: .card)
    }
}

#Preview("Fullscreen") {
    ReusableLoadingView(message: "Menyiapkan lahan…", style: .fullscreen)
}

#Preview("Compact") {
    ZStack {
        Color.brown
        ReusableLoadingView(style: .compact)
    }
}
