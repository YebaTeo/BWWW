import SwiftUI

/// Five-stage PoCPadi preview, with the saved learning journey kept separate.
struct WelcomeHomeView: View {
    let journey: JourneyViewModel
    let onOpen: (PhaseID) -> Void
    let onJourney: () -> Void
    let onCompletion: () -> Void
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    private var largeText: Bool { typeSize.isAccessibilitySize }
    @State private var preview = HomePreviewViewModel()
    @State private var confirmsRestart = false
    @State private var initializedPreview = false
    private var progress: CGFloat { preview.progress }
    private var isTransitioning: Bool { preview.isTransitioning }
    private var selectedStage: Int { preview.selectedStage }

    private let ivory = Color(red: 0.99, green: 0.97, blue: 0.92)
    private let gold = Color(red: 0.98, green: 0.84, blue: 0.44)
    private let darkCard = Color(red: 0.12, green: 0.08, blue: 0.05)
    private var stage: GrowthStage { GrowthStage.allStages[selectedStage] }

    var body: some View {
        GeometryReader { viewport in
            ZStack {
                CinematicAtmosphereView(progress: progress, isActive: isActive)
                    .accessibilityHidden(true)
                SceneKitCropView(progress: progress, isActive: isActive)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    header
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(stageSwipe)
                        .accessibilityHidden(true)
                    ScrollView {
                        stageCard
                            .frame(maxWidth: 440)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: viewport.size.height * (largeText ? 0.35 : 0.33))
                    actions
                        .frame(maxWidth: 440)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)
            }
        }
        .foregroundStyle(ivory)
        .tint(gold)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: selectedStage)
        .onChange(of: reduceMotion) { _, enabled in if enabled { preview.stop() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { preview.stop() } }
        .onAppear {
            guard !initializedPreview else { return }
            initializedPreview = true
            if let stage = GrowthStage.allStages.first(where: { $0.phase == journey.progress.currentPhase }) {
                preview.selectStage(stage.id, reduceMotion: true)
            }
        }
        .onDisappear {
            preview.stop()
        }
        .onChange(of: isActive) { _, active in
            if !active {
                preview.stop()
            }
        }
        .alert("Mulai lagi dari awal?", isPresented: $confirmsRestart) {
            Button("Batalkan", role: .cancel) {}
            Button("Mulai Ulang", role: .destructive) {
                journey.restart()
                selectStage(0)
                onOpen(journey.progress.currentPhase)
            }
            .accessibilityIdentifier("home.restart.confirm")
        } message: {
            Text("Semua progres yang sudah kamu capai akan dihapus dari perangkat ini.")
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Text("TAHAPAN")
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(gold)
                Spacer(minLength: 0)
                Text(stage.stepCounterString)
                    .font(.subheadline.monospaced().bold())
                    .foregroundStyle(ivory)
                    .accessibilityLabel("Pratinjau \(stage.id + 1) dari 5")
                Spacer(minLength: 0)
                Menu {
                    Button("Tahapan belajar", action: onJourney)
                    if journey.progress.isUnlocked(stage.phase), stage.phase != journey.progress.currentPhase {
                        Button("Lanjutkan perjalanan") { onOpen(journey.progress.currentPhase) }
                    }
                    if journey.progress.allComplete {
                        Button("Lihat rangkuman", action: onCompletion)
                    }
                    if journey.completedCount > 0 {
                        Button("Mulai lagi dari awal", role: .destructive) {
                            confirmsRestart = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Pilihan perjalanan")
                .accessibilityIdentifier("home.menu")
            }
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ForEach(GrowthStage.allStages) { item in
                    Button { selectStage(item.id) } label: {
                        Circle()
                            .fill(item.id == stage.id ? gold : ivory.opacity(0.45))
                            .frame(width: item.id == stage.id ? 10 : 7, height: item.id == stage.id ? 10 : 7)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Pratinjau \(item.name)")
                    .accessibilityAddTraits(item.id == stage.id ? [.isSelected] : [])
                    .accessibilityIdentifier("home.stage.\(item.id)")
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .shadow(color: .black.opacity(0.72), radius: 8, y: 2)
    }

    private var stageCard: some View {
        VStack(spacing: 8) {
            Text(stage.culturalContext.uppercased())
                .font(.caption.bold())
                .tracking(1.8)
                .foregroundStyle(gold)
            Text(stage.name)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .fontWidth(.condensed)
                .tracking(2)
                .shadow(color: .black.opacity(0.78), radius: 10, y: 3)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home.stage.title")
            Text(stage.subtitle)
                .font(.headline.weight(.medium))
                .foregroundStyle(gold)
                .shadow(color: .black.opacity(0.8), radius: 8, y: 2)
            Text(stage.narrative)
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.9), radius: 7, y: 2)
            if let message = journey.storageMessage {
                Text(message)
                    .font(.footnote)
                    .shadow(color: .black.opacity(0.9), radius: 7, y: 2)
            }
            Text("\(journey.completedCount) dari 5 tahap telah dijelajahi")
                .font(.caption)
                .foregroundStyle(ivory.opacity(0.86))
                .shadow(color: .black.opacity(0.9), radius: 7, y: 2)
                .accessibilityIdentifier("home.progress")
                .padding(.top, 2)
            if !journey.progress.isUnlocked(stage.phase) {
                Text("Selesaikan tahap sebelumnya untuk membuka tahap ini.").font(.footnote)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
    }

    private var actions: some View {
        let unlocked = journey.progress.isUnlocked(stage.phase)
        let completed = journey.progress.record(for: stage.phase).explanationAvailable
        return VStack(spacing: 4) {
            Button {
                onOpen(unlocked ? stage.phase : journey.progress.currentPhase)
            } label: {
                HStack(spacing: 8) {
                    Text(unlocked ? (completed ? "Tinjau \(stage.name)" : "Jelajahi \(stage.name)") : "Lanjutkan perjalanan")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(darkCard)
                .frame(maxWidth: 230, minHeight: 48)
                .background(gold, in: Capsule())
            }
            .accessibilityIdentifier("resume")
            if isTransitioning {
                Button("Akhiri animasi", action: preview.stop)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("home.preview.finish")
            }
            Button("Lihat tahapan", action: onJourney)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 38)
                .shadow(color: .black.opacity(0.85), radius: 7, y: 2)
                .accessibilityIdentifier("home.journey")
            Button {
                selectStage(stage.id == 4 ? 0 : stage.id + 1)
            } label: {
                Label(stage.id == 4 ? "Ulangi pratinjau" : "Pratinjau berikutnya", systemImage: stage.id == 4 ? "arrow.counterclockwise" : "chevron.up.2")
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 36)
                    .shadow(color: .black.opacity(0.85), radius: 7, y: 2)
            }
            .accessibilityIdentifier("home.preview.next")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 440)
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 18)

    }

    private var stageSwipe: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                guard abs(value.translation.height) > 45,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                let direction = value.translation.height < 0 ? 1 : -1
                preview.swipe(direction: direction, reduceMotion: reduceMotion)
            }
    }

    private func selectStage(_ index: Int) {
        preview.selectStage(index, reduceMotion: reduceMotion)
    }

}
