import SwiftUI

struct WelcomeHomeView: View {
    let journey: JourneyViewModel
    let onResume: () -> Void
    let onJourney: () -> Void
    let onCompletion: () -> Void
    @State private var confirmsRestart = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var hasProgress: Bool { journey.completedCount > 0 }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LessonBackdrop(asset: PhaseCatalog.content(for: journey.progress.currentPhase).before.assetName)
                ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Text("BeBaduy").font(.headline)
                        Spacer()
                        Menu {
                            Button("Tahapan belajar", action: onJourney)
                            if journey.progress.allComplete { Button("Lihat rangkuman", action: onCompletion) }
                            if hasProgress { Button("Mulai lagi dari awal", role: .destructive) { confirmsRestart = true } }
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }.accessibilityLabel("Pilihan perjalanan").accessibilityIdentifier("home.menu")
                    }
                    if hasProgress {
                        Button { confirmsRestart = true } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "chevron.up")
                                Text("Geser ke bawah untuk mulai dari awal").font(.footnote)
                            }.frame(minHeight: 44)
                        }.accessibilityIdentifier("home.restart")
                    }
                    Spacer(minLength: 32)
                    VStack(spacing: 20) {
                        Text("Wilujeng sumping!").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                        Text(hasProgress
                             ? "Hayu, lanjutkan perjalanan dari huma sampai ke leuit."
                             : "Dari satu benih hingga padi tersimpan di leuit, ada pengetahuan yang diwariskan. Hayu, kenali cara berladang masyarakat Baduy.")
                            .font(.title3).lineSpacing(4)
                        Text("\(journey.completedCount) dari 5 tahap telah dijelajahi")
                            .font(.footnote).accessibilityIdentifier("home.progress")
                    }.multilineTextAlignment(.center)
                    Spacer(minLength: 32)
                    LessonButton(title: hasProgress ? "Lanjutkan perjalanan" : "Mulai menjelajah", identifier: "resume", action: onResume)
                    Button("Lihat tahapan", action: onJourney).frame(minHeight: 44)
                        .accessibilityIdentifier("home.journey")
                    Text(hasProgress ? "Geser ke atas untuk lanjut ke modul terakhir" : "Geser ke atas untuk mulai menjelajah")
                        .font(.footnote).multilineTextAlignment(.center)
                    Image(systemName: "chevron.down").accessibilityHidden(true)
                }.padding(24).frame(maxWidth: 560).frame(minHeight: geometry.size.height).frame(maxWidth: .infinity)
                }
            }
            .simultaneousGesture(DragGesture(minimumDistance: 60).onEnded { value in
                guard !typeSize.isAccessibilitySize, abs(value.translation.height) > abs(value.translation.width) else { return }
                if value.translation.height < -80 { onResume() }
                else if value.translation.height > 80 && hasProgress { confirmsRestart = true }
            })
        }
        .foregroundStyle(.white).tint(.white).preferredColorScheme(.dark)
        .alert("Mulai lagi dari awal?", isPresented: $confirmsRestart) {
            Button("Batalkan", role: .cancel) {}
            Button("Mulai Ulang", role: .destructive) { journey.restart(); onResume() }
                .accessibilityIdentifier("home.restart.confirm")
        } message: { Text("Semua progres yang sudah kamu capai akan dihapus dari perangkat ini.") }
    }
}
