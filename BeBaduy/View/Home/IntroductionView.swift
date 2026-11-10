import SwiftUI
struct IntroductionView: View {
    let finish: () -> Void
    @State private var page = 0
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LessonBackdrop(asset: "ngahuru_before")
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 60)
                        if page == 0 {
                            Image(systemName: "leaf").font(.system(size: 54)).accessibilityHidden(true)
                            Text("BeBaduy").font(.largeTitle.bold())
                            Text("Mengenal kehidupan masyarakat Baduy melalui perjalanan padi, dari huma hingga leuit.").font(.title3)
                        } else {
                            Text("Wilujeng sumping!").font(.largeTitle.bold())
                            Text("Hayu, mengenal cara berladang masyarakat Baduy. Pengetahuan tentang alam dan pikukuh, pedoman adat, menyertai kehidupan sehari-hari.").font(.title3)
                            Text("Jelajahi enam bab. Coba aktivitasnya atau lihat demonstrasi untuk melanjutkan.")
                        }
                        Spacer(minLength: 60)
                        LessonButton(title: page == 0 ? "Lanjut" : "Mulai menjelajah", identifier: "intro.continue", action: next)
                        Text("Geser ke atas untuk melanjutkan").font(.footnote)
                    }.multilineTextAlignment(.center).padding(24).frame(maxWidth: 560)
                        .frame(minHeight: geometry.size.height).frame(maxWidth: .infinity)
                }
            }.simultaneousGesture(DragGesture(minimumDistance: 60).onEnded { value in
                guard !typeSize.isAccessibilitySize, value.translation.height < -80,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                next()
            })
        }.foregroundStyle(.white).tint(.white).preferredColorScheme(.dark)
    }
    private func next() { if page == 0 { page = 1 } else { finish() } }
}
