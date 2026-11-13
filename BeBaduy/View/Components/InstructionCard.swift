import SwiftUI

struct InstructionCard: View {
    let title: String
    let message: String
    var identifier = "activity.instruction"
    let action: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color(red: 1, green: 0.65, blue: 0.25))
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
            LessonButton(title: "Lanjut", identifier: identifier + ".continue", action: action)
        }
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}
