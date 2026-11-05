import SwiftUI
struct PhaseHeaderView: View {
    let content: PhaseContent
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tahap \(content.id.index + 1) dari 11").font(.subheadline).foregroundStyle(.white.opacity(0.85))
            Text(content.title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            Text(content.subtitle).font(.title3).foregroundStyle(.white.opacity(0.85))
        }
    }
}
struct IntroductionText: View {
    let content: PhaseContent
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let cue = content.timeCue { Label(cue, systemImage: "sun.horizon").font(.subheadline).foregroundStyle(AppTheme.leaf) }
            Text(content.introduction)
            Text(content.instruction).fontWeight(.medium)
        }
    }
}
struct ReflectionText: View {
    let content: PhaseContent
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Yang kita pelajari").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text(content.result).font(.headline)
            Text(content.explanation)
        }.accessibilityIdentifier("reflection")
    }
}
