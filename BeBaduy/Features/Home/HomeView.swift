import SwiftUI

struct HomeView: View {
    let journey: JourneyViewModel
    let motion: MotionService
    @State private var showsNgahuma = false
    @State private var showsJourney = false
    @State private var pendingPhase: PhaseID?
    @State private var model = HomeViewModel()

    var body: some View {
        NavigationStack(path: $model.path) {
            HarvestHomeView(
                journey: journey,
                isActive: model.path.isEmpty && !showsJourney && !showsNgahuma && !model.showsCompletion,
                onResume: { model.open(journey.progress.currentPhase, journey: journey) },
                onJourney: { showsJourney = true },
                onExplore: { showsNgahuma = true },
                onCompletion: { model.showsCompletion = true }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PhaseID.self) { phase in
                PhaseDestinationView(phase: phase, journey: journey, motion: motion) {
                    if let next = journey.continueFrom(phase) { model.path = [next] }
                    else if phase == .ngaleuitkeunPare && journey.progress.allComplete {
                        journey.finishJourney(); model.path = []; model.showsCompletion = true
                    }
                }
                .toolbar(.visible, for: .navigationBar)
            }
            .fullScreenCover(isPresented: $showsNgahuma) { Ngahuma3DView() }
            .sheet(isPresented: $showsJourney, onDismiss: {
                if let phase = pendingPhase {
                    pendingPhase = nil
                    model.open(phase, journey: journey)
                }
            }) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            JourneyView(journey: journey) { phase in
                                pendingPhase = phase
                                showsJourney = false
                            }
                            NavigationLink("Tentang BeBaduy", destination: AboutView())
                                .frame(minHeight: 44)
                        }
                        .padding(AppTheme.margin)
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                    }
                    .background(AppTheme.background)
                    .navigationTitle("Dari huma ke leuit")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Tutup") { showsJourney = false }
                                .accessibilityIdentifier("home.journey.close")
                        }
                    }
                }
            }
            .sheet(isPresented: $model.showsCompletion) {
                CompletionView(journey: journey) { model.showsCompletion = false }
            }
        }
    }
}
