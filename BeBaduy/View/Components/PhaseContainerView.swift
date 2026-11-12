import SwiftUI

/// Sketch's Explore → activity → result → explanation sequence, shared by all phases.
struct PhaseContainerView<Activity: View, Surface: View, Description: View>: View {
    let content: PhaseContent
    let session: PhaseSessionState
    let journey: JourneyViewModel
    let start: () -> Void
    let replay: () -> Void
    let demonstrate: () -> Void
    let restore: (ActivityOutcome?) -> Void
    let advance: () -> Void
    var suspend: () -> Void = {}
    var activityVisibility: (Bool) -> Void = { _ in }
    var helpVisibility: ((Bool) -> Void)? = nil
    var showsActiveControls = false
    var usesContextCards = true
    var showsInitialActivityCard = true
    var mipitHarvested: Set<Int> = []
    @ViewBuilder let surface: () -> Surface
    @ViewBuilder let activity: () -> Activity
    @ViewBuilder let description: () -> Description
    @State private var flow = LessonFlowViewModel()
    @State private var restored = false
    @State private var isToolRevealed = false
    @State private var card = ActivityCardState()
    @AccessibilityFocusState private var cardHeadingFocused: Bool
    private var immersive: Bool { flow.screen == .activity || flow.screen == .result }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    private var equipment: (title: String, description: String)? {
        switch content.id {
        case .ngaseuk: ("Aseuk", "Gunakan aseuk untuk membuat lubang tempat menanam benih padi.")
        case .ngored: ("Kored", "Gunakan kored untuk membersihkan gulma dan menggemburkan tanah.")
        case .mipit: ("Etem / ani-ani", "Gunakan etem untuk memotong malai padi bersama tangkainya.")
        default: nil
        }
    }
    private var isResult: Bool { flow.screen == .result || flow.screen == .explanation }
    private var targetProgress: CGFloat {
        content.id.progress(isResult: isResult)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CinematicAtmosphereView(progress: targetProgress, isActive: scenePhase == .active)
                    .accessibilityHidden(true)
                SceneKitCropView(progress: targetProgress, isActive: scenePhase == .active,
                                 showsRice: content.id != .mipit || flow.screen != .activity,
                                 mipitHarvested: mipitHarvested)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                    .opacity((content.id == .ngaseuk && (flow.screen == .activity || flow.screen == .result))
                             || (content.id == .mipit && flow.screen == .result) ? 0 : 1)

                // Clean and bright matching Home screen, with only a subtle top vignette for header readability
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.22), location: 0),
                    .init(color: .clear, location: 0.14)
                ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .allowsHitTesting(false)

                if immersive {
                    surface().environment(card)
                        .disabled(!session.isActive || blocksScene)
                        .allowsHitTesting(!blocksScene)
                        .accessibilityHidden(blocksScene)
                        .ignoresSafeArea()
                }
                VStack(spacing: 0) {
                    if flow.screen != .activity { header }
                    switch flow.screen {
                    case .introduction:
                        Color.clear
                    case .equipment:
                        if let equipment {
                            ScrollView {
                                VStack(spacing: 22) {
                                    Text(isToolRevealed ? "Ketuk kartu untuk menutupnya." : "Buka kartu untuk mendapat alat baru!")
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(AppTheme.cream)
                                    ToolRevealCard(title: equipment.title, description: equipment.description,
                                                   isRevealed: $isToolRevealed) {
                                        equipmentArtwork
                                    }
                                    if isToolRevealed {
                                        LessonButton(title: "Mulai aktivitas", identifier: "lesson.begin", action: begin)
                                            .frame(maxWidth: 330)
                                    }
                                }
                                .padding(.horizontal, 32)
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    case .activity:
                        if usesContextCards {
                            activityOverlay
                        } else {
                            activity().disabled(!session.isActive)
                        }
                    case .result:
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("\(content.title) selesai!").font(.system(.title2, design: .rounded).bold())
                                    .foregroundStyle(AppTheme.heading)
                                if session.outcome == .observed {
                                    Text("Demonstrasi selesai.")
                                } else if content.id != .mipit {
                                    Text(content.result)
                                }
                                LessonButton(title: "Lihat penjelasan", identifier: "lesson.result.continue") { flow.explain() }
                                Button(content.id == .mipit ? "Ulang" : "Ulangi") { restartActivity() }.frame(minHeight: 44).accessibilityIdentifier("replay")
                            }.padding(24).activityCardStyle()
                                .padding(24)
                        }
                    case .explanation:
                        ScrollView {
                            HumaGlassCard {
                                description()
                            }
                            .frame(width: min(330, max(1, geometry.size.width - 48)),
                                   height: min(330, max(1, geometry.size.width - 48)) * 480 / 330)
                            .accessibilityIdentifier("lesson.explanation.card")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .frame(minHeight: max(0, geometry.size.height - 180))
                        }.accessibilityIdentifier("lesson.explanation.page")
                        LessonButton(title: content.id.next == nil ? "Selesaikan perjalanan" : (content.id == .mipit ? "Lanjut ke tahap berikutnya" : "Lanjut ke tahapan berikutnya"), identifier: "continue", action: advance)
                            .padding(.horizontal, 24).padding(.vertical, 16)
                    }
                }
            }
        }
        .foregroundStyle(.white).tint(.white)
        .preferredColorScheme(.dark).environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !restored else { return }
            restored = true
            let record = journey.progress.record(for: content.id)
            restore(record.outcome)
            flow.restore(completed: record.explanationAvailable)
            if record.explanationAvailable {
                flow.explain()
            } else {
                explore()
            }
        }
        .onChange(of: session.event) { _, _ in
            if let outcome = session.outcome {
                journey.record(content.id, outcome: outcome)
                flow.completed()
            }
        }
        .onChange(of: flow.screen) { _, value in
            if value == .activity && usesContextCards {
                helpVisibility?(false)
                if showsInitialActivityCard { card.showInstruction() }
                else { card.dismiss() }
            }
            activityVisibility(value == .activity && scenePhase == .active)
            if value != .activity { suspend(); ActivityAudio.shared.stop() }
        }
        .onChange(of: scenePhase) { _, value in
            activityVisibility(value == .active && flow.screen == .activity && (card.mode != .help || helpVisibility != nil))
            if value != .active { suspend(); ActivityAudio.shared.stop() }
        }
        .onChange(of: card.mode) { old, new in
            guard flow.screen == .activity else { return }
            if let helpVisibility {
                helpVisibility(new != .hidden)
            } else if old == .help && new != .help {
                setHelpVisible(false)
            }
        }
        .onDisappear { activityVisibility(false); suspend(); ActivityAudio.shared.stop() }
    }

    private func setHelpVisible(_ visible: Bool) {
        if let helpVisibility { helpVisibility(visible) }
        else { activityVisibility(!visible && scenePhase == .active) }
    }

    private var blocksScene: Bool {
        usesContextCards && flow.screen == .activity && card.mode != .hidden
    }

    private var activityOverlay: some View {
        VStack(spacing: 8) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }.accessibilityLabel("Kembali ke beranda").accessibilityIdentifier("lesson.back")
                Spacer()
                if flow.canSkip {
                    Button("Lewati") { flow.explain() }.frame(minHeight: 44)
                        .accessibilityIdentifier("lesson.skip")
                }
                if card.mode == .hidden {
                    Button {
                        setHelpVisible(true)
                        card.showHelp()
                    } label: {
                        Image(systemName: "questionmark.circle").frame(width: 44, height: 44)
                    }.accessibilityLabel("Buka petunjuk").accessibilityIdentifier("activity.help")
                }
            }.padding(.horizontal, 16)
            Spacer(minLength: 0)
            if card.mode != .hidden {
                ActivityCardPanel { cardContents }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .id(card.revision)
            } else if showsActiveControls {
                activity()
                    .environment(card)
                    .frame(maxWidth: 260)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    private var cardContents: some View {
        VStack(spacing: 8) {
            Text(card.mode == .help ? "Petunjuk" : content.title)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(AppTheme.heading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($cardHeadingFocused)
                .onAppear { cardHeadingFocused = true }
            activity().disabled(!session.isActive)
            if card.mode == .help {
                LessonButton(title: "Kembali ke aktivitas", identifier: "activity.card.close") {
                    card.dismiss()
                }
            }
            Button("Lihat demonstrasi") {
                card.dismiss()
                setHelpVisible(false)
                demonstrate()
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.cream)
            .frame(minHeight: 44)
            .accessibilityIdentifier("demonstrate")
            if card.mode == .help {
                Button {
                    ActivityAudio.shared.enabled.toggle()
                } label: {
                    Label(ActivityAudio.shared.enabled ? "Suara aktif" : "Suara nonaktif",
                          systemImage: ActivityAudio.shared.enabled ? "speaker.wave.2" : "speaker.slash")
                        .frame(minHeight: 44)
                }.accessibilityIdentifier("activity.sound")
            }
        }
        .environment(card)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }.accessibilityLabel("Kembali ke beranda").accessibilityIdentifier("lesson.back")
            Spacer()
            Text("\(content.id.index + 1) / \(PhaseID.allCases.count)").font(.caption.monospacedDigit())
            Spacer()
            if flow.screen == .explanation {
                Button(content.id == .mipit ? "Ulang" : "Ulangi") { restartActivity() }.frame(minWidth: 60, minHeight: 44)
                    .background(.ultraThinMaterial, in: Capsule()).accessibilityIdentifier("replay")
            } else if flow.canSkip && (flow.screen == .activity || flow.screen == .equipment) {
                Button("Lewati") { flow.explain() }.frame(minWidth: 60, minHeight: 44)
                    .accessibilityIdentifier("lesson.skip")
            } else { Color.clear.frame(width: 60, height: 44) }
        }.padding(.horizontal, 20).padding(.vertical, 8)
    }
    @ViewBuilder private var equipmentArtwork: some View {
        switch content.id {
        case .ngaseuk:
            AseukTool(interactive: true, autoRotate: true).frame(width: 68)
        case .ngored:
            KoredTool().frame(width: 150, height: 120)
        case .mipit:
            Image("mipit_etem").resizable().scaledToFit().frame(maxWidth: 160, maxHeight: 140)
        default:
            EmptyView()
        }
    }

    private func explore() {
        guard flow.screen == .introduction else { return }
        flow.explore(hasEquipment: equipment != nil)
        if equipment == nil { start() }
    }
    private func begin() { start(); flow.beginActivity() }
    private func restartActivity() { replay(); flow.replay() }
}
