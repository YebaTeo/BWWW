import SwiftUI

/// Five-stage PoCPadi preview, with the saved learning journey kept separate.
struct WelcomeHomeView: View {
    let journey: JourneyViewModel
    let onResume: () -> Void
    let onJourney: () -> Void
    let onCompletion: () -> Void
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var selectedStage = 0
    @State private var confirmsRestart = false
    @State private var transitionTask: Task<Void, Never>?

    private let ivory = Color(red: 0.99, green: 0.97, blue: 0.92)
    private let gold = Color(red: 0.98, green: 0.84, blue: 0.44)
    private let darkCard = Color(red: 0.12, green: 0.08, blue: 0.05)
    private var stage: GrowthStage { GrowthStage.currentStage(for: progress) }

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
                    stageCard
                        .frame(maxWidth: 440)
                        .frame(maxHeight: viewport.size.height * 0.58)
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
        .onDisappear { transitionTask?.cancel() }
        .onChange(of: isActive) { _, active in
            if !active { transitionTask?.cancel() }
        }
        .alert("Mulai lagi dari awal?", isPresented: $confirmsRestart) {
            Button("Batalkan", role: .cancel) {}
            Button("Mulai Ulang", role: .destructive) {
                journey.restart()
                selectStage(0)
                onResume()
            }
            .accessibilityIdentifier("home.restart.confirm")
        } message: {
            Text("Semua progres yang sudah kamu capai akan dihapus dari perangkat ini.")
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text("BeBaduy")
                    .font(.headline.weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(gold)
                Text("•")
                    .foregroundStyle(ivory.opacity(0.5))
                Text(stage.stepCounterString)
                    .font(.subheadline.monospaced().bold())
                    .foregroundStyle(ivory)
                    .accessibilityLabel("Pratinjau \(stage.id + 1) dari 5")
                Spacer(minLength: 0)
                Menu {
                    Button("Tahapan belajar", action: onJourney)
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
        .padding(.horizontal, 12)
        .background(darkCard.opacity(0.78), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(gold.opacity(0.25)))
    }

    private var stageCard: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(ivory.opacity(0.4))
                .frame(width: 38, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .accessibilityHidden(true)
            ScrollView {
                VStack(spacing: 10) {
                    Text(stage.culturalContext.uppercased())
                        .font(.caption.bold())
                        .tracking(1.4)
                        .foregroundStyle(gold)
                    Text(stage.name)
                        .font(.largeTitle.weight(.black))
                        .fontWidth(.condensed)
                        .tracking(2)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("home.stage.title")
                    Text(stage.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(gold)
                    Text(stage.narrative)
                        .font(.subheadline)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if let message = journey.storageMessage {
                        Text(message).font(.footnote)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 2) {
                Text("\(journey.completedCount) dari 5 tahap telah dijelajahi")
                    .font(.caption)
                    .foregroundStyle(ivory.opacity(0.8))
                    .accessibilityIdentifier("home.progress")
                    .padding(.bottom, 6)
                Button(action: onResume) {
                    HStack(spacing: 8) {
                        Text(journey.completedCount > 0 ? "Lanjutkan perjalanan" : "Mulai menjelajah")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(darkCard)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(gold, in: Capsule())
                }
                .accessibilityIdentifier("resume")
                Button("Lihat tahapan", action: onJourney)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("home.journey")
                Button {
                    selectStage(stage.id == 4 ? 0 : stage.id + 1)
                } label: {
                    Label(stage.id == 4 ? "Ulangi pratinjau" : "Pratinjau berikutnya", systemImage: stage.id == 4 ? "arrow.counterclockwise" : "chevron.up.2")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("home.preview.next")
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(darkCard.opacity(0.92), in: RoundedRectangle(cornerRadius: 28))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(gold.opacity(0.35)))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
    }

    private var stageSwipe: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                guard abs(value.translation.height) > 45,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                selectStage(min(4, max(0, stage.id + (value.translation.height < 0 ? 1 : -1))))
            }
    }

    private func selectStage(_ index: Int) {
        guard GrowthStage.allStages.indices.contains(index) else { return }
        let previousStage = stage.id
        transitionTask?.cancel()
        selectedStage = index
        if reduceMotion {
            progress = GrowthStage.allStages[index].targetProgress
        } else {
            // Give the Ngored → Dibuat day/night cycles enough time to
            // read clearly while the rice grows through the preview.
            let isHarvestTimeLapse = (previousStage == 2 && index == 3) || (previousStage == 3 && index == 2)
            let isForestClearing = (previousStage == 0 && index == 1) || (previousStage == 1 && index == 0)
            let start = progress
            let destination = GrowthStage.allStages[index].targetProgress
            let duration: Double = isHarvestTimeLapse ? 30 : (isForestClearing ? 8 : 0.25)
            // Custom scene inputs need actual intermediate state values;
            // withAnimation alone only interpolates animatable view properties.
            transitionTask = Task { @MainActor in
                let clock = ContinuousClock()
                let began = clock.now
                while !Task.isCancelled {
                    let elapsed = began.duration(to: clock.now).components
                    let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                    let fraction = min(1, seconds / duration)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        progress = start + (destination - start) * CGFloat(fraction)
                    }
                    if fraction >= 1 { break }
                    do { try await Task.sleep(for: .milliseconds(33)) }
                    catch { return }
                }
            }
        }
    }
}
