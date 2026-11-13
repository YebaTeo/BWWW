import Observation
import Foundation
import simd
@Observable @MainActor final class NgoredViewModel {
    enum Step { case weeding, cleared, rain, complete }
    let scene = NgahumaScene()
    private let motion: (any MotionProviding)?
    private var lookMotion = NarawasLookMotion()
    private var lastLookTime: Double?
    private var heading: Double = 0
    private var smoothedHeading: Double = 0
    private var visible = false
    private var motionAllowed = true
    private var motionGeneration = 0

    init(motion: (any MotionProviding)? = nil) {
        self.motion = motion
        scene.activityStage = { .complete }
        scene.onReady = { [weak self] in self?.scene.showNgoredField() }
        scene.muted = true
    }

    func configureLookMotion(reduceMotion: Bool) {
        motionAllowed = !reduceMotion
        scene.reduceMotion = reduceMotion
        updateLookMotion()
    }

    private func updateLookMotion() {
        motionGeneration += 1
        motion?.stop()
        lookMotion.reset()
        lastLookTime = nil
        heading = 0
        smoothedHeading = 0
        guard visible, motionAllowed, session.isActive, let motion, motion.available else { return }
        scene.beginMotionLook()
        let generation = motionGeneration
        motion.start { [weak self] sample in
            guard let self, self.motionGeneration == generation, let sample else { return }
            if let rotation = self.horizontalLook(sample) { self.scene.applyMotionLook(rotation, fixedPosition: true) }
        }
    }

    private func horizontalLook(_ sample: MotionSample) -> simd_quatf? {
        guard let rate = sample.rotationRate, let gravity = sample.gravity else {
            return lookMotion.consume(sample)
        }
        let magnitude = simd_length(gravity)
        // Project the gyro onto world up so turning works at any held tilt.
        let yawRate = -simd_dot(rate, gravity) / magnitude
        guard magnitude > 0.5, yawRate.isFinite, sample.time.isFinite else { return nil }
        guard let previous = lastLookTime else {
            lastLookTime = sample.time
            return nil
        }
        guard sample.time > previous else { return nil }
        lastLookTime = sample.time
        let elapsed = min(0.1, sample.time - previous)
        if abs(yawRate) > 0.02 { heading += yawRate * elapsed }
        smoothedHeading += (heading - smoothedHeading) * (1 - exp(-elapsed / 0.06))
        return simd_quatf(angle: Float(smoothedHeading), axis: [0, 1, 0])
    }

    var session = PhaseSessionState()
    private(set) var removed: Set<Int> = []
    private(set) var lastRemoved: Int?
    private(set) var strokes: [Int: Int] = [:]
    private(set) var step: Step = .weeding
    private(set) var isDemonstrating = false
    private var usedDemo = false
    @ObservationIgnored private var task: Task<Void, Never>?
    func start() {
        suspend()
        removed = []
        strokes = [:]
        lastRemoved = nil
        usedDemo = false
        step = .weeding
        scene.setNgoredRain(false)
        scene.restoreNgoredWeeds()
        scene.resetNgoredRice()
        scene.setNgoredGrowth(0.18)
        scene.setSuspended(!visible)
        session.start()
        updateLookMotion()
    }

    func remove(_ target: Int) {
        guard session.isActive, step == .weeding else { return }
        guard (0..<4).contains(target) else { session.feedback = "Ini padi. Bersihkan gulma di sekitarnya."; return }
        guard !removed.contains(target) else { return }
        strokes[target, default: 0] += 1
        let uprooted = strokes[target] == 3
        scene.animateNgoredWeedStrike(target, uprooted: uprooted)
        ActivityAudio.shared.play(.weed)
        session.feedback = "Gulma \(target + 1): \(strokes[target] ?? 0)/3 sapuan."
        guard strokes[target] == 3 else { return }
        removed.insert(target)
        lastRemoved = target
        session.feedback = "\(removed.count) dari 4 gulma disingkirkan."
        if removed.count == 4 { step = .cleared }
    }

    func observeRain() {
        guard session.isActive, step == .cleared else { return }
        step = .rain
        scene.dissolveUprootedWeedsWithRain()
        if visible { playRain() }
    }

    private func playRain() {
        task?.cancel()
        scene.setNgoredRain(true)
        ActivityAudio.shared.play(.rain)
        task = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            self?.finishRain()
        }
    }

    func finishRain() {
        guard session.isActive, step == .rain else { return }
        task?.cancel()
        task = nil
        scene.setNgoredRain(false)
        ActivityAudio.shared.stop()
        step = .complete
        session.finish(usedDemo ? .observed : .performed)
    }

    func setVisible(_ value: Bool) {
        guard visible != value else { return }
        visible = value
        if value {
            scene.setSuspended(false)
            updateLookMotion()
            if step == .rain && session.isActive { playRain() }
        } else {
            suspend()
        }
    }

    func suspend() {
        motionGeneration += 1
        motion?.stop()
        scene.setSuspended(true)
        ActivityAudio.shared.stop()
        task?.cancel()
        task = nil
        isDemonstrating = false
    }

    func demonstrate() {
        guard session.isActive, step == .weeding || step == .cleared, !isDemonstrating else { return }
        usedDemo = true
        isDemonstrating = true
        task = Task { [weak self] in
            for index in 0..<4 {
                while let self, self.step == .weeding, !self.removed.contains(index) {
                    do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                    guard !Task.isCancelled else { return }
                    self.remove(index)
                }
            }
            guard let self, !Task.isCancelled else { return }
            self.isDemonstrating = false
            self.observeRain()
        }
    }
}
