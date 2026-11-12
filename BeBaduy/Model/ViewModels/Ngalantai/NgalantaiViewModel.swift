import Observation
import Foundation

@Observable @MainActor final class NgalantaiViewModel {
    enum Step { case awaitingLandscape, balanceInstructions, balancing, balanceDemo, awaitingPortrait, drying, complete }
    var session = PhaseSessionState()
    private(set) var step: Step = .awaitingLandscape
    private(set) var balance = 0.65
    private(set) var steadyTime = 0.0
    private(set) var motionActive = false
    private(set) var isDemonstrating = false
    private(set) var rackAnimationReady = false
    private(set) var usesTouch = false
    private var landscapeDirection = 0
    private var visible = false
    private var usedDemo = false
    private let motion: any MotionProviding
    private var baseline: Double?
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    @ObservationIgnored private var rackDelayTask: Task<Void, Never>?

    var allowsLandscape: Bool {
        step == .awaitingLandscape || step == .balanceInstructions || step == .balancing || (step == .balanceDemo && landscapeDirection != 0)
    }

    init(motion: any MotionProviding) { self.motion = motion }

    func start() {
        suspend()
        rackDelayTask?.cancel(); rackDelayTask = nil; rackAnimationReady = false
        step = .awaitingLandscape
        balance = 0.65; steadyTime = 0; usedDemo = false; usesTouch = false
        landscapeDirection = 0
        session.start()
    }

    func orientationChanged(_ direction: Int) {
        guard landscapeDirection != direction else { return }
        landscapeDirection = direction
        stopBalance()
        if step == .balanceDemo { return }
        if direction == 0 {
            if step == .awaitingPortrait { step = .drying }
            else if allowsLandscape { step = .awaitingLandscape }
        } else if allowsLandscape && step != .balanceDemo {
            step = .balanceInstructions
        }
    }

    func beginBalance() {
        guard session.isActive, step == .balanceInstructions, landscapeDirection != 0 else { return }
        step = .balancing
        rackDelayTask?.cancel()
        rackDelayTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard let self, self.session.isActive, self.step == .balancing else { return }
            self.rackAnimationReady = true
        }
        ActivityAudio.shared.play(.bamboo)
        resume()
    }

    func showHelp() {
        guard step == .balancing else { return }
        stopBalance()
        step = .balanceInstructions
    }

    func setBalance(_ value: Double) {
        guard step == .balancing, value.isFinite else { return }
        balance = min(1, max(-1, value))
        if abs(balance) >= 0.18 { steadyTime = 0 }
    }

    func tick(_ seconds: Double) {
        guard visible, session.isActive, step == .balancing, landscapeDirection != 0,
              seconds.isFinite, seconds > 0, abs(balance) < 0.18 else { return }
        steadyTime = min(3, steadyTime + min(seconds, 0.1))
        if steadyTime >= 3 - 1e-9 { finishBalance() }
    }

    private func finishBalance() {
        stopBalance()
        step = landscapeDirection == 0 ? .drying : .awaitingPortrait
    }

    func resume() {
        visible = true
        guard step == .balancing, landscapeDirection != 0, session.isActive, timer == nil else { return }
        if !usesTouch { startMotion() }
        timer = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                guard let self, self.visible else { return }
                if self.usesTouch || self.baseline != nil { self.tick(0.1) }
            }
        }
    }

    func useTouch() {
        pauseMotion()
        usesTouch = true
    }

    func startMotion() {
        guard visible, session.isActive, step == .balancing, landscapeDirection != 0 else { return }
        guard motion.available else { useTouch(); return }
        usesTouch = false; baseline = nil; steadyTime = 0; motionActive = true
        let direction = Double(landscapeDirection)
        motion.start { [weak self] sample in
            guard let self, self.motionActive else { return }
            guard let gravity = sample?.gravity, gravity.y.isFinite else { self.useTouch(); return }
            // The landscape screen's horizontal axis is the device's portrait Y axis.
            let tilt = gravity.y * direction
            if self.baseline == nil {
                self.baseline = tilt
                self.setBalance(0)
                return
            }
            let target = (tilt - (self.baseline ?? tilt)) * 3
            self.setBalance(self.balance + (target - self.balance) * 0.2)
        }
    }

    private func pauseMotion() {
        if motionActive { motion.stop() }
        motionActive = false
        baseline = nil
    }

    private func stopBalance() {
        pauseMotion()
        timer?.cancel(); timer = nil
        steadyTime = 0
    }

    func finishDrying() {
        guard session.isActive, step == .drying else { return }
        step = .complete
        session.finish(usedDemo ? .observed : .performed)
    }

    func suspend() {
        visible = false
        stopBalance()
        demoTask?.cancel(); demoTask = nil
        isDemonstrating = false
        if step == .balanceDemo {
            step = landscapeDirection == 0 ? .awaitingLandscape : .balanceInstructions
        }
    }

    func demonstrate() {
        guard session.isActive, !isDemonstrating, step != .awaitingPortrait, step != .drying else { return }
        stopBalance()
        isDemonstrating = true
        demoTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isDemonstrating = false }
            self.step = .balanceDemo
            for frame in 0...37 {
                self.balance = 0.45 * max(0, 1 - Double(frame) / 7)
                self.steadyTime = Double(max(0, frame - 7)) / 10
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            self.usedDemo = true
            self.finishBalance()
        }
    }
}
