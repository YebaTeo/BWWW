import Observation
import Foundation
@Observable @MainActor final class NgoredViewModel {
    enum Step { case weeding, cleared, rain }
    let scene = NgahumaScene()
    private let motion: (any MotionProviding)?
    private var lookMotion = NarawasLookMotion()
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
        guard visible, motionAllowed, session.isActive, let motion, motion.available else { return }
        scene.beginMotionLook()
        let generation = motionGeneration
        motion.start { [weak self] sample in
            guard let self, self.motionGeneration == generation, let sample else { return }
            if let rotation = self.lookMotion.consume(sample) { self.scene.applyMotionLook(rotation) }
        }
    }

    var session = PhaseSessionState()
    private(set) var removed: Set<Int> = []
    private(set) var lastRemoved: Int?
    private(set) var strokes: [Int: Int] = [:]
    private(set) var step: Step = .weeding
    private(set) var isDemonstrating = false
    private var usedDemo = false
    @ObservationIgnored private var task: Task<Void, Never>?
    func start() { suspend(); removed = []; strokes = [:]; lastRemoved = nil; step = .weeding; usedDemo = false; scene.restoreNgoredWeeds(); session.start(); scene.setSuspended(!visible); updateLookMotion() }
    func remove(_ target: Int) {
        guard session.isActive, step == .weeding else { return }
        guard (0..<8).contains(target) else { session.feedback = "Ini padi. Bersihkan gulma di sekitarnya."; return }
        guard !removed.contains(target) else { return }
        strokes[target, default: 0] += 1
        let uprooted = strokes[target] == 3
        scene.animateNgoredWeedStrike(target, uprooted: uprooted)
        ActivityAudio.shared.play(.weed)
        session.feedback = "Gulma \(target + 1): \(strokes[target] ?? 0)/3 sapuan."
        guard strokes[target] == 3 else { return }
        removed.insert(target)
        lastRemoved = target
        session.feedback = "\(removed.count) dari 8 gulma disingkirkan."
        if removed.count == 8 { step = .cleared }
    }
    func observeRain() { guard session.isActive, step == .cleared else { return }; step = .rain; ActivityAudio.shared.play(.rain) }
    func finishRain() { guard session.isActive, step == .rain else { return }; ActivityAudio.shared.stop(); session.finish(usedDemo ? .observed : .performed) }
    func setVisible(_ value: Bool) { visible = value; scene.setSuspended(!value); updateLookMotion(); if value && step == .rain { ActivityAudio.shared.play(.rain) } else if !value { suspend() } }
    func suspend() { motionGeneration += 1; motion?.stop(); scene.setSuspended(true); ActivityAudio.shared.stop(); task?.cancel(); task = nil; isDemonstrating = false }
    func demonstrate() {
        guard session.isActive else { return }
        suspend(); scene.setSuspended(!visible); usedDemo = true; isDemonstrating = true
        task = Task { [weak self] in
            for index in 0..<8 {
                for _ in 0..<3 {
                    do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                    guard !Task.isCancelled, let self else { return }; self.remove(index)
                }
            }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard !Task.isCancelled, let self else { return }; self.observeRain()
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard !Task.isCancelled else { return }; self.finishRain(); self.isDemonstrating = false
        }
    }
}
