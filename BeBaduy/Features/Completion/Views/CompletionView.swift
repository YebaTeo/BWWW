import SwiftUI
struct CompletionView: View {
    let journey: JourneyViewModel
    let goHome: () -> Void
    @State private var showsRecap = false
    @State private var model = CompletionViewModel()
    var body: some View {
        ZStack {
            LessonBackdrop(asset: LandscapeState(phase: .ngaleuitkeunPare, isResult: true).assetName)
            GeometryReader { geometry in
            ScrollView {
            VStack(spacing: 24) {
                Spacer()
                if showsRecap {
                    Text("Yuk, pilih tahapan yang ingin kamu pelajari lagi!")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    JourneyView(journey: journey, showsRecap: true) { phase in
                        journey.open(phase)
                        goHome()
                    }
                    LessonButton(title: "Kembali ke halaman utama", identifier: "home", action: goHome)
                } else {
                    Text(model.title).font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader).accessibilityIdentifier("journey.completed")
                    Text(model.message).font(.title3).lineSpacing(4)
                    Spacer()
                    LessonButton(title: "Lihat kembali semua tahapan", identifier: "journey.recap") { showsRecap = true }
                }
            }.multilineTextAlignment(.leading).foregroundStyle(.white)
                .padding(28).frame(maxWidth: 560)
                .frame(minHeight: geometry.size.height).frame(maxWidth: .infinity)
            }
            }
        }.preferredColorScheme(.dark)
    }
}
