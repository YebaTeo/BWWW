import SwiftUI
struct HomeView: View {
    let journey: JourneyViewModel
    let motion: MotionService
    @State private var showsNgahuma = false
    @State private var model = HomeViewModel()
    var body: some View {
        NavigationStack(path: $model.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Dari huma\nke leuit.").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    Text("Kenali perjalanan padi dan pengetahuan masyarakat Baduy, satu kegiatan setiap kali.").font(.title3)
                    LandscapeView(state: LandscapeState(phase: .narawas, isResult: false), label: "Huma di antara perbukitan dan pepohonan")
                    PrimaryButton(title: journey.completedCount == 0 ? "Mulai belajar" : "Lanjutkan belajar", identifier: "resume") {
                        model.open(journey.progress.currentPhase, journey: journey)
                    }
                    if let message = journey.storageMessage { Text(message).font(.footnote) }
                    Text("\(journey.completedCount) dari 11 tahap telah dijelajahi").font(.subheadline).foregroundStyle(.secondary)
                    if journey.progress.journeyCompleted {
                        Button("Lihat perjalanan selesai") { model.showsCompletion = true }.frame(minHeight: 44)
                    }
                    Button("Jelajahi huma 3D") { showsNgahuma = true }
                        .frame(minHeight: 44).accessibilityIdentifier("ngahuma.open")
                    Text("Lingkungan interaktif tanpa kamera").font(.caption).foregroundStyle(.secondary)
                    JourneyView(journey: journey) { model.open($0, journey: journey) }
                    NavigationLink("Tentang BeBaduy", destination: AboutView()).frame(minHeight: 44)
                }.padding(AppTheme.margin).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(AppTheme.background).navigationTitle("BeBaduy")
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: PhaseID.self) { phase in
                PhaseDestinationView(phase: phase, journey: journey, motion: motion) {
                    if let next = journey.continueFrom(phase) { model.path = [next] }
                    else if phase == .ngaleuitkeunPare && journey.progress.allComplete {
                        journey.finishJourney(); model.path = []; model.showsCompletion = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showsNgahuma) {
                Ngahuma3DView()
            }
            .sheet(isPresented: $model.showsCompletion) { CompletionView(journey: journey) { model.showsCompletion = false } }
        }
    }
}
