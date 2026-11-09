import Observation
import Foundation
@Observable @MainActor final class NukuhViewModel {
    var session = PhaseSessionState()
    private(set) var collected: Set<Int> = []
    private(set) var isDemonstrating = false
    let scene = NgahumaScene()
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    private var visible = false
    private var usedDemo = false
    private let motion: (any MotionProviding)?
    private var lookMotion = NukuhLookMotion()
    private var motionGeneration = 0
    private var motionConfigured = false
    private(set) var motionEnabled = true
    private(set) var motionActive = false
    private(set) var motionMessage = ""
    init(motion: (any MotionProviding)? = nil) {
        self.motion = motion
        scene.onCut = { [weak self] index in
            guard let self, self.session.isActive else { return }
            self.collected.insert(index)
            ActivityAudio.shared.play(.cut)
            self.session.feedback = "\(self.collected.count) dari 6 pohon pada ilustrasi telah ditebang."
        }
        scene.onIgnitionRequested = { [weak self] index in self?.burn(startingAt: index) }
        scene.onBurnFinished = { [weak self] in
            guard let self, self.session.isActive else { return }
            self.session.finish(self.usedDemo ? .observed : .performed)
            self.isDemonstrating = false
        }
    }
    func start() { suspend(); collected = []; usedDemo = false; session.start(); scene.reset(); scene.setSuspended(!visible); if visible { startLookMotion() } }
    func collect(_ index: Int) {
        guard session.isActive, !isDemonstrating else { return }
        scene.interact(index)
    }
    func burn() { burn(startingAt: 0) }
    func burn(startingAt index: Int) {
        guard session.isActive, !isDemonstrating else { return }
        scene.ignite(startingAt: index)
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
        guard motionConfigured, motionEnabled, visible, session.isActive, !motionActive else { return }
        guard let motion, motion.available else {
            motionMessage = "Sensor gerakan tidak tersedia. Geser mendatar di lahan untuk melihat sekeliling."
            return
        }
        lookMotion.reset(); scene.beginMotionLook(); motionMessage = ""; motionActive = true
        motionGeneration += 1
        let generation = motionGeneration
        motion.start { [weak self] sample in
            guard let self, self.motionActive, self.motionGeneration == generation else { return }
            guard let sample, sample.attitude != nil else {
                self.stopLookMotion()
                self.motionMessage = "Gerakan dijeda. Gunakan geseran atau aktifkan gerakan lagi."
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
        guard session.isActive, scene.stage != .entering else { return }
        demoTask?.cancel(); usedDemo = true; isDemonstrating = true
        demoTask = Task { [weak self] in
            for index in 0..<6 {
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.scene.interact(index)
            }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            for index in 0..<6 {
                guard !Task.isCancelled else { return }
                self.scene.ignite(startingAt: index)
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            }
        }
    }
}
