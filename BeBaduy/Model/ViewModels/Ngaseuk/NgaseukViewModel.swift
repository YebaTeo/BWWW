import Observation
import Foundation
import UIKit
@Observable @MainActor final class NgaseukViewModel {
    enum Step { case instructions, digging, holesReady, seeding }
    static let seedsPerHole = 4
    var session = PhaseSessionState()
    private(set) var step: Step = .instructions
    private(set) var holes: Set<Int> = []
    private(set) var digCounts: [Int: Int] = [:]
    private(set) var seeds: Set<Int> = []
    private(set) var selectedTarget = 0
    private(set) var lastDug = 0
    private(set) var motionActive = false
    private(set) var isDemonstrating = false
    private(set) var peekTarget: Int?
    private(set) var isDraggingSeed = false
    private(set) var isSeedInPlantingRange = false
    private(set) var isBasketEntering = false
    private(set) var isBasketTilting = false
    private(set) var isPouring = false
    private var pourDetector = SeedPourMotionDetector()
    @ObservationIgnored private var tutorialTask: Task<Void, Never>?

    func setActivityVisible(_ visible: Bool) {
        if visible {
            guard session.isActive, !motionActive, !isDemonstrating else { return }
            if step == .instructions { startTutorial() }
            else if peekTarget != nil { startPourMotion() }
            else if step == .digging { startMotion() }
        } else {
            cancelTutorial()
            pauseMotion()
            pourTask?.cancel()
            pourTask = nil
            isBasketEntering = false
            isBasketTilting = false
            isPouring = false
        }
    }

    private func startTutorial() {
        guard tutorialTask == nil else { return }
        tutorialTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.tutorialTask = nil
            self.proceed()
            self.startMotion()
        }
    }

    private func cancelTutorial() {
        tutorialTask?.cancel()
        tutorialTask = nil
    }

    private var motionGeneration = 0
    @ObservationIgnored private var pourTask: Task<Void, Never>?
    private var usedDemo = false
    private let motion: any MotionProviding
    private var detector = NgaseukMotionDetector()
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    init(motion: any MotionProviding) { self.motion = motion }
    func start() { suspend(); holes = []; digCounts = [:]; seeds = []; selectedTarget = 0; lastDug = 0; usedDemo = false; step = .instructions; session.start() }
    func proceed() {
        guard session.isActive else { return }
        if step == .instructions { step = .digging }
        else if step == .holesReady { step = .seeding }
    }
    func dig(_ target: Int) {
        guard session.isActive, step == .digging, target == selectedTarget, (0..<3).contains(target),
              !holes.contains(target), (digCounts[target, default: 0] < 3) else { return }
        let count = digCounts[target, default: 0] + 1
        digCounts[target] = count
        lastDug = target
        ActivityAudio.shared.play(.dig)
        if !isDemonstrating { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        if count == 3 { holes.insert(target) }
        // Keep the aseuk on this same spot until all three strikes are done.
        selectedTarget = count < 3 ? target : ((0..<3).first { !holes.contains($0) } ?? target)
        session.feedback = count == 3 ? "Lubang \(target + 1) siap." : "Perlebar lubang \(target + 1): tusukan \(count) dari 3."
        if holes.count == 3 { pauseMotion(); step = .holesReady }
    }
    @discardableResult func seed(_ target: Int) -> Bool {
        guard session.isActive, step == .seeding, holes.contains(target), seeds.insert(target).inserted else { return false }
        ActivityAudio.shared.play(.seed)
        session.feedback = "\(seeds.count) dari 3 lubang berisi benih."
        if seeds.count == 3 { session.finish(usedDemo ? .observed : .performed) }
        return true
    }
    func peek(_ target: Int) {
        guard session.isActive, step == .seeding, holes.contains(target), !isDemonstrating,
              !isBasketEntering, !isBasketTilting, !isPouring else { return }
        closePeek()
        peekTarget = target
        if !seeds.contains(target) { startPourMotion() }
    }
    func beginSeedDrag() {
        guard session.isActive, step == .seeding, !isDemonstrating else { return }
        isDraggingSeed = true
        isSeedInPlantingRange = false
        peekTarget = nil
    }
    func updateSeedDrag(near target: Int?, canPlant: Bool) {
        guard isDraggingSeed else { return }
        guard let target, holes.contains(target), !seeds.contains(target) else {
            peekTarget = nil
            isSeedInPlantingRange = false
            return
        }
        peekTarget = target
        isSeedInPlantingRange = canPlant
    }
    @discardableResult func endSeedDrag() -> Bool {
        guard isDraggingSeed else { return false }
        let target = peekTarget
        let shouldPlant = isSeedInPlantingRange
        isDraggingSeed = false
        isSeedInPlantingRange = false
        guard shouldPlant, target != nil else {
            peekTarget = nil
            return false
        }
        pourSeeds(returnToField: true)
        return isBasketEntering
    }
    func closePeek() {
        pauseMotion()
        pourTask?.cancel(); pourTask = nil; isBasketEntering = false; isPouring = false; peekTarget = nil
        isBasketTilting = false
        isDraggingSeed = false
        isSeedInPlantingRange = false
    }
    func startPourMotion() {
        guard session.isActive, step == .seeding, let target = peekTarget,
              !seeds.contains(target), !isBasketEntering, !isBasketTilting,
              !isPouring, !isDemonstrating else { return }
        pauseMotion()
        guard motion.available else {
            session.feedback = "Gunakan tombol Tuang \(Self.seedsPerHole) benih untuk mengisi lubang."
            return
        }
        pourDetector.reset(); motionActive = true
        let generation = motionGeneration
        motion.start { [weak self] sample in
            guard let self, self.motionActive, self.motionGeneration == generation, self.peekTarget == target else { return }
            guard let sample else {
                self.pauseMotion(); self.session.feedback = "Gerakan dijeda. Ketuk Tuang benih untuk melanjutkan."
                return
            }
            if self.pourDetector.consume(sample) { self.pourSeeds() }
        }
    }
    func pourSeeds(returnToField: Bool = false) {
        guard session.isActive, let target = peekTarget, step == .seeding,
              !seeds.contains(target), !isBasketEntering, !isBasketTilting,
              !isPouring, !isDemonstrating else { return }
        pauseMotion()
        isBasketEntering = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        pourTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(420)) } catch { return }
            guard let self, !Task.isCancelled, self.session.isActive, self.peekTarget == target else { return }
            self.isBasketEntering = false
            self.isBasketTilting = true
            do { try await Task.sleep(for: .milliseconds(420)) } catch { return }
            guard !Task.isCancelled, self.session.isActive, self.peekTarget == target else { return }
            self.isPouring = true
            do { try await Task.sleep(for: .milliseconds(850)) } catch { return }
            guard !Task.isCancelled, self.session.isActive, self.peekTarget == target else { return }
            self.seed(target)
            self.isPouring = false
            if returnToField {
                do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
                guard !Task.isCancelled, self.peekTarget == target else { return }
                self.isBasketTilting = false
                self.peekTarget = nil
            } else {
                self.isBasketTilting = false
            }
            self.pourTask = nil
        }
    }
    func startMotion() {
        guard session.isActive, step == .digging, !isDemonstrating, !motionActive else { return }
        guard motion.available else { session.feedback = "Sensor gerak tidak tersedia. Buka Petunjuk untuk melihat demonstrasi."; return }
        session.feedback = ""
        detector.reset(); motionActive = true
        let generation = motionGeneration
        motion.start { [weak self] sample in
            guard let self, self.motionActive, self.motionGeneration == generation else { return }
            guard let sample else { self.pauseMotion(); self.session.feedback = "Sensor gerak terputus. Buka lalu tutup Petunjuk untuk mencoba lagi."; return }
            if self.detector.consume(sample) { self.dig(self.selectedTarget) }
        }
    }
    func pauseMotion() { motionGeneration += 1; motionActive = false; motion.stop(); detector.reset(); pourDetector.reset() }
    func suspend() { cancelTutorial(); demoTask?.cancel(); demoTask = nil; isDemonstrating = false; closePeek() }
    func demonstrate() {
        guard session.isActive else { return }
        suspend(); usedDemo = true; isDemonstrating = true
        demoTask = Task { [weak self] in
            guard let self else { return }
            self.proceed()
            for index in 0..<3 {
                for _ in 0..<3 {
                    do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                    guard !Task.isCancelled else { return }; self.dig(index)
                }
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
