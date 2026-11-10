import SwiftUI

struct NukuhView: View {
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model: NukuhViewModel
    private enum Message { case cleared, burnIntro, ready, explanation }
    @State private var message: Message?
    @State private var initialized = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let orange = Color(red: 1, green: 0.65, blue: 0.25)

    init(journey: JourneyViewModel, motion: any MotionProviding, advance: @escaping () -> Void) {
        self.journey = journey
        self.advance = advance
        _model = State(initialValue: NukuhViewModel(motion: motion))
    }

    var body: some View {
        ZStack {
            NukuhSurface(scene: model.scene)
                .ignoresSafeArea()
                .allowsHitTesting(message == nil && model.session.isActive)
                .accessibilityIdentifier("nukuh.field")
            if let message {
                messageOverlay(message)
            } else {
                VStack(spacing: 16) {
                    if model.stage == .burning {
                        ProgressView(value: model.scene.progress)
                            .tint(orange).padding(.horizontal, 40)
                            .accessibilityLabel("Progres pembakaran")
                    }
                    Spacer()
                    if model.scene.loadingAssets {
                        ProgressView("Menyiapkan lahan…")
                    } else if let error = model.scene.assetError {
                        card {
                            Text(error)
                            Button("Coba lagi") { Task { await model.scene.prepareAssets() } }
                        }
                    } else {
                        if model.stage == .clearing {
                            Text("Berhasil dibersihkan: \(model.collected.count)/\(NukuhViewModel.treeCount)")
                                .font(.caption).padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Color.brown.opacity(0.85), in: Capsule())
                                .accessibilityIdentifier("nukuh.progress")
                        }
                        card {
                            Text(model.stage == .clearing
                                 ? "Coba arahkan ponselmu ke sekeliling dan tap pohon untuk mulai membuka lahan!"
                                 : "Yuk, arahkan ponsel ke sekeliling dan ketuk lahan untuk menyalakan api. Pantau api pembakaran lahan.")
                                .accessibilityIdentifier("nukuh.sceneReady")
                            if !model.motionMessage.isEmpty {
                                Text(model.motionMessage).font(.caption)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 24)
            }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }.accessibilityLabel("Kembali ke beranda")
                    Spacer()
                    if message == .explanation {
                        Button("Ulangi", action: restart)
                            .font(.caption).padding(.horizontal, 16).frame(minHeight: 44)
                            .background(orange.opacity(0.25), in: Capsule())
                            .accessibilityIdentifier("replay")
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
            if journey.progress.record(for: .nukuh).explanationAvailable {
                message = .explanation
            } else {
                model.start()
                model.setVisible(true)
            }
            model.configureLookMotion(reduceMotion: reduceMotion)
            model.scene.muted = !ActivityAudio.shared.enabled
            await model.scene.prepareAssets()
            await model.scene.loadAudio()
            if message == .explanation { model.scene.showBurnedField() }
        }
        .onChange(of: model.stage) { _, stage in
            if stage == .prepared { message = .cleared }
            if stage == .complete {
                if let outcome = model.session.outcome { journey.record(.nukuh, outcome: outcome) }
                message = .ready
            }
        }
        .onChange(of: message) { _, value in model.setHelpVisible(value != nil) }
        .onChange(of: reduceMotion) { _, value in model.configureLookMotion(reduceMotion: value) }
        .onChange(of: scenePhase) { _, value in model.setVisible(value == .active && message != .explanation) }
        .onDisappear { model.setVisible(false); ActivityAudio.shared.stop() }
    }

    @ViewBuilder private func messageOverlay(_ current: Message) -> some View {
        if current == .explanation {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    ScrollView {
                        HumaGlassCard {
                            VStack(spacing: 24) {
                                Text("Kami memanfaatkan abu dari pembakaran rumput dan daun kering untuk menyuburkan tanah.")
                                Text("Jadi, sisa tanaman yang sudah tidak digunakan masih punya manfaat, lho!")
                            }
                        }
                        .frame(width: min(330, max(1, geometry.size.width - 48)),
                               height: min(330, max(1, geometry.size.width - 48)) * 480 / 330)
                        .accessibilityIdentifier("lesson.explanation.card")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .frame(minHeight: max(0, geometry.size.height - 140))
                    }
                    .accessibilityIdentifier("lesson.explanation.page")
                    LessonButton(title: "Lanjut ke tahap berikutnya", identifier: "continue", action: advance)
                        .padding(.horizontal, 24).padding(.vertical, 16)
                }
                .padding(.top, 44)
            }
        } else {
            Button {
                switch current {
                case .cleared: message = .burnIntro
                case .burnIntro: message = nil
                case .ready: message = .explanation; model.setVisible(false)
                case .explanation: break
                }
            } label: {
                VStack(spacing: 20) {
                    Spacer()
                    card {
                        if current == .cleared {
                            Text("Kerja bagus!").font(.headline).foregroundStyle(orange)
                            Text("Sekarang sinar matahari bisa memberi energi ke huma (ladang) yang baru dibuka.")
                        } else if current == .burnIntro {
                            Text("Nah, selanjutnya kita akan Ngahuru (membakar sisa rumput dan daun kering).")
                        } else {
                            Text("Lahan sudah siap ditanam!").font(.headline).foregroundStyle(orange)
                        }
                    }
                    Text("Tap layar untuk lanjutkan.").font(.caption).italic().foregroundStyle(.white.opacity(0.65))
                    Spacer()
                }.padding(.horizontal, 36).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("nukuh.message.continue")
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 16, content: content)
            .font(.subheadline).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity).padding(24)
            .background(Color(red: 0.36, green: 0.29, blue: 0.23).opacity(0.88), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(red: 0.77, green: 0.65, blue: 0.48), lineWidth: 0.75))
    }

    private func restart() {
        message = nil
        model.setHelpVisible(false)
        model.start()
        model.setVisible(true)
    }
}
