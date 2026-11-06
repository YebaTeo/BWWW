import SwiftUI
struct InstructionCard: View {
    let title: String
    let message: String
    var identifier = "activity.instruction"
    let action: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Button(action: action) {
                VStack(spacing: 10) {
                    Text(title).font(.title3.bold())
                    Text(message).font(.body)
                }.frame(maxWidth: .infinity).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier(identifier)
            LessonButton(title: "Lanjut", identifier: identifier + ".continue", action: action)
        }.multilineTextAlignment(.center).padding(20)
            .foregroundStyle(.black.opacity(0.85))
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .environment(\.colorScheme, .light)
    }
}
