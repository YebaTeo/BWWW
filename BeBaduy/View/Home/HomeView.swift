import SwiftUI

struct HomeView: View {
    let journey: JourneyViewModel
    let motion: MotionService
    @State private var showsLaunchSplash = true
    @State private var loadsFirstPreview = false
    @State private var showsIntroduction = true
    @State private var showsJourney = false
    @State private var reopenIntroduction = false
    @State private var pendingTransitionFrom: Int?
    @State private var pendingPhase: PhaseID?
    @State private var model = HomeViewModel()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var introductionProgress: CGFloat {
        GrowthStage.onboardingStage(for: journey.progress).targetProgress
    }

    private var shouldShowIntroduction: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting"), arguments.contains(where: { $0.hasPrefix("--uitest-") }) {
            return false
        }
        #endif
        return showsIntroduction
    }

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
                if !shouldShowIntroduction {
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
                    IntroductionView(stageProgress: introductionProgress, onFirstFrame: finishLoadingPreview) {
                        if !journey.progress.introductionSeen {
                            journey.finishIntroduction()
                            journey.open(.narawas)
                        }
                        showsIntroduction = false
                        loadsFirstPreview = true
                    }
                    .accessibilityHidden(showsLaunchSplash || loadsFirstPreview)
                    .allowsHitTesting(!showsLaunchSplash && !loadsFirstPreview)
                }
                if showsLaunchSplash {
                    LaunchSplashView().transition(.opacity)
                } else if loadsFirstPreview {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        LaunchLoadingIndicator()
                            .accessibilityIdentifier("onboarding.loading")
                    }
                    .transition(.opacity)
                }
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
            .fullScreenCover(isPresented: $showsJourney, onDismiss: {
                if reopenIntroduction {
                    reopenIntroduction = false
                    showsIntroduction = true
                    return
                }
                if let phase = pendingPhase {
                    pendingPhase = nil
                    model.open(phase, journey: journey)
                }
            }) {
                NavigationStack {
                ZStack(alignment: .topLeading) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            JourneyView(journey: journey, onPrologue: {
                                reopenIntroduction = true
                                showsJourney = false
                            }) { phase in
                                pendingPhase = phase
                                showsJourney = false
                            }
                            NavigationLink(destination: AboutView()) {
                            Text("Tentang BeBaduy")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                            }
                        }
                        .padding(.top, 72)
                        .padding(.bottom, 36)
                        .frame(maxWidth: 540)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                    Button { showsJourney = false } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.3), in: Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.42), lineWidth: 0.7))
                    }
                    .accessibilityLabel("Kembali")
                    .accessibilityIdentifier("home.journey.close")
                    .padding(.leading, 20)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    CinematicAtmosphereView(progress: introductionProgress, isActive: false)
                        .blur(radius: 16)
                        .overlay(Color(red: 0.20, green: 0.12, blue: 0.08).opacity(0.34))
                        .ignoresSafeArea()
                }
                .toolbar(.hidden, for: .navigationBar)
                }
                .preferredColorScheme(.dark)
            }
            .fullScreenCover(isPresented: $model.showsCompletion) {
                CompletionView(journey: journey) { model.showsCompletion = false }
            }
        }
    }
}
