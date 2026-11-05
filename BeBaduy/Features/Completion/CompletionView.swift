import SwiftUI
struct CompletionView: View {
    let journey: JourneyViewModel
    let goHome: () -> Void
    @State private var model = CompletionViewModel()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(model.title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    LandscapeView(state: LandscapeState(phase: .ngaleuitkeunPare, isResult: true), label: "Padi tersimpan di dalam leuit")
                    Text(model.message)
                    PrimaryButton(title: "Kunjungi tahap di beranda", identifier: "home", action: goHome)
                    NavigationLink("Kenali Baduy lebih dekat", destination: AboutView())
                }.padding(24)
            }.background(AppTheme.background).navigationTitle("Perjalanan selesai")
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
