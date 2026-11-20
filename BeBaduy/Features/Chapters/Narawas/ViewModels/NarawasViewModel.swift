import Observation
import Foundation
@Observable @MainActor final class NarawasViewModel {
    static let treeCount = 3
    static let tapsPerTree = 4
    enum Stage { case entering, clearing, prepared, burning, complete }
    private(set) var stage: Stage = .entering
    private(set) var ignited: Set<Int> = []
    var session = PhaseSessionState()
    private(set) var collected: Set<Int> = []
    private(set) var treeTapCounts: [Int: Int] = [:]
    private(set) var struckTree: Int?
    private(set) var swingCount = 0
    private(set) var isDemonstrating = false
    let scene = NgahumaScene()
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    private var visible = false
    private var helpVisible = false

    func setHelpVisible(_ value: Bool) {
        helpVisible = value
        if value { lookSession.stop() } else { startLookMotion() }
    }
    private var usedDemo = false
    private let lookSession: FieldLookSession
    private var motionConfigured = false
    private(set) var motionEnabled = true
    var motionActive: Bool { lookSession.isActive }
    private(set) var motionMessage = ""
    init(motion: (any MotionProviding)? = nil) {
        lookSession = FieldLookSession(motion: motion, scene: scene)
        scene.activityStage = { [weak self] in self?.stage ?? .entering }
        scene.onReady = { [weak self] in
            guard let self, self.stage == .entering else { return }
            self.stage = .clearing
        }
        scene.onTreeTapped = { [weak self] index in self?.collect(index) }
        scene.onIgnitionRequested = { [weak self] index in self?.burn(startingAt: index) }
        scene.onFireSettled = { [weak self] in self?.finishBurn() }
    }

    func start() {
        suspend()
        stage = .entering
        collected.removeAll()
        treeTapCounts.removeAll()
        struckTree = nil
        ignited.removeAll()
        usedDemo = false
        session.start()
        scene.reset()
        scene.setSuspended(!visible)
        if visible { startLookMotion() }
    }

    func collect(_ index: Int) {
        guard !isDemonstrating else { return }
        cutTree(index)
    }

    func clearStruckTree() {
        struckTree = nil
    }

    private func cutTree(_ index: Int) {
        guard session.isActive, stage == .clearing, (0..<NarawasViewModel.treeCount).contains(index),
              !collected.contains(index) else { return }
        struckTree = index
        swingCount += 1
        let tapCount = (treeTapCounts[index] ?? 0) + 1
        treeTapCounts[index] = tapCount
        ActivityAudio.shared.play(.cut)

        if tapCount < Self.tapsPerTree {
            scene.animateChop(index, tapCount: tapCount, requiredTaps: Self.tapsPerTree)
            session.feedback = "Pohon \(index + 1) ditebas (\(tapCount)/\(Self.tapsPerTree) tebasan)."
            return
        }

        collected.insert(index)
        scene.animateCut(index)
        session.feedback = "\(collected.count) dari \(Self.treeCount) pohon pada ilustrasi telah ditebang."
        if collected.count == NarawasViewModel.treeCount { stage = .prepared }
    }

    func burn(startingAt index: Int = 0) {
        guard !isDemonstrating else { return }
        ignitePatch(index)
    }

    private func ignitePatch(_ index: Int) {
        guard visible, session.isActive, stage == .prepared || stage == .burning,
              (0..<NarawasViewModel.treeCount).contains(index), ignited.insert(index).inserted else { return }
        stage = .burning
        scene.animateIgnition(at: index)
    }

    func finishBurn() {
        guard session.isActive, stage == .burning, ignited.count == NarawasViewModel.treeCount else { return }
        stage = .complete
        scene.showBurnedField()
        session.finish(usedDemo ? .observed : .performed)
        isDemonstrating = false
    }

    func restore(_ outcome: ActivityOutcome?) { session.restore(outcome) }
    func setVisible(_ value: Bool) { visible = value; if !value { suspend() } else { scene.setSuspended(false); startLookMotion() } }
    func suspend() { lookSession.stop(); demoTask?.cancel(); demoTask = nil; isDemonstrating = false; scene.setSuspended(true) }
    func configureLookMotion(reduceMotion: Bool) {
        scene.reduceMotion = reduceMotion
        if !motionConfigured { motionEnabled = !reduceMotion; motionConfigured = true }
        if reduceMotion { motionEnabled = false; lookSession.stop() }
        else { startLookMotion() }
    }
    func toggleLookMotion() {
        motionEnabled.toggle()
        if motionEnabled { startLookMotion() } else { lookSession.stop() }
    }
    func recenterLook() {
        lookSession.stop(); scene.recenterLook(); startLookMotion()
    }
    private func startLookMotion() {
        guard motionConfigured, motionEnabled, visible, !helpVisible, session.isActive, !motionActive else { return }
        guard lookSession.isAvailable else {
            motionMessage = "Arahkan ponsel ke kiri dan kanan untuk melihat sekeliling."
            return
        }
        motionMessage = ""
        lookSession.start { [weak self] in
            self?.motionMessage = "Gerakan dijeda. Aktifkan gerakan lagi untuk melihat sekeliling."
            self?.motionEnabled = false
        }
    }
    func demonstrate() {
        guard session.isActive, visible, stage != .entering, stage != .complete else { return }
        demoTask?.cancel(); usedDemo = true; isDemonstrating = true
        demoTask = Task { [weak self] in
            for index in 0..<NarawasViewModel.treeCount {
                for _ in 0..<NarawasViewModel.tapsPerTree {
                    do { try await Task.sleep(for: .milliseconds(160)) } catch { return }
                    guard let self, !Task.isCancelled else { return }
                    if self.collected.contains(index) { break }
                    self.cutTree(index)
                }
            }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            for index in 0..<NarawasViewModel.treeCount {
                guard !Task.isCancelled else { return }
                self.ignitePatch(index)
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            }
        }
    }
}
