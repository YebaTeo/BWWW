import SwiftUI
struct NgoredIntroductionView: View {
    var story = false
    var body: some View {
        if story {
            VStack(alignment: .leading, spacing: 20) {
                Spacer(minLength: 60)
                Label("Setelah beberapa waktu", systemImage: "sun.horizon").font(.subheadline).foregroundStyle(.secondary)
                Text("Tahap 6 dari 11").font(.subheadline).foregroundStyle(.secondary)
                Text("Ngored").font(.system(.largeTitle, design: .serif).weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text("Padi muda tumbuh bersama tumbuhan lain. Saatnya mengenali gulma dan merawat padi dengan hati-hati.").font(.title3)
                Text("Perhatikan padi muda dan tumbuhan di sekitarnya.").foregroundStyle(.secondary)
                Spacer(minLength: 24)
            }.frame(maxWidth: 560, alignment: .leading)
        } else { IntroductionText(content: NgoredContent.value) }
    }
}
