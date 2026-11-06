import SwiftUI

/// Sketch's Explore → activity → result → explanation sequence, shared by all phases.
struct PhaseContainerView<Introduction: View, Activity: View, Surface: View, Description: View>: View {
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
    @ViewBuilder let introduction: () -> Introduction
    @ViewBuilder let surface: () -> Surface
    @ViewBuilder let activity: () -> Activity
    @ViewBuilder let description: () -> Description
    @State private var flow = LessonFlowViewModel()
    @State private var restored = false
    @State private var activitySheet = ActivitySheetState()
    @State private var showsActivitySheet = false
    @State private var exitAfterSheet = false
    private var immersive: Bool { flow.screen == .activity || flow.screen == .result }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    private var equipment: String? {
        switch content.id {
        case .ngaseuk: "Aseuk"
        case .dibuat: "Etem / ani-ani"
        default: nil
        }
    }
    private var isResult: Bool { flow.screen == .result || flow.screen == .explanation }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LessonBackdrop(asset: (isResult ? content.after : content.before).assetName)
                if immersive {
                    surface().environment(activitySheet)
                        .disabled(!session.isActive).ignoresSafeArea()
                }
                VStack(spacing: 0) {
                    if flow.screen != .activity { header }
                    switch flow.screen {
                    case .introduction:
                        ScrollView {
                            VStack(spacing: 16) {
                                Color.clear.frame(height: typeSize.isAccessibilitySize ? 24 : max(80, geometry.size.height * 0.34))
                                VStack(spacing: 16) {
                                Text(content.title.uppercased()).font(.largeTitle.weight(.heavy))
                                    .accessibilityAddTraits(.isHeader)
                                Text(content.subtitle).font(.title3.weight(.medium))
                                Text(content.introduction).font(.body)
                                LessonButton(title: "Explore", identifier: "start") { explore() }
                                    .frame(maxWidth: 190).padding(.top, 8)
                                if flow.canSkip {
                                    Button("Lihat penjelasan") { flow.explain() }
                                        .frame(minHeight: 44).accessibilityIdentifier("lesson.explanation")
                                }
                                Text("Geser ke atas untuk mulai menjelajah")
                                    .font(.footnote).padding(.top, 24)
                                Image(systemName: "chevron.down").accessibilityHidden(true)
                                }.padding(typeSize.isAccessibilitySize ? 16 : 0)
                                    .background(typeSize.isAccessibilitySize ? Color.black : Color.clear, in: RoundedRectangle(cornerRadius: 20))
                            }.multilineTextAlignment(.center).padding(24)
                        }
                        .simultaneousGesture(DragGesture(minimumDistance: 60).onEnded { value in
                            guard !typeSize.isAccessibilitySize, value.translation.height < -80,
                                  abs(value.translation.height) > abs(value.translation.width) else { return }
                            explore()
                        })
                    case .equipment:
                        ScrollView {
                        Spacer(minLength: 24)
                        VStack(spacing: 24) {
                            Text("Hayu, kenalan dulu dengan alatnya!").font(.title2.bold())
                            Text(equipment ?? "").font(.title.bold())
                            if content.id == .dibuat {
                                Image("dibuat_etem").resizable().scaledToFit().frame(height: 140)
                            } else {
                                Image(systemName: "line.diagonal").font(.system(size: 100, weight: .light))
                                    .foregroundStyle(Color.brown).accessibilityLabel("Tongkat aseuk")
                            }
                            Text(content.id == .ngaseuk
                                 ? "Aseuk adalah tongkat runcing untuk membuat lubang tempat benih padi."
                                 : "Etem adalah alat panen kecil untuk memotong malai padi. Bulir tetap bersama tangkainya.")
                            LessonButton(title: "Mulai aktivitas", identifier: "lesson.begin") { begin() }
                        }.multilineTextAlignment(.center).padding(24)
                            .foregroundStyle(Color.black.opacity(0.85))
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                            .environment(\.colorScheme, .light).padding(24)
                        Spacer(minLength: 24)
                        }
                    case .activity:
                        Spacer().allowsHitTesting(false)
                    case .result:
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("\(content.title) selesai!").font(.title2.bold())
                                Text(session.outcome == .observed ? "Demonstrasi selesai." : content.result)
                                LessonButton(title: "Lihat penjelasan", identifier: "lesson.result.continue") { flow.explain() }
                                Button("Ulangi") { restartActivity() }.frame(minHeight: 44).accessibilityIdentifier("replay")
                            }.padding(24).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
                                .padding(24)
                        }
                    case .explanation:
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                Color.clear.frame(height: typeSize.isAccessibilitySize ? 0 : geometry.size.height * 0.28)
                                description()
                                    .padding(24)
                                    .background(.black.opacity(typeSize.isAccessibilitySize ? 1 : 0.72), in: RoundedRectangle(cornerRadius: 24))
                            }.padding(24)
                        }.accessibilityIdentifier("lesson.explanation.page")
                        LessonButton(title: content.id.next == nil ? "Selesaikan perjalanan" : "Lanjut ke tahapan berikutnya", identifier: "continue", action: advance)
                            .padding(.horizontal, 24).padding(.vertical, 16)
                    }
                }
            }
        }
        .foregroundStyle(.white).tint(.white)
        .preferredColorScheme(.dark).environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsActivitySheet, onDismiss: {
            if exitAfterSheet { dismiss() }
        }) { activityPanel }
        .onAppear {
            activitySheet.largeText = typeSize.isAccessibilitySize
            guard !restored else { return }
            restored = true
            let record = journey.progress.record(for: content.id)
            restore(record.outcome); flow.restore(completed: record.explanationAvailable)
        }
        .onChange(of: session.event) { _, _ in
            if let outcome = session.outcome {
                journey.record(content.id, outcome: outcome)
                flow.completed()
            }
        }
        .onChange(of: typeSize) { _, value in
            activitySheet.largeText = value.isAccessibilitySize
            if activitySheet.collapsed { activitySheet.collapse() } else { activitySheet.expand() }
        }
        .onChange(of: flow.screen) { _, value in
            let needsSheet = value == .activity
            if needsSheet { activitySheet.expand() }
            showsActivitySheet = needsSheet
            activityVisibility(value == .activity)
            if value != .activity { suspend(); ActivityAudio.shared.stop() }
        }
        .onChange(of: scenePhase) { _, value in
            activityVisibility(value == .active && flow.screen == .activity)
            if value != .active { suspend(); ActivityAudio.shared.stop() }
        }
        .onDisappear { activityVisibility(false); suspend(); ActivityAudio.shared.stop() }
    }

    private var activityPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    exitAfterSheet = true
                    activityVisibility(false); suspend(); ActivityAudio.shared.stop()
                    showsActivitySheet = false
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                        .frame(width: 48, height: 48)
                        .background(Color.primary.opacity(0.06), in: Circle()).contentShape(Circle())
                }.accessibilityLabel("Kembali ke beranda").accessibilityIdentifier("lesson.back")
                Text(content.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if flow.canSkip && flow.screen == .activity && !activitySheet.largeText {
                    Button("Lewati") { flow.explain() }.buttonStyle(.bordered).frame(minHeight: 44)
                        .accessibilityIdentifier("lesson.skip")
                }
                Button {
                    if activitySheet.collapsed { activitySheet.expand() } else { activitySheet.collapse() }
                } label: {
                    Image(systemName: activitySheet.collapsed ? "chevron.up" : "chevron.down")
                        .font(.system(size: 18, weight: .semibold)).frame(width: 48, height: 48)
                        .background(Color.primary.opacity(0.06), in: Circle()).contentShape(Circle())
                }.accessibilityLabel(activitySheet.collapsed ? "Buka petunjuk" : "Lihat seluruh lahan")
                    .accessibilityIdentifier(activitySheet.collapsed ? "activity.sheet.expand" : "activity.sheet.collapse")
            }.buttonStyle(.plain).padding(.horizontal, 12).padding(.top, 12)
            if activitySheet.collapsed {
                if !activitySheet.largeText {
                    Text("Tarik ke atas untuk petunjuk dan kontrol").font(.caption).foregroundStyle(.secondary)
                        .padding(.bottom, 12)
                }
                Spacer(minLength: 0)
            } else {
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Color.clear.frame(height: 1).id("activity.sheet.top").accessibilityHidden(true)
                        if flow.canSkip && activitySheet.largeText {
                            Button("Lewati") { flow.explain() }.accessibilityIdentifier("lesson.skip")
                        }
                        activity().disabled(!session.isActive)
                        if !session.feedback.isEmpty {
                            Text(session.feedback).font(.subheadline).foregroundStyle(.secondary)
                                .accessibilityIdentifier("feedback")
                        }
                        Divider()
                        Button {
                            ActivityAudio.shared.enabled.toggle()
                        } label: {
                            Label(ActivityAudio.shared.enabled ? "Suara aktif" : "Suara nonaktif", systemImage: ActivityAudio.shared.enabled ? "speaker.wave.2" : "speaker.slash")
                                .frame(minHeight: 44)
                        }.accessibilityIdentifier("activity.sound")
                        Button("Lihat demonstrasi", action: demonstrate).frame(minHeight: 48)
                            .accessibilityIdentifier("demonstrate")
                    }.padding(24).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
                }.accessibilityIdentifier("activity.sheet.scroll")
                    .onChange(of: activitySheet.contentRevision) { _, _ in
                        proxy.scrollTo("activity.sheet.top", anchor: .top)
                    }
                }

            }
        }
        .environment(activitySheet)
        .foregroundStyle(.primary).tint(.blue).buttonStyle(.bordered).controlSize(.large)
        .preferredColorScheme(.light).environment(\.colorScheme, .light)
        .presentationDetents(activitySheet.largeText ? [activitySheet.compactDetent, .large] : [activitySheet.compactDetent, .medium, .large], selection: $activitySheet.detent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: activitySheet.largeText ? activitySheet.compactDetent : .medium))
        .presentationContentInteraction(.scrolls)
        .interactiveDismissDisabled()
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }.accessibilityLabel("Kembali ke beranda").accessibilityIdentifier("lesson.back")
            Spacer()
            Text("\(content.id.index + 1) / 5").font(.caption.monospacedDigit())
            Spacer()
            if flow.screen == .explanation {
                Button("Ulangi") { restartActivity() }.frame(minWidth: 60, minHeight: 44)
                    .background(.ultraThinMaterial, in: Capsule()).accessibilityIdentifier("replay")
            } else if flow.canSkip && (flow.screen == .activity || flow.screen == .equipment) {
                Button("Lewati") { flow.explain() }.frame(minWidth: 60, minHeight: 44)
                    .accessibilityIdentifier("lesson.skip")
            } else { Color.clear.frame(width: 60, height: 44) }
        }.padding(.horizontal, 20).padding(.vertical, 8)
    }
    private func explore() {
        guard flow.screen == .introduction else { return }
        flow.explore(hasEquipment: equipment != nil)
        if equipment == nil { start() }
    }
    private func begin() { start(); flow.beginActivity() }
    private func restartActivity() { replay(); flow.replay() }
}
