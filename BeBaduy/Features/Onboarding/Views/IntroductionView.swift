import SwiftUI

struct IntroductionView: View {
    let stageProgress: CGFloat
    var onFirstFrame: (() -> Void)? = nil
    let finish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: Story = .welcome
    @State private var incomingPage: Story?
    @State private var outgoingOffset: CGFloat = 0
    @State private var incomingOffset: CGFloat = 0
    @State private var isTransitioning = false
    @State private var transitionTask: Task<Void, Never>?

    private enum Story: Int, CaseIterable, Identifiable {
        case welcome, pikukuh, ngahuma

        var id: Self { self }

        var title: String {
            switch self {
            case .welcome: "Selamat Datang!"
            case .pikukuh: "Pikukuh"
            case .ngahuma: "Mengenal Ngahuma"
            }
        }

        var message: String {
            switch self {
            case .welcome:
                "Kami adalah masyarakat Baduy yang tinggal di Desa Kanekes, Lebak, Banten. Sejak dulu, kami hidup dengan menjaga adat dan tradisi warisan leluhur."
            case .pikukuh:
                "Dalam kehidupan sehari-hari, kami berpegang pada Pikukuh, amanah adat untuk menjaga sesama, alam, dan warisan leluhur."
            case .ngahuma:
                "Salah satu cara kami menjalankan pikukuh adalah melalui Ngahuma, tradisi berladang yang diwariskan turun-temurun."
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    CinematicAtmosphereView(progress: stageProgress, isActive: true)
                    SceneKitCropView(progress: stageProgress, isActive: true,
                                     showsTreeFallEffects: false, onFirstFrame: onFirstFrame)
                }
                .accessibilityHidden(true)
                .allowsHitTesting(false)
                ScrollView(.vertical) {
                    ZStack {
                        storyPage(page, size: geometry.size,
                                  topInset: geometry.safeAreaInsets.top,
                                  bottomInset: geometry.safeAreaInsets.bottom)
                            .offset(y: outgoingOffset)
                        if let incomingPage {
                            storyPage(incomingPage, size: geometry.size,
                                      topInset: geometry.safeAreaInsets.top,
                                      bottomInset: geometry.safeAreaInsets.bottom)
                                .offset(y: incomingOffset)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .scrollDisabled(true)
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("intro.story")
                .gesture(storySwipe(height: geometry.size.height))
                .allowsHitTesting(!isTransitioning)
            }
            .accessibilityAction(named: "Halaman berikutnya") {
                changePage(by: 1, height: geometry.size.height)
            }
            .accessibilityAction(named: "Halaman sebelumnya") {
                changePage(by: -1, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
        .foregroundStyle(AppTheme.cream)
        .background(Color(red: 0.49, green: 0.39, blue: 0.29))
        .sensoryFeedback(.selection, trigger: page)
        .onDisappear { transitionTask?.cancel() }
    }

    private func storyPage(_ story: Story, size: CGSize, topInset: CGFloat, bottomInset: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.clear, .black.opacity(0.66), AppTheme.action.opacity(0.96)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: size.height * 0.55)
            VStack(alignment: .leading, spacing: 14) {
                Text(story.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text(story.message)
                    .font(.system(.title3, design: .rounded, weight: .regular))
                if story == .ngahuma {
                    LessonButton(title: "Mulai Ngahuma", identifier: "intro.continue", action: finish)
                        .padding(.top, 10)
                        .accessibilityHidden(page != .ngahuma)
                } else if story == .welcome {
                    Label("Geser ke atas", systemImage: "chevron.up")
                        .font(.footnote.italic())
                }
            }
            .frame(maxWidth: 490, alignment: .leading)
            .padding(.leading, 28)
            .padding(.trailing, 50)
            .padding(.top, max(topInset, 56))
            .padding(.bottom, max(bottomInset, 34) + 16)

            VStack(spacing: 10) {
                ForEach(Story.allCases) { dot in
                    Circle().fill(.white.opacity(dot == story ? 1 : 0.35))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, max(bottomInset, 34) + 46)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityHidden(true)
        }
        .frame(width: size.width, height: size.height, alignment: .bottom)
        .clipped()
    }

    private func storySwipe(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                guard abs(value.translation.height) > 45,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                changePage(by: value.translation.height < 0 ? 1 : -1, height: height)
            }
    }

    private func changePage(by direction: Int, height: CGFloat) {
        guard !isTransitioning,
              let next = Story(rawValue: page.rawValue + direction) else { return }
        if reduceMotion {
            page = next
            return
        }
        isTransitioning = true
        incomingPage = next
        incomingOffset = CGFloat(direction) * height
        transitionTask = Task { @MainActor in
            // Give the entering page a frame offscreen before sliding both layers.
            do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
            withAnimation(.easeInOut(duration: 0.48)) {
                outgoingOffset = -CGFloat(direction) * height
                incomingOffset = 0
            }
            do { try await Task.sleep(for: .milliseconds(480)) } catch { return }
            page = next
            incomingPage = nil
            outgoingOffset = 0
            isTransitioning = false
            transitionTask = nil
        }
    }
}
