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
    private(set) var isDemonstrating = false
    let scene = NgahumaScene()
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    private var visible = false
    private var helpVisible = false

    func setHelpVisible(_ value: Bool) {
        helpVisible = value
        if value { stopLookMotion() } else { startLookMotion() }
    }
    private var usedDemo = false
    private let motion: (any MotionProviding)?
    private var lookMotion = NarawasLookMotion()
    private var motionGeneration = 0
    private var motionConfigured = false
    private(set) var motionEnabled = true
    private(set) var motionActive = false
    private(set) var motionMessage = ""
    init(motion: (any MotionProviding)? = nil) {
        self.motion = motion
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

    private func cutTree(_ index: Int) {
        guard session.isActive, stage == .clearing, (0..<NarawasViewModel.treeCount).contains(index),
              !collected.contains(index) else { return }
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
    func suspend() { stopLookMotion(); demoTask?.cancel(); demoTask = nil; isDemonstrating = false; scene.setSuspended(true) }
    func configureLookMotion(reduceMotion: Bool) {
        scene.reduceMotion = reduceMotion
        if !motionConfigured { motionEnabled = !reduceMotion; motionConfigured = true }
        if reduceMotion { motionEnabled = false; stopLookMotion() }
        else { startLookMotion() }
    }
    func toggleLookMotion() {
        motionEnabled.toggle()
        if motionEnabled { startLookMotion() } else { stopLookMotion() }
    }
    func recenterLook() {
        stopLookMotion(); scene.recenterLook(); startLookMotion()
    }
    private func startLookMotion() {
        guard motionConfigured, motionEnabled, visible, !helpVisible, session.isActive, !motionActive else { return }
        guard let motion, motion.available else {
            motionMessage = "Arahkan ponsel ke kiri dan kanan untuk melihat sekeliling."
            return
        }
        lookMotion.reset(); scene.beginMotionLook(); motionMessage = ""; motionActive = true
        motionGeneration += 1
        let generation = motionGeneration
        motion.start { [weak self] sample in
            guard let self, self.motionActive, self.motionGeneration == generation else { return }
            guard let sample, sample.attitude != nil else {
                self.stopLookMotion()
                self.motionMessage = "Gerakan dijeda. Aktifkan gerakan lagi untuk melihat sekeliling."
                self.motionEnabled = false
                return
            }
            if let rotation = self.lookMotion.consume(sample) { self.scene.applyMotionLook(rotation) }
        }
    }
    private func stopLookMotion() {
        motionGeneration += 1
        if motionActive { motion?.stop() }
        motionActive = false; lookMotion.reset()
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
