import SwiftUI

struct IntroductionView: View {
    let finish: () -> Void

    @State private var page: Story? = .welcome
    @State private var showsSplash = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

        var image: String {
            switch self {
            case .welcome: "OnboardingVillage"
            case .pikukuh: "OnboardingPikukuh"
            case .ngahuma: "OnboardingNgahuma"
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
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Story.allCases) { story in
                        storyPage(story, size: geometry.size,
                                  topInset: geometry.safeAreaInsets.top,
                                  bottomInset: geometry.safeAreaInsets.bottom)
                            .id(story)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("intro.story")
            .accessibilityHidden(showsSplash)
            .allowsHitTesting(!showsSplash)
            .overlay {
                if showsSplash { splash(size: geometry.size) }
            }
        }
        .ignoresSafeArea()
        .foregroundStyle(AppTheme.cream)
        .background(.black)
        .task {
            do { try await Task.sleep(for: .milliseconds(850)) } catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showsSplash = false }
        }
    }

    private func storyPage(_ story: Story, size: CGSize, topInset: CGFloat, bottomInset: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            backdrop(story.image, size: size)
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, .black.opacity(0.66), AppTheme.action.opacity(0.96)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: size.height * 0.55)
                }
            VStack(alignment: .leading, spacing: 14) {
                Text(story.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text(story.message).font(.body)
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

    private func splash(size: CGSize) -> some View {
        ZStack {
            backdrop("OnboardingVillage", size: size)
                .blur(radius: 22)
                .overlay(.black.opacity(0.28))
            VStack(spacing: 20) {
                Image("OnboardingLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 108, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .accessibilityHidden(true)
                Text("BeBaduy").font(.system(.largeTitle, design: .rounded, weight: .bold))
            }
        }
        .clipped()
    }

    private func backdrop(_ image: String, size: CGSize) -> some View {
        Image(image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .accessibilityHidden(true)
    }
}
