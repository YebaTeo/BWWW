import Observation
import Foundation
import UIKit
@Observable @MainActor final class NgaseukViewModel {
    enum Step { case instructions, digging, holesReady, seeding }
    var session = PhaseSessionState()
    private(set) var step: Step = .instructions
    private(set) var holes: Set<Int> = []
    private(set) var seeds: Set<Int> = []
    private(set) var selectedTarget = 0
    private(set) var lastDug = 0
    private(set) var motionActive = false
    private(set) var isDemonstrating = false
    private var usedDemo = false
    private let motion: any MotionProviding
    private var detector = NgaseukMotionDetector()
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    init(motion: any MotionProviding) { self.motion = motion }
    func start() { suspend(); holes = []; seeds = []; selectedTarget = 0; lastDug = 0; usedDemo = false; step = .instructions; session.start() }
    func proceed() {
        guard session.isActive else { return }
        if step == .instructions { step = .digging }
        else if step == .holesReady { step = .seeding }
    }
    func dig(_ target: Int) {
        guard session.isActive, step == .digging, (0..<3).contains(target), holes.insert(target).inserted else { return }
        lastDug = target
        ActivityAudio.shared.play(.dig)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selectedTarget = (0..<3).first { !holes.contains($0) } ?? target
        session.feedback = "Lubang \(target + 1) siap."
        if holes.count == 3 { pauseMotion(); step = .holesReady }
    }
    @discardableResult func seed(_ target: Int) -> Bool {
        guard session.isActive, step == .seeding, holes.contains(target), seeds.insert(target).inserted else { return false }
        ActivityAudio.shared.play(.seed)
        session.feedback = "\(seeds.count) dari 3 lubang berisi benih."
        if seeds.count == 3 { session.finish(usedDemo ? .observed : .performed) }
        return true
    }
    func startMotion() {
        guard session.isActive, step == .digging, !isDemonstrating else { return }
        guard motion.available else { session.feedback = "Sensor tidak tersedia. Ketuk tanah untuk membuat lubang."; return }
        detector.reset(); motionActive = true
        motion.start { [weak self] sample in
            guard let self, self.motionActive else { return }
            guard let sample else { self.pauseMotion(); self.session.feedback = "Gerakan dijeda. Kamu dapat melanjutkan dengan sentuhan."; return }
            if self.detector.consume(sample) { self.dig(self.selectedTarget) }
        }
    }
    func pauseMotion() { motionActive = false; motion.stop(); detector.reset() }
    func suspend() { demoTask?.cancel(); demoTask = nil; isDemonstrating = false; pauseMotion() }
    func demonstrate() {
        guard session.isActive else { return }
        suspend(); usedDemo = true; isDemonstrating = true
        demoTask = Task { [weak self] in
            guard let self else { return }
            self.proceed()
            for index in 0..<3 {
                do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                guard !Task.isCancelled else { return }; self.dig(index)
            }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard !Task.isCancelled else { return }; self.proceed()
            for index in 0..<3 {
                do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                guard !Task.isCancelled else { return }; self.seed(index)
            }
            self.isDemonstrating = false
        }
    }
}
