import Observation
import Foundation
@Observable @MainActor final class DibuatViewModel {
    enum Step { case harvesting, balanceInstructions, balancing, drying }
    var session = PhaseSessionState()
    private(set) var harvested: Set<Int> = []
    private(set) var step: Step = .harvesting
    private(set) var balance = 0.65
    private(set) var steadyTime: Double = 0
    private(set) var motionActive = false
    private(set) var isDemonstrating = false
    private var usedDemo = false
    private let motion: any MotionProviding
    private var lastSample: Double?
    private var baseRoll: Double?
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    init(motion: any MotionProviding) { self.motion = motion }
    func start() { suspend(); harvested = []; step = .harvesting; balance = 0.65; steadyTime = 0; usedDemo = false; session.start() }
    func harvest(_ head: Int) {
        guard session.isActive, step == .harvesting, (0..<4).contains(head), harvested.insert(head).inserted else { return }
        ActivityAudio.shared.play(.harvest)
        if harvested.count == 4 { step = .balanceInstructions }
    }
    func beginBalance() {
        guard session.isActive, step == .balanceInstructions else { return }
        step = .balancing; ActivityAudio.shared.play(.bamboo); resume()
    }
    func setBalance(_ value: Double) {
        guard step == .balancing, value.isFinite else { return }
        balance = min(1, max(-1, value))
    }
    func tick(_ seconds: Double) {
        guard session.isActive, step == .balancing, seconds.isFinite, seconds > 0, abs(balance) < 0.18 else { return }
        steadyTime = min(3, steadyTime + min(seconds, 0.1))
        if steadyTime >= 3 { pauseMotion(); timer?.cancel(); step = .drying }
    }
    func resume() {
        guard step == .balancing, session.isActive, timer == nil else { return }
        timer = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                guard !Task.isCancelled, let self else { return }; self.tick(0.1)
            }
        }
    }
    func startMotion() {
        guard session.isActive, step == .balancing else { return }
        guard motion.available else { session.feedback = "Sensor tidak tersedia. Geser pengatur keseimbangan di bawah."; return }
        baseRoll = nil; lastSample = nil; motionActive = true; resume()
        motion.start { [weak self] sample in
            guard let self, self.motionActive else { return }
            guard let sample, sample.roll.isFinite, sample.time.isFinite else { self.pauseMotion(); return }
            guard self.lastSample == nil || sample.time > self.lastSample! else { return }
            self.lastSample = sample.time
            if self.baseRoll == nil { self.baseRoll = sample.roll }
            self.setBalance((sample.roll - (self.baseRoll ?? 0)) * 2 + 0.65)
        }
    }
    func pauseMotion() { motionActive = false; motion.stop(); baseRoll = nil; lastSample = nil }
    func finishDrying() { guard session.isActive, step == .drying else { return }; session.finish(usedDemo ? .observed : .performed) }
    func suspend() { pauseMotion(); timer?.cancel(); timer = nil; demoTask?.cancel(); demoTask = nil; isDemonstrating = false }
    func demonstrate() {
        guard session.isActive else { return }
        suspend(); usedDemo = true; isDemonstrating = true
        demoTask = Task { [weak self] in
            for i in 0..<4 {
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
                guard !Task.isCancelled, let self else { return }; self.harvest(i)
            }
            guard let self else { return }
            self.beginBalance(); self.resume(); self.setBalance(0)
            while self.step == .balancing {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard !Task.isCancelled else { return }; self.finishDrying(); self.isDemonstrating = false
        }
    }
}
