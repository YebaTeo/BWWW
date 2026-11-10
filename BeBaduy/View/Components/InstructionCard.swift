import SwiftUI

struct InstructionCard: View {
    let title: String
    let message: String
    var identifier = "activity.instruction"
    let action: () -> Void
    @ScaledMetric(relativeTo: .title3) private var headingSize = 24.0
    @ScaledMetric(relativeTo: .body) private var bodySize = 20.0

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: headingSize, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.heading)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.system(size: bodySize, design: .rounded))
                .foregroundStyle(AppTheme.cream)
            LessonButton(title: "Lanjut", identifier: identifier + ".continue", action: action)
        }
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}
