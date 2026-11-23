import SwiftUI

struct NarawasView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model: NarawasViewModel
    private let wasPrepared: Bool
    private enum Message { case cleared, burnIntro, ready, explanation }
    @State private var message: Message?
    @State private var initialized = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    private let orange = Color(red: 1, green: 0.65, blue: 0.25)

    init(journey: JourneyViewModel, motion: any MotionProviding, preparedModel: NarawasViewModel? = nil, advance: @escaping () -> Void) {
        self.journey = journey
        self.advance = advance
        wasPrepared = preparedModel != nil
        _model = State(initialValue: preparedModel ?? NarawasViewModel(motion: motion))
    }

    var body: some View {
        let isLoading = model.scene.loadingAssets
        ZStack {
            NarawasSurface(scene: model.scene)
                .ignoresSafeArea()
                .allowsHitTesting(message == nil && model.session.isActive)
                .accessibilityHidden(message != nil || !model.session.isActive)
                .accessibilityIdentifier("narawas.field")
            if model.swingCount > 0, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: model.struckTree == nil || scenePhase != .active)) { _ in
                    let point = model.struckTree.flatMap { model.scene.projectedTreeChopPoint(at: $0) }
                    let visible = point != nil && scenePhase == .active
                    Golok3DView(isVisible: visible, swingCount: model.swingCount)
                        .frame(width: 300, height: 300)
                        .position(x: point?.x ?? 0, y: (point?.y ?? 0) - 24)
                        .opacity(visible ? 1 : 0)
                }
                .allowsHitTesting(false)
            }
            if model.scene.assetError != nil && isLoading == false {
                Color(red: 0.14, green: 0.09, blue: 0.06)
                    .allowsHitTesting(false)
            }
            if let message {
                messageOverlay(message)
            } else if isLoading {
                ReusableLoadingView(
                    message: "Menyiapkan lahan…",
                    style: .fullscreen,
                    identifier: "narawas.loading"
                )
            } else {
                fieldOverlay
                    .padding(.top, 44)
            }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }.accessibilityLabel("Kembali ke beranda").accessibilityIdentifier("lesson.back")
                    Spacer()
                    if message == nil && initialized && !model.scene.loadingAssets && model.scene.assetError == nil {
                        Button(action: model.recenterLook) {
                            Label("Pusatkan", systemImage: "scope")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(Color.brown.opacity(0.85), in: Capsule())
                        }
                        .accessibilityLabel("Pusatkan pandangan")
                        .accessibilityIdentifier("narawas.recenter")
                    }
                }
                Spacer()
            }.padding(.horizontal, 20)
        }
        .foregroundStyle(.white).tint(orange)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard !initialized else { return }
            initialized = true
            if !wasPrepared { model.start() }
            model.setVisible(true)
            model.configureLookMotion(reduceMotion: reduceMotion)
            model.scene.muted = !ActivityAudio.shared.enabled
            if !wasPrepared { await model.scene.prepareAssets() }
            if message == .explanation { model.scene.showBurnedField() }
        }
        .onChange(of: model.stage) { _, stage in
            if stage == .prepared { message = .cleared }
            if stage == .complete {
                if let outcome = model.session.outcome {
                    journey.record(.narawas, outcome: outcome)
                    showExplanation()
                }
            }
        }
        .onChange(of: message) { _, value in model.setHelpVisible(value != nil) }
        .onChange(of: reduceMotion) { _, value in model.configureLookMotion(reduceMotion: value) }
        .onChange(of: scenePhase) { _, value in model.setVisible(value == .active && message != .explanation) }
        .task(id: model.swingCount) {
            guard model.struckTree != nil else { return }
            do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
            model.clearStruckTree()
        }
        .onDisappear { model.setVisible(false); ActivityAudio.shared.stop() }
    }

    @ViewBuilder private func messageOverlay(_ current: Message) -> some View {
        if current == .explanation {
            GeometryReader { geometry in
                ZStack {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    VStack(spacing: 0) {
                        ScrollView {
                            HumaGlassCard {
                                ReflectionText(content: PhaseContent.content(for: .narawas))
                            }
                            .frame(width: min(330, max(1, geometry.size.width - 48)),
                                   height: min(330, max(1, geometry.size.width - 48)) * 480 / 330)
                            .environment(\.colorScheme, .dark)
                            .accessibilityIdentifier("lesson.explanation.card")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .frame(minHeight: max(0, geometry.size.height - 140))
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .accessibilityIdentifier("lesson.explanation.page")
                        LessonButton(title: "Ayo lanjut!", identifier: "continue", action: advance)
                            .padding(.horizontal, 24).padding(.vertical, 16)
                    }
                    .padding(.top, 44)
                }
            }
        } else {
            ActivityCardLayout(placement: .middle) {
                ActivityCardPanel {
                    switch current {
                    case .cleared:
                        ActivityCardHeading("Mantap!")
                        Text("Sekarang sinar matahari bisa memberi energi ke huma (ladang) yang baru dibuka.")
                    case .burnIntro:
                        Text("Setelah pohon ditebang, masih ada rumput dan daun kering yang tersisa. Saatnya kita Ngahuru (membakar sisa rumput dan daun kering)!")
                    case .ready:
                        ActivityCardHeading("Lahan sudah siap!")
                        Text("Kini, huma lebih siap untuk memasuki tahap penanaman!")
                    case .explanation:
                        EmptyView()
                    }
                }
                ActivityAcknowledgement(title: "Lanjut", identifier: "narawas.message.continue") {
                    guard message == current else { return }
                    switch current {
                    case .cleared: message = .burnIntro
                    case .burnIntro: message = nil
                    case .ready: showExplanation()
                    case .explanation: break
                    }
                }
                .id(current)
            }
            .padding(.top, 44)
        }
    }

    @ViewBuilder private var fieldOverlay: some View {
        if let error = model.scene.assetError {
            ActivityCardLayout(placement: .bottom) {
                ActivityCardPanel { Text(error) }
                Button("Coba lagi") { Task { await model.scene.prepareAssets() } }
                    .frame(minHeight: 44)
            }
        } else if model.stage == .complete {
            ActivityCardLayout(placement: .middle) {
                ActivityCardPanel {
                    ActivityCardHeading("Lahan sudah siap!")
                    Text("Huma siap memasuki tahap penanaman.")
                    motionHint
                }
                ActivityAcknowledgement(title: "Lihat hasil", identifier: "narawas.activity.result",
                                        action: showExplanation)
            }
        } else {
            let allLit = model.ignited.count >= NarawasViewModel.treeCount
            ActivityCardLayout(placement: .bottom) {
                if model.stage == .clearing {
                    Text("Berhasil ditebang: \(model.collected.count)/\(NarawasViewModel.treeCount)")
                        .activityCounterStyle()
                        .accessibilityIdentifier("narawas.progress")
                } else {
                    Text("Titik api dinyalakan: \(model.ignited.count)/\(NarawasViewModel.treeCount)")
                        .activityCounterStyle()
                        .accessibilityIdentifier("narawas.fire.progress")
                }
                ActivityCardPanel(passesTouchesThrough: true) {
                    Text(fieldInstruction(allLit: allLit))
                        .accessibilityIdentifier("narawas.sceneReady")
                    if model.stage == .burning {
                        ProgressView(value: model.scene.progress)
                            .tint(orange)
                            .accessibilityLabel("Progres pembakaran")
                    }
                    motionHint
                }
                if model.stage == .clearing || model.stage == .prepared || model.stage == .burning {
                    if !model.motionActive || voiceOverEnabled {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(0..<NarawasViewModel.treeCount, id: \.self) { index in
                                    let available = model.stage == .clearing
                                        ? !model.collected.contains(index) : !model.ignited.contains(index)
                                    Button(model.stage == .clearing ? "Tebang pohon \(index + 1)" : "Nyalakan petak \(index + 1)") {
                                        if model.stage == .clearing { model.collect(index) }
                                        else { model.burn(startingAt: index) }
                                    }
                                    .disabled(!available)
                                    .font(.caption.weight(.semibold))
                                    .padding(9)
                                    .background(.brown.opacity(0.85), in: Capsule())
                                }
                            }
                        }
                    }
                }
                if allLit {
                    ActivityAcknowledgement(title: "Tampilkan kondisi setelah api reda", identifier: "narawas.finishBurn",
                                            action: model.finishBurn)
                }
            }
        }
    }

    private func fieldInstruction(allLit: Bool) -> String {
        if model.stage == .clearing {
            return "Arahkan ponselmu ke kiri atau kanan, lalu usap pohon untuk menebangnya!"
        }
        if allLit {
            return "Arahkan ponselmu ke kiri atau kanan agar kita bisa memantau api hingga mereda."
        }
        return "Arahkan ponsel ke sekeliling dan tap setiap pangkal pohon untuk menyalakan api."
    }

    private func showExplanation() {
        message = .explanation
        model.setVisible(false)
    }

    @ViewBuilder private var motionHint: some View {
        if !model.motionMessage.isEmpty {
            Text(model.motionMessage).font(.caption)
        }
    }

}
