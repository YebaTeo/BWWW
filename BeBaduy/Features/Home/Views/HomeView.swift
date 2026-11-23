import SwiftUI

struct HomeView: View {
    let journey: JourneyViewModel
    let motion: MotionService
    @State private var model = HomeViewModel()
    @State private var preparingStage: PhaseID?
    @State private var preparedPreview: PreparedStagePreview?
    @State private var preparingActivity: PhaseID?
    @State private var preparedNarawasModel: NarawasViewModel?
    @State private var preparedNgoredModel: NgoredViewModel?
    @State private var activityPreparationFailed = false
    @State private var preparationFailed = false
    @State private var onboardingReady = false
    @State private var selectedTab: HomeTab = .menu
    @State private var isTabCollapsed = false
    @State private var showsHomeLanding = true
    @State private var landscapeViewportHeight: CGFloat?
    @State private var collectionPath = NavigationPath()
    @State private var selectedCollectionCard: ChapterCard?

    private var isUITesting: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--uitesting")
        #else
        return false
        #endif
    }

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
            if !skipsLaunchPresentationForTests && showsHomeLanding {
                LandingToMenuTransition(journey: journey, playsLaunchTransition: !isUITesting) { height in
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
                            open: openStage,
                            onScroll: { oldOffset, newOffset in
                                updateTabBar(for: .menu, from: oldOffset, to: newOffset)
                            }
                        )
                        .navigationDestination(for: HomeRoute.self) { route in
                            switch route {
                            case .stage(let phase):
                                StagePreviewScreen(stage: GrowthStage.allStages[phase.index], prepared: preparedPreview?.phase == phase ? preparedPreview : nil) {
                                    startActivity(phase)
                                }
                                .disabled(preparingActivity == phase)
                                .overlay {
                                    if preparingActivity == phase {
                                        ZStack {
                                            Color.black.opacity(0.28).ignoresSafeArea()
                                            ReusableLoadingView(message: "Menyiapkan lahan…", style: .card,
                                                                identifier: "stage.activity.loading")
                                        }
                                    }
                                }
                                .task(id: preparingActivity) {
                                    guard preparingActivity == phase else { return }
                                    await prepareActivity(phase)
                                }
                                .onDisappear { if preparingActivity == phase { preparingActivity = nil } }
                                .alert("Lahan belum dapat dimuat. Silakan coba lagi.", isPresented: $activityPreparationFailed) {
                                    Button("Tutup") {}
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
                                PhaseDestinationView(phase: phase, journey: journey, motion: motion,
                                                     preparedNarawasModel: preparedNarawasModel,
                                                     preparedNgoredModel: phase == .ngored ? preparedNgoredModel : nil) {
                                    guard model.path.last == .activity(phase) else { return }
                                    if phase == .ngaleuitkeunPare {
                                        model.path = []
                                    } else {
                                        model.path = [.transition(phase)]
                                    }
                                }
                                .id(phase)
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
                .disabled(preparingStage != nil)
                .overlay {
                    if preparingStage != nil {
                        ZStack {
                            Color.black.opacity(0.28).ignoresSafeArea()
                            ReusableLoadingView(
                                message: "Menyiapkan tahap…",
                                style: .card,
                                identifier: "menu.stage.loading"
                            )
                        }
                    }
                }
                .task(id: preparingStage) {
                    guard let phase = preparingStage else { return }
                    // Let SwiftUI present the menu indicator before building the graph.
                    do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                    preparedPreview?.renderer.stopUpdates()
                    preparedPreview = nil
                    let preview = PreparedStagePreview(stage: GrowthStage.allStages[phase.index])
                    let ready = await preview.prepare()
                    guard !Task.isCancelled, preparingStage == phase else {
                        preview.renderer.stopUpdates()
                        return
                    }
                    preparingStage = nil
                    if ready {
                        preparedPreview = preview
                        model.path = [.stage(phase)]
                    } else {
                        preview.renderer.stopUpdates()
                        preparationFailed = true
                    }
                }
                .alert("Tahap belum dapat dimuat. Silakan pilih kembali.", isPresented: $preparationFailed) {
                    Button("Tutup") {}
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

            }
        }
        .preferredColorScheme(.dark)
    }

    private func openStage(_ phase: PhaseID) {
        guard preparingStage == nil, journey.progress.isUnlocked(phase) else { return }
        if preparedPreview?.phase == phase {
            model.path = [.stage(phase)]
        } else {
            preparingStage = phase
        }
    }

    private func startActivity(_ phase: PhaseID) {
        guard model.path.last == .stage(phase), preparingActivity == nil else { return }
        if phase == .narawas {
            preparingActivity = phase
        } else if phase == .ngored {
            if preparedNgoredModel?.scene.hasPreparedNgoredField == true {
                model.open(phase, journey: journey)
            } else {
                preparingActivity = phase
            }
        } else {
            model.open(phase, journey: journey)
        }
    }

    private func prepareActivity(_ phase: PhaseID) async {
        let ready: Bool
        if phase == .narawas {
            let prepared = NarawasViewModel(motion: motion)
            prepared.start()
            ready = await prepared.scene.prepareField(forNgored: false)
            if ready && !Task.isCancelled { preparedNarawasModel = prepared }
        } else {
            let prepared = NgoredViewModel(motion: motion)
            ready = await prepared.scene.prepareNgoredField()
            if ready && !Task.isCancelled { preparedNgoredModel = prepared }
        }
        guard !Task.isCancelled, preparingActivity == phase, model.path.last == .stage(phase) else { return }
        preparingActivity = nil
        if ready { model.open(phase, journey: journey) }
        else { activityPreparationFailed = true }
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
    let playsLaunchTransition: Bool
    let complete: (CGFloat) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat
    @State private var dragStartProgress: CGFloat?
    @State private var didComplete = false
    @State private var tabSelection: HomeTab = .menu
    @State private var tabCollapsed = false
    @State private var launchMorphActive: Bool
    @State private var morphProgress: CGFloat
    @State private var wordmarkOpacity: Double
    @State private var introReveal: Double

    init(
        journey: JourneyViewModel,
        returning: Bool = false,
        playsLaunchTransition: Bool = false,
        complete: @escaping (CGFloat) -> Void
    ) {
        self.journey = journey
        self.returning = returning
        self.playsLaunchTransition = playsLaunchTransition
        self.complete = complete
        _progress = State(initialValue: returning ? 1 : 0)
        let shouldMorph = playsLaunchTransition && !returning
        _launchMorphActive = State(initialValue: shouldMorph)
        _morphProgress = State(initialValue: shouldMorph ? 0 : 1)
        _wordmarkOpacity = State(initialValue: shouldMorph ? 1 : 0)
        _introReveal = State(initialValue: shouldMorph ? 0 : 1)
    }

    var body: some View {
        GeometryReader { safeGeometry in
            GeometryReader { geometry in
                let height = geometry.size.height
                ZStack {
                    MenuView(
                        journey: journey,
                        showsBackground: false,
                        isActive: false,
                        showsIntroText: false,
                        transitionTopInset: safeGeometry.safeAreaInsets.top,
                        landscapeViewportHeight: height,
                        open: { _ in },
                        onScroll: { _, _ in }
                    )
                    .offset(y: (1 - progress) * height)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    HomeLandingView(transitionProgress: progress, hidesRiceEmblem: launchMorphActive)
                        .offset(y: -progress * height)
                        .contentShape(Rectangle())
                        .highPriorityGesture(landingDrag(height: height))

                    VStack {
                        Spacer()
                        Button {
                            finishLaunchMorphImmediately()
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
                    .opacity((1 - progress) * introReveal)
                    .offset(y: -progress * height + (reduceMotion ? 0 : (1 - introReveal) * 8))

                    LandingIntroText(progress: progress, topSafeAreaInset: safeGeometry.safeAreaInsets.top)
                        .opacity(introReveal)
                        .offset(y: reduceMotion ? 0 : (1 - introReveal) * 8)
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

                    if launchMorphActive {
                        LaunchToHomeMorphOverlay(
                            width: geometry.size.width,
                            height: height,
                            morphProgress: morphProgress,
                            wordmarkOpacity: wordmarkOpacity,
                            reduceMotion: reduceMotion
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }
                .frame(width: geometry.size.width, height: height)
                .clipped()
                .task {
                    if returning {
                        try? await Task.sleep(for: .milliseconds(30))
                        snapToLanding(viewportHeight: height)
                        return
                    }
                    await runLaunchMorph()
                }
            }
            .ignoresSafeArea()
        }
        .background(launchMorphActive ? LaunchSplashStyle.backgroundColor : Color(red: 0.20, green: 0.13, blue: 0.08))
        .preferredColorScheme(.light)
    }

    private func runLaunchMorph() async {
        guard launchMorphActive else { return }
        do { try await Task.sleep(for: .milliseconds(70)) } catch { return }
        guard launchMorphActive else { return }
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.24)) {
                wordmarkOpacity = 0
                morphProgress = 1
                introReveal = 1
            }
            do { try await Task.sleep(for: .milliseconds(260)) } catch { return }
            launchMorphActive = false
            return
        }
        withAnimation(.easeOut(duration: 0.22)) {
            wordmarkOpacity = 0
        }
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.62)) {
            morphProgress = 1
        }
        do { try await Task.sleep(for: .milliseconds(160)) } catch { return }
        guard launchMorphActive else { return }
        withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.38)) {
            introReveal = 1
        }
        do { try await Task.sleep(for: .milliseconds(480)) } catch { return }
        launchMorphActive = false
    }

    private func finishLaunchMorphImmediately() {
        guard launchMorphActive else { return }
        launchMorphActive = false
        morphProgress = 1
        wordmarkOpacity = 0
        introReveal = 1
    }

    private func landingDrag(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !didComplete else { return }
                finishLaunchMorphImmediately()
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

private struct LaunchToHomeMorphOverlay: View, Animatable {
    let width: CGFloat
    let height: CGFloat
    nonisolated var morphProgress: CGFloat
    let wordmarkOpacity: Double
    let reduceMotion: Bool

    nonisolated var animatableData: CGFloat {
        get { morphProgress }
        set { morphProgress = newValue }
    }

    var body: some View {
        let centerX = width / 2
        let centerY = height * LaunchSplashStyle.logoVerticalFraction
        let targetSize = JourneyLandscapeBridgeView.riceEmblemSize(width: width, viewportHeight: height)
        let startScale = targetSize > 0 ? LaunchSplashStyle.logoSize / targetSize : 1
        let currentScale = startScale + (1 - startScale) * morphProgress
        let backdropOpacity = Double(max(0, 1 - morphProgress * 1.18))
        let appIconOpacity = Double(max(0, 1 - morphProgress * 1.35))
        let riceOpacity = reduceMotion
            ? Double(morphProgress) * 0.94
            : Double(min(1, morphProgress / 0.16)) * 0.94

        ZStack(alignment: .top) {
            LaunchSplashStyle.backgroundColor
                .opacity(backdropOpacity)

            Text("BeBaduy")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(LaunchSplashStyle.wordmarkColor)
                .opacity(wordmarkOpacity)
                .frame(maxWidth: .infinity)
                .offset(y: centerY + LaunchSplashStyle.logoSize / 2 + LaunchSplashStyle.wordmarkSpacing + (reduceMotion ? 0 : (1 - wordmarkOpacity) * 4))

            if reduceMotion {
                Image("JourneyLogoRice")
                    .resizable()
                    .scaledToFit()
                    .saturation(0.68)
                    .brightness(0.08)
                    .opacity(riceOpacity)
                    .shadow(color: .white.opacity(0.72 * Double(morphProgress)), radius: 10)
                    .shadow(color: JourneyLandscapeBridgeView.riceGlow.opacity(0.48 * Double(morphProgress)), radius: 28)
                    .frame(width: targetSize, height: targetSize)
                    .position(x: centerX, y: centerY)

                Image("OnboardingLogo")
                    .resizable()
                    .scaledToFit()
                    .opacity(Double(1 - morphProgress))
                    .frame(width: LaunchSplashStyle.logoSize, height: LaunchSplashStyle.logoSize)
                    .position(x: centerX, y: centerY)
            } else {
                ZStack {
                    Image("JourneyLogoRice")
                        .resizable()
                        .scaledToFit()
                        .saturation(0.68)
                        .brightness(0.08)
                        .opacity(riceOpacity)
                        .shadow(color: .white.opacity(0.72 * Double(morphProgress)), radius: 10)
                        .shadow(color: JourneyLandscapeBridgeView.riceGlow.opacity(0.48 * Double(morphProgress)), radius: 28)

                    Image("OnboardingLogo")
                        .resizable()
                        .scaledToFit()
                        .opacity(appIconOpacity)
                }
                .frame(width: targetSize, height: targetSize)
                .scaleEffect(currentScale)
                .position(x: centerX, y: centerY)
            }
        }
        .frame(width: width, height: height)
    }
}

private struct HomeLandingView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let transitionProgress: CGFloat
    var hidesRiceEmblem = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                JourneyLandscapeBridgeView(width: geometry.size.width,
                                           viewportHeight: geometry.size.height,
                                           hidesRiceEmblem: hidesRiceEmblem)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .clipped()

                if !reduceTransparency {
                    JourneyLandscapeBridgeView(width: geometry.size.width,
                                               viewportHeight: geometry.size.height,
                                               hidesRiceEmblem: hidesRiceEmblem)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                        .clipped()
                        .blur(radius: 16, opaque: true)
                        .mask {
                            LinearGradient(stops: [
                                .init(color: .clear, location: 0.56),
                                .init(color: .white.opacity(0.55), location: 0.73),
                                .init(color: .white.opacity(0.55), location: 0.88),
                                .init(color: .clear, location: 1)
                            ], startPoint: .top, endPoint: .bottom)
                        }
                        .opacity(max(0, 1 - transitionProgress * 5))
                        .allowsHitTesting(false)
                }

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.62),
                        .init(color: .black.opacity(0.12), location: 0.78),
                        .init(color: .black.opacity(0.22), location: 1)
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
    @ScaledMetric(relativeTo: .body) private var menuBodySize: CGFloat = 17
    @State private var copyHeight: CGFloat = 170

    var body: some View {
        GeometryReader { geometry in
            let horizontal: CGFloat = 27
            let width = geometry.size.width - 2 * horizontal
            let landingBottom = geometry.size.height - max(geometry.safeAreaInsets.bottom, 20) - 75
            let menuTop = topSafeAreaInset + 26
            let top = (landingBottom - copyHeight) * (1 - progress) + menuTop * progress
            VStack(alignment: .leading, spacing: 14) {
                Text(JourneyIntroCopy.title)
                    .font(.system(size: menuTitleSize,
                                  weight: .bold, design: .rounded))
                    .scaleEffect(1 + (landingTitleSize / menuTitleSize - 1) * (1 - progress), anchor: .leading)
                    .accessibilityAddTraits(.isHeader)
                Text(JourneyIntroCopy.description)
                    .font(.system(size: menuBodySize,
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
    let prepared: PreparedStagePreview?
    let openSelectedChapter: () -> Void
    @State private var sceneReady = false
    @State private var isVisible = false
    private let ivory = Color(red: 0.99, green: 0.97, blue: 0.92)
    private let gold = Color(red: 1, green: 0.62, blue: 0.14)

    var body: some View {
        GeometryReader { viewport in
            ZStack(alignment: .bottom) {
                CinematicAtmosphereView(progress: stage.targetProgress, isActive: isVisible)
                Group {
                    if let prepared {
                        PreparedStageSurface(preview: prepared, active: isVisible)
                    } else {
                        SceneKitCropView(
                            progress: stage.targetProgress,
                            isActive: isVisible,
                            dryingStageOnly: stage.phase == .ngalantai,
                            showsTreeFallEffects: false,
                            onFirstFrame: { sceneReady = true }
                        )
                    }
                }
                .ignoresSafeArea()
                VStack(spacing: 0) {
                    stageCard
                    actions
                }
                .frame(maxWidth: 440)
                .padding(.horizontal, 12)
                .padding(.bottom, viewport.size.height * 0.14)
                .allowsHitTesting(prepared != nil || sceneReady)
                .accessibilityHidden(prepared == nil && !sceneReady)

            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
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
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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
                             showsBurnTint: phase == .narawas,
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
