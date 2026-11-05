import SwiftUI
struct NgaseukDescriptionView: View {
    var story = false
    var body: some View {
        if story {
            VStack(alignment: .leading, spacing: 20) {
                Spacer(minLength: 60)
                Text("Benih sudah ditanam").font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(NgaseukContent.value.explanation).font(.title3)
                Text(NgaseukContent.storySeedReminder).foregroundStyle(.secondary)
                StoryScrollCue(text: "Geser ke atas untuk melanjutkan cerita")
                Spacer(minLength: 24)
            }.frame(maxWidth: 560, alignment: .leading)
        } else { ReflectionText(content: NgaseukContent.value) }
    }
}
