import SwiftUI
struct NgaseukIntroductionView: View {
    var story = false
    var body: some View {
        if story {
            VStack(alignment: .leading, spacing: 20) {
                Spacer(minLength: 60)
                Text("Tahap 5 dari 11").font(.subheadline).foregroundStyle(.secondary)
                Text("Ngaseuk").font(.system(.largeTitle, design: .serif).weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text(NgaseukContent.storyIntroduction)
                    .font(.title3)
                StoryScrollCue(text: "Geser ke atas untuk mencoba")
                Spacer(minLength: 24)
            }.frame(maxWidth: 560, alignment: .leading)
        } else { IntroductionText(content: NgaseukContent.value) }
    }
}
