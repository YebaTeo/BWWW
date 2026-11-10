import SwiftUI
struct ReflectionText: View {
    let content: PhaseContent
    var body: some View {
        VStack(spacing: 20) {
            Text("Yang kita pelajari").font(.system(.title2, design: .rounded).bold()).accessibilityAddTraits(.isHeader)
            Text(content.result).font(.headline)
            Text(content.explanation)
        }.multilineTextAlignment(.center).accessibilityIdentifier("reflection")
    }
}
