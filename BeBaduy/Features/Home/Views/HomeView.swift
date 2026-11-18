import SwiftUI

struct HomeView: View {
    let journey: JourneyViewModel
    let motion: MotionService
    @State private var model = HomeViewModel()
    @State private var onboardingReady = false
    @State private var selectedTab: HomeTab = .menu
    @State private var isTabCollapsed = false
    @State private var showsPrologue = false
    @State private var loadingDestination: HomeRoute?

    var body: some View {
        Group {
            if !journey.progress.introductionSeen {
                ZStack {
                    IntroductionView(
                        stageProgress: GrowthStage.onboardingStage(for: journey.progress).targetProgress,
                        onFirstFrame: { onboardingReady = true }
                    ) {
                        journey.finishIntroduction()
                    }
                    .allowsHitTesting(onboardingReady)
                    .accessibilityHidden(!onboardingReady)
                    if !onboardingReady { LaunchSplashView() }
                }
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack(path: $model.path) {
                        MenuView(
                            journey: journey,
                            showsBackground: selectedTab == .menu && model.path.isEmpty,
                            onPrologue: { showsPrologue = true },
                            open: startActivity,
                            onScroll: { oldOffset, newOffset in
                                updateTabBar(for: .menu, from: oldOffset, to: newOffset)
                            }
                        )
                        .navigationDestination(for: HomeRoute.self) { route in
                            switch route {
                            case .transition(let phase):
                                ChapterTransitionView(phase: phase, journey: journey) {
                                    if journey.continueFrom(phase) == nil,
                                       phase == .ngaleuitkeunPare, journey.progress.allComplete {
                                        journey.finishJourney()
                                        model.showsCompletion = true
                                    }
                                    model.path = []
                                }
                                .toolbar(.hidden, for: .navigationBar)
                                .toolbar(.hidden, for: .tabBar)
                            case .activity(let phase):
                                PhaseDestinationView(phase: phase, journey: journey, motion: motion) {
                                    guard model.path.last == .activity(phase) else { return }
                                    loadingDestination = nil
                                    model.path = [.transition(phase)]
                                }
                                .id(phase)
                                .environment(\.navigationSceneReady, {
                                    if loadingDestination == .activity(phase) { loadingDestination = nil }
                                })
                                .toolbar(.hidden, for: .tabBar)
                            }
                        }
                    }
                    .tabItem { Label("Menu", systemImage: "square.grid.2x2.fill") }
                    .tag(HomeTab.menu)
                    .toolbar(.hidden, for: .tabBar)
                    NavigationStack {
                        CardCollectionView(journey: journey, showsBackground: selectedTab == .collection) { oldOffset, newOffset in
                            updateTabBar(for: .collection, from: oldOffset, to: newOffset)
                        }
                    }
                    .tabItem { Label("Koleksi", systemImage: "rectangle.stack.fill") }
                    .tag(HomeTab.collection)
                    .toolbar(.hidden, for: .tabBar)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if model.path.isEmpty {
                        HStack {
                            CollapsibleHomeTabBar(selection: $selectedTab, isCollapsed: $isTabCollapsed)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 70, alignment: .bottom)
                    }
                }
                .tint(AppTheme.heading)
                .overlay {
                    if loadingDestination != nil {
                        ZStack {
                            Color(red: 0.20, green: 0.12, blue: 0.08)
                            LaunchLoadingIndicator(message: "Menyiapkan tahap…")
                                .accessibilityIdentifier("navigation.loading")
                        }
                        .ignoresSafeArea()
                    }
                }
                .fullScreenCover(isPresented: $model.showsCompletion) {
                    CompletionView(journey: journey) { model.showsCompletion = false }
                }
                .fullScreenCover(isPresented: $showsPrologue) {
                    ZStack(alignment: .topTrailing) {
                        IntroductionView(
                            stageProgress: GrowthStage.onboardingStage(for: journey.progress).targetProgress
                        ) {
                            showsPrologue = false
                        }
                        Button { showsPrologue = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.45), in: Circle())
                        }
                        .accessibilityLabel("Tutup prologue")
                        .padding(.top, 12)
                        .padding(.trailing, 20)
                    }
                    .preferredColorScheme(.dark)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func startActivity(_ phase: PhaseID) {
        guard journey.progress.isUnlocked(phase), loadingDestination == nil else { return }
        loadingDestination = .activity(phase)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            guard loadingDestination == .activity(phase) else { return }
            model.open(phase, journey: journey)
        }
    }

    private func updateTabBar(for tab: HomeTab, from oldOffset: CGFloat, to newOffset: CGFloat) {
        guard selectedTab == tab, model.path.isEmpty else { return }
        let delta = newOffset - oldOffset
        guard abs(delta) > 3 else { return }
        let shouldCollapse = delta > 0 && newOffset > 24
        guard shouldCollapse != isTabCollapsed else { return }
        withAnimation(.smooth(duration: 0.28)) {
            isTabCollapsed = shouldCollapse
        }
    }
}

private struct ChapterTransitionView: View {
    let phase: PhaseID
    let journey: JourneyViewModel
    let continueJourney: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var preview = HomePreviewViewModel()
    @State private var ready = false
    @State private var started = false
    @State private var showsInformation = false
    @State private var rewardIndex = 0

    var body: some View {
        let progress = started ? preview.progress : GrowthStage.allStages[phase.index].targetProgress
        ZStack {
            CinematicAtmosphereView(progress: progress, isActive: scenePhase == .active)
            SceneKitCropView(progress: progress, isActive: scenePhase == .active,
                             showsTreeFallEffects: started && !showsInformation,
                             onSettledFrame: started && !preview.isTransitioning && !showsInformation && scenePhase == .active ? {
                                 guard scenePhase == .active else { return }
                                 showsInformation = true
                             } : nil,
                             onFirstFrame: { ready = true })
                .ignoresSafeArea()
                .accessibilityHidden(true)
            if showsInformation {
                if journey.newlyEarnedCards.indices.contains(rewardIndex) {
                    let card = journey.newlyEarnedCards[rewardIndex]
                    ChapterRewardCard(card: card) {
                        if rewardIndex + 1 < journey.newlyEarnedCards.count {
                            rewardIndex += 1
                        } else {
                            continueJourney()
                        }
                    }
                    .id(card.id)
                } else {
                    ChapterRewardCard(card: .chapter(phase), alreadyOwned: true, continueJourney: continueJourney)
                }
            } else if !ready {
                LaunchLoadingIndicator(message: "Menyiapkan tahap…")
            }
        }
        .task(id: ready && scenePhase == .active) {
            guard ready, scenePhase == .active, !showsInformation else { return }
            preview.selectStage(phase.index, journey: journey.progress, reduceMotion: true)
            started = true
            preview.selectStage(phase.index + 1, journey: journey.progress, reduceMotion: reduceMotion)

        }
        .onChange(of: scenePhase) { _, state in
            if state != .active { preview.stop() }
        }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled && preview.isTransitioning { preview.stop() }
        }
        .onDisappear { preview.stop() }
    }
}

private struct ChapterRewardCard: View {
    let card: ChapterCard
    var alreadyOwned = false
    let continueJourney: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = 0.0
    @State private var emerging = false
    @State private var angle = 0.0
    @State private var turned = false
    @State private var readable = false

    var body: some View {
        GeometryReader { bounds in
            let width = min(330, bounds.size.width * 0.85, max(120, (bounds.size.height - 96) * 0.7))
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                ChapterCardFace(card: card, width: width, front: turned || reduceMotion)
                .overlay(alignment: .top) {
                    if alreadyOwned && readable {
                        Label("Sudah ada di koleksi", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.black.opacity(0.88), in: Capsule())
                            .padding(.top, 10)
                    }
                }
                .rotation3DEffect(.degrees(reduceMotion ? 0 : angle), axis: (0, 1, 0))
                .scaleEffect(reduceMotion || emerging ? 1 : 1.45)
                .opacity(reduceMotion || emerging ? 1 : 0)
                .background {
                    RadialGradient(colors: [.white, .yellow.opacity(0.9), .orange.opacity(0.4), .clear],
                                   center: .center, startRadius: 0, endRadius: width * 0.92)
                        .frame(width: width * 2, height: width * 2)
                        .opacity(reduceMotion ? 0 : glow)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .accessibilityHidden(!readable)
                Spacer(minLength: 0)
                LessonButton(title: "Ayo lanjut!", identifier: "continue", action: continueJourney)
                    .opacity(readable ? 1 : 0).disabled(!readable).accessibilityHidden(!readable)
                    .padding(.horizontal, 24)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .background(.black.opacity(reduceMotion || emerging ? 0.52 : 0))
        .task(id: reduceMotion) {
            if reduceMotion { emerging = true; glow = 0; angle = 0; turned = true; readable = true; return }
            guard !readable else { return }
            do {
                withAnimation(.easeOut(duration: 0.32)) { glow = 1 }
                try await Task.sleep(for: .milliseconds(320))
                withAnimation(.easeOut(duration: 0.58)) { emerging = true }
                withAnimation(.easeInOut(duration: 0.85)) { glow = 0 }
                try await Task.sleep(for: .milliseconds(440))
                withAnimation(.easeIn(duration: 0.2)) { angle = -90 }
                try await Task.sleep(for: .milliseconds(200))
            } catch { return }
            turned = true
            angle = 90
            do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            withAnimation(.easeOut(duration: 0.48), completionCriteria: .removed) {
                angle = 0
            } completion: { readable = true }
        }
    }
}

private enum HomeTab: Hashable {
    case menu
    case collection

    var title: String {
        switch self {
        case .menu: "Menu"
        case .collection: "Koleksi"
        }
    }

    var symbol: String {
        switch self {
        case .menu: "square.grid.2x2.fill"
        case .collection: "rectangle.stack.fill"
        }
    }
}

private struct CollapsibleHomeTabBar: View {
    @Binding var selection: HomeTab
    @Binding var isCollapsed: Bool

    var body: some View {
        HStack(spacing: 2) {
            if isCollapsed {
                Button {
                    withAnimation(.smooth(duration: 0.28)) { isCollapsed = false }
                } label: {
                    Image(systemName: selection.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 52, height: 52)
                }
                .accessibilityLabel("Buka tab")
            } else {
                tabButton(.menu)
                tabButton(.collection)
            }
        }
        .foregroundStyle(AppTheme.heading)
        .padding(4)
        .background(Color(red: 0.21, green: 0.13, blue: 0.09).opacity(0.94), in: Capsule())
        .overlay(Capsule().strokeBorder(AppTheme.heading.opacity(0.4)))
        .animation(.smooth(duration: 0.28), value: isCollapsed)
    }

    private func tabButton(_ tab: HomeTab) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 20, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(width: 82, height: 52)
            .background(selection == tab ? AppTheme.heading.opacity(0.22) : .clear, in: Capsule())
        }
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }
}
