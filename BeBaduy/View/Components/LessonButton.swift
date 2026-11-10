import SwiftUI

struct LessonButton: View {
    let title: String
    var identifier = ""
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.cream)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 20)
                .background(AppTheme.action, in: Capsule())
                .overlay(Capsule().stroke(AppTheme.cream.opacity(0.45), lineWidth: 1))
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
    }
}

struct LessonBackdrop: View {
    let asset: String
    var body: some View {
        GeometryReader { bounds in
            Image(asset).resizable().scaledToFill()
                .frame(width: bounds.size.width, height: bounds.size.height).clipped()
                .overlay(LinearGradient(stops: [
                    .init(color: .black.opacity(0.28), location: 0),
                    .init(color: .black.opacity(0.12), location: 0.15),
                    .init(color: .clear, location: 0.30),
                    .init(color: .clear, location: 0.60),
                    .init(color: .black.opacity(0.25), location: 0.80),
                    .init(color: .black.opacity(0.48), location: 1)
                ], startPoint: .top, endPoint: .bottom))
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}
