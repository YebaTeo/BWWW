import Observation
import Foundation

@Observable @MainActor final class NgaseukViewModel {
    var session = PhaseSessionState()
    private(set) var holes: Set<Int> = []
    private(set) var selectedTarget = 0
    private(set) var lastPlanted: Int?
    private(set) var motionActive = false
    private let motion: any MotionProviding
    private var detector = NgaseukMotionDetector()
    private(set) var isDemonstrating = false
    private(set) var demonstrationHoles: Set<Int> = []
    private(set) var demonstrationTarget = 0
    @ObservationIgnored private var demonstrationTask: Task<Void, Never>?
    @ObservationIgnored private var demonstrationGeneration = 0
    var storyHoles: Set<Int> {
        if session.showsDescription { return Set(0..<3) }
        return isDemonstrating ? demonstrationHoles : holes
    }
    var storyTarget: Int {
        isDemonstrating ? demonstrationTarget : (motionActive ? selectedTarget : (lastPlanted ?? selectedTarget))
    }
    init(motion: any MotionProviding) { self.motion = motion }
    func start() { cancelStoryDemonstration(); demonstrationHoles = []; pauseMotion(); holes = []; selectedTarget = 0; lastPlanted = nil; session.start() }
    func plant(_ target: Int) {
        guard session.isActive, (0..<3).contains(target), holes.insert(target).inserted else { return }
        lastPlanted = target
        session.feedback = "Lubang \(target + 1) dibuat dan diisi benih."
        selectedTarget = (0..<3).first { !holes.contains($0) } ?? target
        if holes.count == 3 { pauseMotion(); session.finish() }
    }
    func tap(_ target: Int) {
        guard session.isActive, (0..<3).contains(target), !holes.contains(target) else { return }
        if motionActive { selectedTarget = target } else { plant(target) }
    }
    func startMotion() {
        cancelStoryDemonstration()
        guard session.isActive else { return }
        guard motion.available else { session.feedback = "Sensor tidak tersedia. Ketuk tanda untuk menanam."; return }
        detector.reset(); motionActive = true
        session.feedback = "Tahan ponsel dengan nyaman. Gerakkan sedikit ke bawah, lalu kembali tenang. Jangan mengguncang atau membenturkan ponsel."
        motion.start { [weak self] sample in
            guard let self, self.motionActive else { return }
            guard let sample else {
                self.pauseMotion(); self.session.feedback = "Gerakan terhenti. Lanjutkan dengan sentuhan atau mulai gerakan lagi."; return
            }
            if self.detector.consume(sample) { self.plant(self.selectedTarget) }
        }
    }
    func pauseMotion() { motionActive = false; motion.stop(); detector.reset() }
    func prepareStoryActivity() {
        if session.stage == .introduction { start() }
    }
    func storyTap(_ target: Int) {
        guard (0..<3).contains(target), !session.showsDescription else { return }
        cancelStoryDemonstration()
        prepareStoryActivity()
        tap(target)
    }
    /// Inject the wait to test cancellation and completion without real-time delays.
    func beginStoryDemonstration(waitForStep: @escaping @Sendable () async throws -> Void = {
        try await Task.sleep(for: .milliseconds(800))
    }) {
        guard !session.showsDescription else { return }
        cancelStoryDemonstration(); pauseMotion(); prepareStoryActivity()
        demonstrationHoles = []; demonstrationTarget = 0; isDemonstrating = true
        session.feedback = "Amati aseuk membuat lubang, lalu benih ditempatkan satu per satu."
        let generation = demonstrationGeneration
        demonstrationTask = Task { [weak self] in
            for target in 0..<3 {
                do { try await waitForStep() } catch { return }
                guard !Task.isCancelled, let self, self.demonstrationGeneration == generation else { return }
                self.demonstrationTarget = target
                self.demonstrationHoles.insert(target)
                self.session.feedback = "Contoh: lubang \(target + 1) diisi benih."
            }
            // Leave time for the last seed placement to be observed before awarding completion.
            do { try await waitForStep() } catch { return }
            guard !Task.isCancelled, let self, self.demonstrationGeneration == generation else { return }
            self.isDemonstrating = false
            self.demonstrationTask = nil
            self.session.finish(.observed)
        }
    }
    func cancelStoryDemonstration() {
        demonstrationGeneration += 1
        demonstrationTask?.cancel(); demonstrationTask = nil
        if isDemonstrating {
            isDemonstrating = false; demonstrationHoles = []
            session.feedback = "Demonstrasi dijeda. Ketuk sasaran atau pilih Lihat caranya untuk mencoba lagi."
        }
    }
    func stopStoryInteraction() {
        let wasMoving = motionActive
        cancelStoryDemonstration(); pauseMotion()
        if wasMoving && session.isActive {
            session.feedback = "Gerakan dijeda. Ketuk sasaran atau aktifkan kembali untuk melanjutkan."
        }
    }
    func demonstrate() { cancelStoryDemonstration(); pauseMotion(); holes = Set(0..<3); session.finish(.observed) }
}
