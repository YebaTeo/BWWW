import SwiftUI

struct LessonButton: View {
    let title: String
    var identifier = ""
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 20)
                .background(Color(red: 0.12, green: 0.31, blue: 0.62), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
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
                    .init(color: .black.opacity(0.58), location: 0),
                    .init(color: .black.opacity(0.58), location: 0.35),
                    .init(color: .black.opacity(0.64), location: 0.58),
                    .init(color: .black.opacity(0.8), location: 1)
                ], startPoint: .top, endPoint: .bottom))
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}
