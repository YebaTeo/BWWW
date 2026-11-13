import SwiftUI

struct HomeView: View {
    let journey: JourneyViewModel
    let motion: MotionService
    @State private var showsLaunchSplash = true
    @State private var loadsFirstPreview = false
    @State private var showsJourney = false
    @State private var pendingTransitionFrom: Int?
    @State private var pendingPhase: PhaseID?
    @State private var model = HomeViewModel()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func finishLoadingPreview() {
        guard showsLaunchSplash || loadsFirstPreview else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            showsLaunchSplash = false
            loadsFirstPreview = false
        }
    }

    var body: some View {
        NavigationStack(path: $model.path) {
            ZStack {
                if journey.progress.introductionSeen {
                    WelcomeHomeView(
                        journey: journey,
                        onFirstFrame: finishLoadingPreview,
                        pendingTransitionFrom: $pendingTransitionFrom,
                        onOpen: { model.open($0, journey: journey) },
                        onJourney: { showsJourney = true },
                        onCompletion: { model.showsCompletion = true },
                        isActive: model.path.isEmpty && !showsJourney && !model.showsCompletion
                    )
                    .accessibilityHidden(showsLaunchSplash || loadsFirstPreview)
                    .allowsHitTesting(!showsLaunchSplash && !loadsFirstPreview)
                } else {
                    IntroductionView {
                        loadsFirstPreview = true
                    }
                    .accessibilityHidden(showsLaunchSplash || loadsFirstPreview)
                    .allowsHitTesting(!showsLaunchSplash && !loadsFirstPreview)
                    .onAppear(perform: finishLoadingPreview)
                }
                if showsLaunchSplash {
                    LaunchSplashView().transition(.opacity)
                } else if loadsFirstPreview {
                    ZStack {
                        LessonBackdrop(asset: "OnboardingNgahuma")
                        Color.black.opacity(0.35).ignoresSafeArea()
                        LaunchLoadingIndicator()
                            .accessibilityIdentifier("onboarding.loading")
                    }
                    .transition(.opacity)
                }
            }
            .task(id: loadsFirstPreview) {
                guard loadsFirstPreview, !journey.progress.introductionSeen else { return }
                // Give the loading view a frame before starting scene construction.
                do { try await Task.sleep(for: .milliseconds(80)) } catch { return }
                journey.finishIntroduction()
                journey.open(.narawas)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PhaseID.self) { phase in
                PhaseDestinationView(phase: phase, journey: journey, motion: motion) {
                    if journey.progress.record(for: phase).explanationAvailable,
                       let stage = GrowthStage.allStages.first(where: { $0.phase == phase }) {
                        pendingTransitionFrom = stage.id
                    }
                    if journey.continueFrom(phase) != nil { model.path = [] }
                    else if phase == .ngaleuitkeunPare && journey.progress.allComplete {
                        journey.finishJourney(); model.path = []; model.showsCompletion = true
                    } else {
                        model.path = []
                    }
                }
                .id(phase)
            }
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
            .fullScreenCover(isPresented: $model.showsCompletion) {
                CompletionView(journey: journey) { model.showsCompletion = false }
            }
        }
    }
}
