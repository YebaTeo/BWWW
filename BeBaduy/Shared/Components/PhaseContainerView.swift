import SwiftUI

/// Every phase uses the same three-page sequence. Activity state remains phase-owned.
struct PhaseContainerView<Introduction: View, Activity: View, Description: View>: View {
    let content: PhaseContent
    let session: PhaseSessionState
    let journey: JourneyViewModel
    let start: () -> Void
    let replay: () -> Void
    let demonstrate: () -> Void
    let restore: (ActivityOutcome?) -> Void
    let advance: () -> Void
    var suspend: () -> Void = {}
    @ViewBuilder let introduction: () -> Introduction
    @ViewBuilder let activity: () -> Activity
    @ViewBuilder let description: () -> Description
    @State private var page: Int? = 0
    @State private var restored = false
    @Environment(\.scenePhase) private var scenePhase
    private var unlocked: Bool {
        session.showsDescription || journey.progress.record(for: content.id).explanationAvailable
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    pageContent(0, geometry: geometry) {
                        Spacer(minLength: 40)
                        PhaseHeaderView(content: content)
                        introduction()
                        StoryScrollCue(text: "Geser ke atas untuk mencoba")
                        Spacer(minLength: 20)
                    }
                    pageContent(1, geometry: geometry) {
                        Text(content.title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        activity().disabled(!session.isActive)
                        if !session.feedback.isEmpty {
                            Text(session.feedback).font(.subheadline).accessibilityIdentifier("feedback")
                        }
                        HStack {
                            if session.isActive {
                                Button("Lihat demonstrasi", action: demonstrate)
                                    .accessibilityIdentifier("demonstrate")
                            }
                            if unlocked {
                                Button("Ulangi aktivitas", action: replay).accessibilityIdentifier("replay")
                            }
                        }.frame(minHeight: 44)
                        StoryScrollCue(text: unlocked ? "Geser ke atas untuk melihat hasilnya" : "Selesaikan aktivitas atau lihat demonstrasi")
                    }
                    if unlocked {
                        pageContent(2, geometry: geometry) {
                            Spacer(minLength: 40)
                            description()
                            StoryScrollCue(text: content.id.next == nil ? "Geser ke atas untuk menyelesaikan perjalanan" : "Geser ke atas untuk tahap berikutnya")
                            Spacer(minLength: 20)
                        }
                        pageContent(3, geometry: geometry) {
                            Spacer(minLength: 40)
                            if let next = content.id.next {
                                PhaseHeaderView(content: PhaseCatalog.content(for: next))
                                IntroductionText(content: PhaseCatalog.content(for: next))
                            } else {
                                Text("Padi telah sampai di leuit").font(.largeTitle.bold())
                                Text("Perjalanan belajar selesai. Mari mengenal Baduy lebih dekat.")
                            }
                            Spacer(minLength: 20)
                        }
                    }
                }.scrollTargetLayout()
            }
            .clipped()
            .scrollIndicators(.hidden)
            .scrollPosition(id: $page)
            .scrollTargetBehavior(StorySnapBehavior(enabled: true))
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .navigationTitle(content.title).navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black.opacity(0.6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .background {
            GeometryReader { bounds in
                Image(backgroundState(page ?? 0).assetName).resizable().scaledToFill()
                    .frame(width: bounds.size.width, height: bounds.size.height).clipped()
                    .overlay(Color.black.opacity(0.65))
            }.ignoresSafeArea().accessibilityHidden(true).allowsHitTesting(false)
        }
        .tint(.white).foregroundStyle(.white)
        .onAppear {
            guard !restored else { return }
            restored = true
            restore(journey.progress.record(for: content.id).outcome)
        }
        .onChange(of: page) { _, value in
            if value == 1 && session.stage == .introduction { start() }
            if value != 1 { suspend() }
        }
        .task(id: page) {
            guard page == 3, unlocked else { return }
            // Wait for the page to settle, rather than navigating during the drag.
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard !Task.isCancelled, page == 3 else { return }
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { advance() }
        }
        .onChange(of: session.event) { _, _ in
            if let outcome = session.outcome { journey.record(content.id, outcome: outcome) }
        }
        .onChange(of: scenePhase) { _, value in if value != .active { suspend() } }
        .onDisappear { suspend() }
    }

    private func pageContent<V: View>(_ index: Int, geometry: GeometryProxy,
                                      @ViewBuilder content: () -> V) -> some View {
        OverflowPageContent {
            VStack(alignment: .leading, spacing: 16, content: content)
        }
        .padding(.horizontal, 24).padding(.top, 16)
        .padding(.bottom, max(24, geometry.safeAreaInsets.bottom))
        .frame(width: geometry.size.width, height: geometry.size.height)
        .background {
            GeometryReader { pageGeometry in
                Image(backgroundState(index).assetName).resizable().scaledToFill()
                    .frame(width: pageGeometry.size.width, height: pageGeometry.size.height).clipped()
                    .overlay(LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                    .accessibilityHidden(true)
            }
        }
        .clipped()
        .accessibilityHidden(page != index)
        .id(index)
    }
    private func backgroundState(_ index: Int) -> LandscapeState {
        if index == 3, let next = content.id.next { return PhaseCatalog.content(for: next).before }
        return index >= 2 ? content.after : content.before
    }
}
