import SwiftUI

struct HomeView: View {
    let journey: JourneyViewModel
    let motion: MotionService
    @State private var model = HomeViewModel()
    @State private var onboardingReady = false
    @State private var selectedTab: HomeTab = .menu
    @State private var isTabCollapsed = false

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
                            open: { model.open($0, journey: journey) },
                            onScroll: { oldOffset, newOffset in
                                updateTabBar(for: .menu, from: oldOffset, to: newOffset)
                            }
                        )
                        .navigationDestination(for: PhaseID.self) { phase in
                            PhaseDestinationView(phase: phase, journey: journey, motion: motion) {
                                if journey.continueFrom(phase) == nil,
                                   phase == .ngaleuitkeunPare, journey.progress.allComplete {
                                    journey.finishJourney()
                                    model.showsCompletion = true
                                }
                                model.path = []
                            }
                            .id(phase)
                            .toolbar(.hidden, for: .tabBar)
                        }
                    }
                    .tabItem { Label("Menu", systemImage: "square.grid.2x2.fill") }
                    .tag(HomeTab.menu)
                    .toolbar(.hidden, for: .tabBar)
                    NavigationStack {
                        CardCollectionView(journey: journey) { oldOffset, newOffset in
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
                .fullScreenCover(isPresented: $model.showsCompletion) {
                    CompletionView(journey: journey) { model.showsCompletion = false }
                }
            }
        }
        .preferredColorScheme(.dark)
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
