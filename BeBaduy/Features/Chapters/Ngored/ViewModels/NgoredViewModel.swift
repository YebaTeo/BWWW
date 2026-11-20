import Observation
import Foundation
@Observable @MainActor final class NgoredViewModel {
    enum Step: Equatable {
        case initialRain, weeding, cleared, rain, cycles
        case secondWeeding, secondCleared, finalRain, finalCycles, complete
    }
    let scene = NgahumaScene()
    private let lookSession: FieldLookSession
    private var visible = false
    private var initialRainStartedAt = Date()
    private var initialRainPending = false
    private var initialRainRunning = false
    private var motionAllowed = true
    var needsTouchTargets: Bool { !motionAllowed || !lookSession.isAvailable }

    init(motion: (any MotionProviding)? = nil) {
        lookSession = FieldLookSession(motion: motion, scene: scene)
        scene.activeWeedTargets = { [weak self] in
            guard let self, self.session.isActive, !self.isDemonstrating else { return 0..<0 }
            switch self.step {
            case .weeding: return 0..<4
            case .secondWeeding: return 4..<7
            default: return 0..<0
            }
        }
        scene.activityStage = { .complete }
        scene.onReady = { [weak self] in
            guard let self else { return }
            self.scene.showNgoredField()
            self.configureLoadedScene()
        }
        scene.muted = true
    }

    func configureLookMotion(reduceMotion: Bool) {
        motionAllowed = !reduceMotion
        scene.reduceMotion = reduceMotion
        updateLookMotion()
    }

    private func updateLookMotion() {
        guard visible, motionAllowed, session.isActive else {
            lookSession.stop()
            return
        }
        lookSession.start { [weak self] in
            self?.motionAllowed = false
        }
    }

    var session = PhaseSessionState()
    private(set) var removed: Set<Int> = []
    private(set) var lastRemoved: Int?
    private(set) var step: Step = .initialRain
    private(set) var isDemonstrating = false
    private var usedDemo = false
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    func start() {
        suspend()
        removed = []
        lastRemoved = nil
        usedDemo = false
        step = .initialRain
        initialRainPending = false
        initialRainRunning = false
        scene.focusNgoredRice()
        scene.presentNgoredDaytime()
        scene.setNgoredRain(false)
        scene.restoreNgoredWeeds()
        scene.prepareNgoredInitialGrowth()
        scene.resetNgoredRice()
        scene.setNgoredGrowth(0)
        scene.setSuspended(!visible)
        session.start()
        updateLookMotion()
    }

    func beginInitialRainAfterCard() {
        guard session.isActive, step == .initialRain, !initialRainPending, !initialRainRunning else { return }
        initialRainPending = true
        task?.cancel()
        task = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard let self, self.session.isActive, self.step == .initialRain else { return }
            self.initialRainPending = false
            self.initialRainRunning = true
            self.initialRainStartedAt = Date()
            self.scene.setNgoredRain(true)
            self.scene.animateNgoredInitialWeedGrowth(duration: 5)
            self.scene.setNgoredGrowth(0.18, duration: 5)
            if self.visible { ActivityAudio.shared.play(.rain) }
            self.scheduleInitialRain()
        }
    }

    private func scheduleInitialRain() {
        task?.cancel()
        initialRainStartedAt = Date()
        task = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            guard let self, !Task.isCancelled, self.session.isActive else { return }
            self.scene.setNgoredRain(false)
            ActivityAudio.shared.stop()
            if self.needsTouchTargets { self.scene.frameNgoredWeedingWithoutMotion() }
            self.step = .weeding
            self.task = nil
        }
    }

    private func configureLoadedScene() {
        guard session.isActive else { return }
        switch step {
        case .initialRain:
            guard initialRainRunning else {
                scene.setNgoredRain(false)
                scene.restoreNgoredWeeds()
                scene.prepareNgoredInitialGrowth()
                scene.resetNgoredRice()
                return
            }
            let remaining = max(0.1, 5 - Date().timeIntervalSince(initialRainStartedAt))
            scene.setNgoredRain(true)
            scene.restoreNgoredWeeds()
            scene.animateNgoredInitialWeedGrowth(duration: remaining)
            scene.resetNgoredRice()
            scene.setNgoredGrowth(0.18, duration: remaining)
        case .weeding:
            scene.setNgoredRain(false)
            scene.restoreNgoredWeeds()
            scene.resetNgoredRice()
            scene.setNgoredGrowth(0.18)
        default:
            break
        }
    }

    func remove(_ target: Int) {
        guard session.isActive, step == .weeding || step == .secondWeeding else { return }
        let secondRound = step == .secondWeeding
        let targets = secondRound ? 4..<7 : 0..<4
        guard targets.contains(target) else { session.feedback = "Ini padi. Bersihkan gulma di sekitarnya."; return }
        guard removed.insert(target).inserted else { return }
        scene.uprootNgoredWeed(target)
        ActivityAudio.shared.play(.weed)
        lastRemoved = target
        let removedThisRound = targets.filter { removed.contains($0) }.count
        session.feedback = "\(removedThisRound) dari \(targets.count) gulma disingkirkan."
        if removedThisRound == targets.count { step = secondRound ? .secondCleared : .cleared }
    }

    func observeRain() {
        guard session.isActive, step == .cleared || step == .secondCleared else { return }
        let secondRound = step == .secondCleared
        step = secondRound ? .finalRain : .rain
        task?.cancel()
        task = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard let self, self.session.isActive else { return }
            self.scene.dissolveUprootedWeedsWithRain()
            self.playRain(secondRound: secondRound)
        }
    }

    private func playRain(secondRound: Bool) {
        task?.cancel()
        scene.setNgoredRain(true)
        ActivityAudio.shared.play(.rain)
        task = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            guard let self, !Task.isCancelled, self.session.isActive else { return }
            self.scene.setNgoredRain(false)
            ActivityAudio.shared.stop()
            if secondRound { self.beginFinalCycles() } else { self.beginGrowthCycles() }
        }
    }

    func finishRain() {
        guard session.isActive, step == .rain || step == .finalRain else { return }
        task?.cancel()
        scene.setNgoredRain(false)
        ActivityAudio.shared.stop()
        if step == .finalRain { beginFinalCycles() } else { beginGrowthCycles() }
    }

    private func beginGrowthCycles() {
        step = .cycles
        scene.revealNgoredRegrowth(duration: 4.5)
        scene.animateNgoredDayNight(cycles: 3, duration: 12, growthFrom: 0.18, growthTo: 0.5) { [weak self] in
            guard let self, self.session.isActive else { return }
            self.scene.presentNgoredDaytime()
            self.removed.formUnion(0..<4)
            self.step = .secondWeeding
        }
    }

    private func beginFinalCycles() {
        step = .finalCycles
        scene.animateNgoredDayNight(cycles: 3, duration: 12, growthFrom: 0.5, growthTo: 1) { [weak self] in
            guard let self, self.session.isActive else { return }
            self.step = .complete
            self.lookSession.stop()
            self.session.finish(self.usedDemo ? .observed : .performed)
        }
    }

    func setVisible(_ value: Bool) {
        guard visible != value else { return }
        visible = value
        if value {
            scene.setSuspended(false)
            updateLookMotion()
            if (step == .rain || step == .finalRain || (step == .initialRain && initialRainRunning)) && session.isActive {
                if step == .initialRain { ActivityAudio.shared.play(.rain) }
                if step == .initialRain {
                    scheduleInitialRain()
                } else {
                    playRain(secondRound: step == .finalRain)
                }
            }
        } else {
            suspend()
        }
    }

    func suspend() {
        lookSession.stop()
        scene.setSuspended(true)
        ActivityAudio.shared.stop()
        task?.cancel()
        task = nil
        initialRainPending = false
        demoTask?.cancel()
        demoTask = nil
        isDemonstrating = false
    }

    func demonstrate() {
        guard session.isActive, step == .initialRain || step == .weeding, !isDemonstrating else { return }
        usedDemo = true
        isDemonstrating = true
        demoTask = Task { [weak self] in
            guard let self else { return }
            guard await self.waitFor(.weeding) else { return }
            for index in 0..<4 {
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                self.remove(index)
            }
            guard await self.waitFor(.cleared) else { return }
            self.observeRain()
            guard await self.waitFor(.secondWeeding) else { return }
            for index in 4..<7 {
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                self.remove(index)
            }
            guard await self.waitFor(.secondCleared) else { return }
            self.observeRain()
            guard await self.waitFor(.complete) else { return }
            self.isDemonstrating = false
            self.demoTask = nil
        }
    }

    private func waitFor(_ expected: Step) async -> Bool {
        while session.isActive, step != expected, !Task.isCancelled {
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return false }
        }
        return !Task.isCancelled && step == expected
    }
}
