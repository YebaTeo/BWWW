import SwiftUI

struct ChapterIntroductionView: View {
    let content: PhaseContent
    let viewportHeight: CGFloat
    let canReview: Bool
    let explore: () -> Void
    let review: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 48.0
    @ScaledMetric(relativeTo: .body) private var bodySize = 20.0
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: typeSize.isAccessibilitySize ? 28 : viewportHeight * 0.30)

                VStack(spacing: 10) {
                    Text(content.title.uppercased())
                        .font(.system(size: titleSize, weight: .black))
                        .foregroundStyle(AppTheme.orange)
                        .fontWidth(.condensed)
                        .accessibilityAddTraits(.isHeader)
                    Text(content.introduction)
                        .font(.system(size: bodySize, design: .rounded))
                        .foregroundStyle(AppTheme.cream)
                        .frame(maxWidth: 330)
                    LessonButton(title: "Jelajahi", identifier: "start") { explore() }
                        .frame(maxWidth: 190)
                        .padding(.top, 8)
                    if canReview {
                        Button("Lihat penjelasan") { review() }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("lesson.explanation")
                    }
                }
                .multilineTextAlignment(.center)
                .padding(20)
                .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 20)

                Spacer(minLength: typeSize.isAccessibilitySize ? 28 : viewportHeight * 0.12)

                VStack(spacing: 2) {
                    Text("Geser ke atas untuk mulai aktivitas.")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.down.2")
                        .font(.system(size: 15, weight: .regular))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: 300)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, minHeight: max(0, viewportHeight - 80))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        }
        .simultaneousGesture(DragGesture(minimumDistance: 60).onEnded { value in
            guard !typeSize.isAccessibilitySize, value.translation.height < -80,
                  abs(value.translation.height) > abs(value.translation.width) else { return }
            explore()
        })
    }
}
