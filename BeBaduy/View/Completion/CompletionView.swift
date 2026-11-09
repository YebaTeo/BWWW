import SwiftUI
struct CompletionView: View {
    let journey: JourneyViewModel
    let goHome: () -> Void
    @State private var model = CompletionViewModel()
    var body: some View {
        ZStack {
            LessonBackdrop(asset: LandscapeState(phase: .ngaleuitkeunPare, isResult: true).assetName)
            GeometryReader { geometry in
            ScrollView {
            VStack(spacing: 24) {
                Spacer()
                Text("Siklus berladang sudah selesai.").font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("journey.completed")
                Text(model.message).font(.title3).lineSpacing(4)
                Spacer()
                LessonButton(title: "Jelajah ulang", identifier: "home", action: goHome)
            }.multilineTextAlignment(.center).foregroundStyle(.white)
                .padding(28).frame(maxWidth: 560)
                .frame(minHeight: geometry.size.height).frame(maxWidth: .infinity)
            }
            }
        }.preferredColorScheme(.dark)
    }
}
