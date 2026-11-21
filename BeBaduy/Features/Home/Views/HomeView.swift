import SwiftUI

struct HomeView: View {
    let journey: JourneyViewModel
    let motion: MotionService
    @State private var model = HomeViewModel()
    @State private var onboardingReady = false
    @State private var selectedTab: HomeTab = .menu
    @State private var isTabCollapsed = false
    @State private var loadingDestination: HomeRoute?
    @State private var loadingPreview: UIImage?
    @State private var showsHomeLanding = true
    @State private var showsSplash = true
    @State private var landscapeViewportHeight: CGFloat?
    @State private var collectionPath = NavigationPath()
    @State private var selectedCollectionCard: ChapterCard?

    private var skipsLaunchPresentationForTests: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--uitesting") && !arguments.contains("--show-home-landing")
        #else
        return false
        #endif
    }

    var body: some View {
        Group {
            if !skipsLaunchPresentationForTests && showsSplash {
                LaunchSplashView()
                    .task {
                        try? await Task.sleep(for: .milliseconds(650))
                        showsSplash = false
                    }
            } else if !skipsLaunchPresentationForTests && showsHomeLanding {
                LandingToMenuTransition(journey: journey) { height in
                    landscapeViewportHeight = height
                    showsHomeLanding = false
                }
            } else if !journey.progress.introductionSeen {
                ZStack {
                    IntroductionView(
                        stageProgress: GrowthStage.onboardingStage(for: journey.progress).targetProgress,
                        onFirstFrame: { onboardingReady = true }
                    ) {
                        journey.finishIntroduction()
                    }
                    .allowsHitTesting(onboardingReady)
                    .accessibilityHidden(!onboardingReady)
                    if !onboardingReady {
                        ReusableLoadingView(
                            message: "Menyiapkan perjalanan…",
                            style: .fullscreen(backdrop: "HumaSunsetValley"),
                            identifier: "onboarding.loading"
                        )
                    }
                }
                .task {
                    try? await Task.sleep(for: .seconds(12))
                    if !onboardingReady { onboardingReady = true }
                }
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack(path: $model.path) {
                        MenuView(
                            journey: journey,
                            showsBackground: selectedTab == .menu && model.path.isEmpty,
                            isActive: selectedTab == .menu && model.path.isEmpty,
                            landscapeViewportHeight: landscapeViewportHeight,
                            open: { model.path = [.stage($0)] },
                            onScroll: { oldOffset, newOffset in
                                updateTabBar(for: .menu, from: oldOffset, to: newOffset)
                            }
                        )
                        .navigationDestination(for: HomeRoute.self) { route in
                            switch route {
                            case .stage(let phase):
                                StagePreviewScreen(stage: GrowthStage.allStages[phase.index]) {
                                    startActivity(phase)
                                }
                            case .transition(let phase):
                                ChapterTransitionView(phase: phase, journey: journey) {
                                    if let next = journey.continueFrom(phase) {
                                        model.path = [.stage(next)]
                                        return
                                    }
                                    model.path = []
                                }
                                .toolbar(.hidden, for: .navigationBar)
                                .toolbar(.hidden, for: .tabBar)
                            case .activity(let phase):
                                PhaseDestinationView(phase: phase, journey: journey, motion: motion) {
                                    guard model.path.last == .activity(phase) else { return }
                                    loadingDestination = nil
                                    if phase == .ngaleuitkeunPare {
                                        model.path = []
                                    } else {
                                        model.path = [.transition(phase)]
                                    }
                                }
                                .id(phase)
                                .environment(\.navigationSceneReady, {
                                    if loadingDestination == .activity(phase) {
                                        loadingDestination = nil
                                        loadingPreview = nil
                                    }
                                })
                                .toolbar(.hidden, for: .tabBar)
                            }
                        }
                    }
                    .tabItem { Label("Ngahuma", systemImage: "leaf.fill") }
                    .tag(HomeTab.menu)
                    .toolbar(.hidden, for: .tabBar)
                    NavigationStack(path: $collectionPath) {
                        CardCollectionView(
                            journey: journey,
                            showsBackground: selectedTab == .collection && collectionPath.isEmpty,
                            isActive: selectedTab == .collection && collectionPath.isEmpty,
                            onSelect: { selectedCollectionCard = $0 },
                            onScroll: { oldOffset, newOffset in
                                updateTabBar(for: .collection, from: oldOffset, to: newOffset)
                            }
                        )
                    }
                    .tabItem { Label("Koleksi", systemImage: "rectangle.stack.fill") }
                    .tag(HomeTab.collection)
                    .toolbar(.hidden, for: .tabBar)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if model.path.isEmpty && collectionPath.isEmpty {
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
                    if let card = selectedCollectionCard {
                        CollectionCardPresentation(card: card) {
                            selectedCollectionCard = nil
                        }
                        .id(card)
                    }
                }
                .accessibilityHidden(loadingDestination != nil)
                .allowsHitTesting(loadingDestination == nil)
                .overlay {
                    if loadingDestination != nil {
                        Color.black.ignoresSafeArea()
                        if let loadingPreview {
                            Image(uiImage: loadingPreview).resizable().ignoresSafeArea().accessibilityHidden(true)
                        }
                        ReusableLoadingView(
                            message: "Menyiapkan tahap…",
                            style: .fullscreen(),
                            identifier: "navigation.loading"
                        )
                    }
                }
                .task(id: loadingDestination) {
                    guard case .activity(let phase) = loadingDestination else { return }
                    do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
                    guard loadingDestination == .activity(phase) else { return }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { model.open(phase, journey: journey) }
                    do { try await Task.sleep(for: .seconds(12)) } catch { return }
                    if loadingDestination == .activity(phase) {
                        withTransaction(transaction) { model.path = [.stage(phase)] }
                        loadingPreview = nil
                        loadingDestination = nil
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func startActivity(_ phase: PhaseID) {
        guard journey.progress.isUnlocked(phase), loadingDestination == nil else { return }
        if let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?.keyWindow {
            loadingPreview = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
            }
        }
        loadingDestination = .activity(phase)
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

private struct LandingToMenuTransition: View {
    let journey: JourneyViewModel
    let returning: Bool
    let complete: (CGFloat) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat
    @State private var dragStartProgress: CGFloat?
    @State private var didComplete = false
    @State private var tabSelection: HomeTab = .menu
    @State private var tabCollapsed = false

    init(journey: JourneyViewModel, returning: Bool = false, complete: @escaping (CGFloat) -> Void) {
        self.journey = journey
        self.returning = returning
        self.complete = complete
        _progress = State(initialValue: returning ? 1 : 0)
    }

    var body: some View {
        GeometryReader { safeGeometry in
            GeometryReader { geometry in
                let height = geometry.size.height
                ZStack {
                    MenuView(
                        journey: journey,
                        showsIntroText: false,
                        transitionTopInset: safeGeometry.safeAreaInsets.top,
                        landscapeViewportHeight: height,
                        open: { _ in },
                        onScroll: { _, _ in }
                    )
                    .offset(y: (1 - progress) * height)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    HomeLandingView()
                        .offset(y: -progress * height)
                        .contentShape(Rectangle())
                        .highPriorityGesture(landingDrag(height: height))

                    VStack {
                        Spacer()
                        Button {
                            snapToMenu(fromGesture: false, viewportHeight: height)
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: geometry.size.width - 80, height: 48)
                        }
                        .accessibilityLabel("Lanjut ke perjalanan")
                        .accessibilityIdentifier("home.landing.continue")
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20) + 12)
                    }
                    .opacity(1 - progress)
                    .offset(y: -progress * height)

                    LandingIntroText(progress: progress, topSafeAreaInset: safeGeometry.safeAreaInsets.top)
                        .allowsHitTesting(false)

                    VStack {
                        Spacer()
                        HStack {
                            CollapsibleHomeTabBar(selection: $tabSelection, isCollapsed: $tabCollapsed)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 70, alignment: .bottom)
                    }
                    .opacity(progress)
                    .offset(y: (1 - progress) * 24)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                .frame(width: geometry.size.width, height: height)
                .clipped()
                .task {
                    guard returning else { return }
                    try? await Task.sleep(for: .milliseconds(30))
                    snapToLanding(viewportHeight: height)
                }
            }
            .ignoresSafeArea()
        }
        .background(Color(red: 0.19, green: 0.20, blue: 0.15))
        .preferredColorScheme(.light)
    }

    private func landingDrag(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !didComplete else { return }
                if dragStartProgress == nil { dragStartProgress = progress }
                progress = min(1, max(0, (dragStartProgress ?? 0) - value.translation.height / height))
            }
            .onEnded { value in
                dragStartProgress = nil
                let projected = progress - (value.predictedEndTranslation.height - value.translation.height) / height
                if progress > 0.28 || projected > 0.50 {
                    snapToMenu(fromGesture: true, viewportHeight: height)
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.96)) {
                        progress = 0
                    }
                }
            }
    }

    private func snapToMenu(fromGesture: Bool, viewportHeight: CGFloat) {
        guard !didComplete else { return }
        if reduceMotion {
            finish(viewportHeight: viewportHeight)
            return
        }
        let animation: Animation = fromGesture
            ? .spring(response: 0.46, dampingFraction: 0.98)
            : .smooth(duration: 0.42)
        withAnimation(animation, completionCriteria: .logicallyComplete) {
            progress = 1
        } completion: {
            guard progress > 0.999 else { return }
            finish(viewportHeight: viewportHeight)
        }
    }

    private func snapToLanding(viewportHeight: CGFloat) {
        guard !didComplete else { return }
        if reduceMotion {
            finish(viewportHeight: viewportHeight)
            return
        }
        withAnimation(.spring(response: 0.46, dampingFraction: 0.98), completionCriteria: .logicallyComplete) {
            progress = 0
        } completion: {
            guard progress < 0.001 else { return }
            finish(viewportHeight: viewportHeight)
        }
    }

    private func finish(viewportHeight: CGFloat) {
        guard !didComplete else { return }
        didComplete = true
        if !returning && !journey.progress.introductionSeen { journey.finishIntroduction() }
        complete(viewportHeight)
    }
}

private struct HomeLandingView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Image("JourneyLandscapeSoil")
                    .resizable()
                    .frame(width: geometry.size.width, height: geometry.size.height * 1.9)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .clipped()
                    .accessibilityHidden(true)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.62),
                        .init(color: .black.opacity(0.12), location: 0.78),
                        .init(color: .black.opacity(0.42), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

private struct LandingIntroText: View {
    let progress: CGFloat
    let topSafeAreaInset: CGFloat
    @ScaledMetric(relativeTo: .title) private var landingTitleSize: CGFloat = 25
    @ScaledMetric(relativeTo: .title) private var menuTitleSize: CGFloat = 29
    @ScaledMetric(relativeTo: .body) private var landingBodySize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var menuBodySize: CGFloat = 17
    @State private var copyHeight: CGFloat = 170

    var body: some View {
        GeometryReader { geometry in
            let horizontal: CGFloat = 27
            let width = geometry.size.width - 2 * horizontal
            let landingBottom = geometry.size.height - max(geometry.safeAreaInsets.bottom, 20) - 75
            let menuTop = topSafeAreaInset + 26
            let top = (landingBottom - copyHeight) * (1 - progress) + menuTop * progress
            VStack(alignment: .leading, spacing: 20 - 6 * progress) {
                Text(JourneyIntroCopy.title)
                    .font(.system(size: landingTitleSize + (menuTitleSize - landingTitleSize) * progress,
                                  weight: .bold, design: .rounded))
                    .accessibilityAddTraits(.isHeader)
                Text(JourneyIntroCopy.description)
                    .font(.system(size: landingBodySize + (menuBodySize - landingBodySize) * progress,
                                  weight: .medium))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.65), radius: 5, y: 2)
            .frame(width: width, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _, newHeight in
                copyHeight = newHeight
            }
            .position(x: horizontal + width / 2, y: top + copyHeight / 2)
        }
        .accessibilityHidden(progress > 0.5)
    }
}

private struct StagePreviewScreen: View {
    let stage: GrowthStage
    let openSelectedChapter: () -> Void
    @State private var sceneReady = false
    private let ivory = Color(red: 0.99, green: 0.97, blue: 0.92)
    private let gold = Color(red: 1, green: 0.62, blue: 0.14)

    var body: some View {
        GeometryReader { viewport in
            ZStack(alignment: .bottom) {
                CinematicAtmosphereView(progress: stage.targetProgress, isActive: true)
                SceneKitCropView(
                    progress: stage.targetProgress,
                    isActive: true,
                    showsTreeFallEffects: false,
                    onFirstFrame: { sceneReady = true }
                )
                .ignoresSafeArea()
                VStack(spacing: 0) {
                    stageCard
                    actions
                }
                .frame(maxWidth: 440)
                .padding(.horizontal, 12)
                .padding(.bottom, viewport.size.height * 0.14)
                .allowsHitTesting(sceneReady)
                .accessibilityHidden(!sceneReady)

                if !sceneReady {
                    ReusableLoadingView(
                        message: "Menyiapkan tahap…",
                        style: .fullscreen(),
                        identifier: "stage.preview.loading"
                    )
                }
            }
        }
        .foregroundStyle(ivory)
        .task {
            try? await Task.sleep(for: .seconds(8))
            if !sceneReady { sceneReady = true }
        }
    }

    private var stageCard: some View {
        VStack(spacing: 8) {
            Text(stage.name)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .fontWidth(.condensed)
                .tracking(1)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(gold)
                .shadow(color: .black.opacity(0.78), radius: 10, y: 3)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home.stage.title")
            Text(stage.narrative)
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.9), radius: 7, y: 2)

        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
    }

    private var actions: some View {
        Button(action: openSelectedChapter) {
            Text(stage.isConclusion ? "Lihat Rangkuman" : "Ikut \(PhaseContent.content(for: stage.phase).title)")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ivory)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color(red: 0.86, green: 0.35, blue: 0.01), in: Capsule())
                .overlay(Capsule().strokeBorder(Color(red: 1, green: 0.62, blue: 0.24), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("resume")
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 18)
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
    @State private var showsInformation = true
    @State private var rewardIndex = 0

    var body: some View {
        let progress = started ? preview.progress : GrowthStage.allStages[phase.index].targetProgress
        ZStack {
            CinematicAtmosphereView(progress: progress, isActive: scenePhase == .active)
            SceneKitCropView(progress: progress, isActive: scenePhase == .active,
                             showsTreeFallEffects: started && !showsInformation,
                             onSettledFrame: started && !preview.isTransitioning && !showsInformation && scenePhase == .active ? {
                                 guard scenePhase == .active else { return }
                                 continueJourney()
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
                            showsInformation = false
                        }
                    }
                    .id(card.id)
                } else {
                    ChapterRewardCard(card: .chapter(phase, secondCycle: journey.progress.secondCycle), alreadyOwned: true) { showsInformation = false }
                }
            } else if !ready {
                ReusableLoadingView(
                    message: "Menyiapkan tahap…",
                    style: .fullscreen(),
                    identifier: "transition.loading"
                )
            }
            if started && !showsInformation {
                Button("Lewati animasi") {
                    preview.stop()
                    continueJourney()
                }
                .font(.subheadline.weight(.semibold))
                .padding(12)
                .background(.black.opacity(0.7), in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(20)
                .accessibilityIdentifier("transition.skip")
            }
        }
        .task(id: !showsInformation && !ready) {
            guard !showsInformation, !ready else { return }
            try? await Task.sleep(for: .seconds(8))
            if !ready { ready = true }
        }
        .task(id: ready && !showsInformation && scenePhase == .active) {
            guard ready, scenePhase == .active, !showsInformation, !started else { return }
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

struct ChapterRewardCard: View {
    let card: ChapterCard
    var alreadyOwned = false
    var isPresented = true
    let continueJourney: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = 0.0
    @State private var emerging = false
    @State private var angle = 0.0
    @State private var tapped = false
    @State private var turned = false
    @State private var readable = false

    var body: some View {
        GeometryReader { bounds in
            let width = min(330, bounds.size.width * 0.85, max(120, (bounds.size.height - 96) * 0.7))
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                ChapterCardFace(card: card, width: width, front: turned)
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
                .scaleEffect(reduceMotion || emerging ? 1 : card.isEpic ? 0.22 : 1.45)
                .opacity(reduceMotion || emerging ? 1 : 0)
                .background {
                    RadialGradient(colors: [.white, .yellow.opacity(0.9), .orange.opacity(0.4), .clear],
                                   center: .center, startRadius: 0, endRadius: width * 0.92)
                        .frame(width: width * 2, height: width * 2)
                        .opacity(reduceMotion ? 0 : glow)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .overlay {
                    if isPresented && !tapped {
                        Button { tapped = true } label: { Color.clear.contentShape(Rectangle()) }
                            .accessibilityLabel("Ketuk untuk membuka kartu")
                    }
                }
                Spacer(minLength: 0)
                LessonButton(title: card.isEpic ? "Kembali ke menu" : "Ayo lanjut!",
                             identifier: "continue", action: continueJourney)
                    .opacity(readable ? 1 : 0).disabled(!readable).accessibilityHidden(!readable)
                    .padding(.horizontal, 24)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .background(.black.opacity(reduceMotion || emerging ? 0.52 : 0))
        .task(id: isPresented) {
            guard isPresented else { return }
            if reduceMotion { emerging = true; return }
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.spring(duration: 0.7, bounce: 0.08)) { emerging = true }
        }
        .task(id: tapped) {
            guard tapped else { return }
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
        case .menu: "Ngahuma"
        case .collection: "Koleksi"
        }
    }

    var symbol: String {
        switch self {
        case .menu: "leaf.fill"
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
        .padding(4)
        .background(Color(red: 0.88, green: 0.86, blue: 0.77).opacity(0.84), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.7)))
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
            .foregroundStyle(selection == tab ? AppTheme.orange : .black)
            .frame(width: 82, height: 52)
            .background(selection == tab ? .white.opacity(0.36) : .clear, in: Capsule())
        }
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }
}
