import SwiftUI
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
