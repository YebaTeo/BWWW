import Observation
import Foundation
@Observable @MainActor final class NgoredViewModel {
    enum Step { case initialRain, weeding, cleared, rain, cycles, secondWeeding, secondCleared, finalRain, finalCycles, complete }
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
    func start() {
        suspend(); removed = []; strokes = [:]; lastRemoved = nil; step = .initialRain; usedDemo = false
        scene.setNgoredRain(true); scene.restoreNgoredWeeds(); scene.resetNgoredRice(); scene.setNgoredGrowth(0)
        scene.setSuspended(!visible); session.start(); updateLookMotion()
        scheduleInitialRain()
    }

    private func scheduleInitialRain() {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            guard !Task.isCancelled, self.session.isActive else { return }
            self.scene.setNgoredRain(false); ActivityAudio.shared.stop()
            self.scene.setNgoredGrowth(0.18, duration: 3); self.step = .weeding
        }
    }
    func remove(_ target: Int) {
        guard session.isActive, step == .weeding || step == .secondWeeding else { return }
        let secondRound = step == .secondWeeding
        let targets = secondRound ? 4..<7 : 0..<4
        guard targets.contains(target) else { session.feedback = "Ini padi. Bersihkan gulma di sekitarnya."; return }
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
        let roundDone = secondRound
            ? (4..<7).filter { removed.contains($0) }.count == 3
            : (0..<4).filter { removed.contains($0) }.count == 4
        if roundDone { step = secondRound ? .secondCleared : .cleared }
    }
    func observeRain() {
        guard session.isActive, step == .cleared || step == .secondCleared else { return }
        let secondRound = step == .secondCleared
        step = secondRound ? .finalRain : .rain
        scene.setNgoredRain(true); scene.dissolveUprootedWeedsWithRain(); ActivityAudio.shared.play(.rain)
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            guard !Task.isCancelled, self.session.isActive else { return }
            self.scene.setNgoredRain(false); ActivityAudio.shared.stop()
            self.step = secondRound ? .finalCycles : .cycles
            if !secondRound {
                self.scene.revealNgoredRegrowth(duration: 28)
            }
            let cycleCount = secondRound ? 4 : 3
            self.scene.animateNgoredDayNight(cycles: cycleCount, duration: Double(cycleCount) * 4,
                growthFrom: secondRound ? 0.5 : 0.18, growthTo: secondRound ? 1 : 0.5) { [weak self] in
                guard let self, self.session.isActive else { return }
                if secondRound {
                    self.step = .complete
                    self.session.finish(self.usedDemo ? .observed : .performed)
                } else {
                    self.scene.presentNgoredDaytime()
                    self.removed.formUnion(0..<4)
                    self.step = .secondWeeding
                }
            }
        }
    }
    func finishRain() { observeRain() }
    func setVisible(_ value: Bool) { visible = value; scene.setSuspended(!value); updateLookMotion(); if value && (step == .rain || step == .finalRain || step == .initialRain) { ActivityAudio.shared.play(.rain) } else if !value { suspend() } }
    func suspend() { motionGeneration += 1; motion?.stop(); scene.setSuspended(true); ActivityAudio.shared.stop(); task?.cancel(); task = nil; isDemonstrating = false }
    func demonstrate() {
        guard session.isActive else { return }
        suspend(); scene.setSuspended(!visible); usedDemo = true; isDemonstrating = true
        task = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            guard !Task.isCancelled, let self else { return }
            self.scene.setNgoredRain(false)
            self.scene.setNgoredGrowth(0.18, duration: 3)
            self.step = .weeding
            for index in 0..<4 {
                for _ in 0..<3 {
                    do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                    guard !Task.isCancelled else { return }
                    self.remove(index)
                }
            }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard !Task.isCancelled else { return }; self.observeRain()
            do { try await Task.sleep(for: .seconds(38)) } catch { return }
            guard !Task.isCancelled else { return }
            for index in 4..<7 {
                for _ in 0..<3 {
                    do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                    guard !Task.isCancelled else { return }; self.remove(index)
                }
            }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard !Task.isCancelled else { return }; self.observeRain()
            do { try await Task.sleep(for: .seconds(38)) } catch { return }
            guard !Task.isCancelled else { return }; self.isDemonstrating = false
        }
    }
}
