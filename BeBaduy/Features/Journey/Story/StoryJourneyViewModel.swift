import Foundation
import Observation

enum StorySectionID: String, CaseIterable, Identifiable {
    case ngaseukIntroduction = "ngaseuk.introduction"
    case ngaseukActivity = "ngaseuk.activity"
    case ngaseukExplanation = "ngaseuk.explanation"
    case ngoredIntroduction = "ngored.introduction"
    var id: String { rawValue }
}

/// A disposable pilot store. Never reads or writes UserDefaults.
@MainActor final class StoryPreviewStore: ProgressStoring {
    var recoveryMessage: String? { nil }
    private var value: JourneyProgress
    init() {
        var progress = JourneyProgress()
        for phase in PhaseID.allCases.prefix(4) { progress.complete(phase, outcome: .observed) }
        progress.currentPhase = .ngaseuk
        value = progress
    }
    func load() -> JourneyProgress { value }
    func save(_ progress: JourneyProgress) throws { value = progress }
}

@Observable @MainActor final class StoryJourneyViewModel {
    let journey: JourneyViewModel
    let ngaseuk: NgaseukViewModel
    private(set) var unlocked: Bool
    private(set) var activityVisible = false
    // Reading is deliberately independent from completion; no progress schema changes.
    private(set) var readingSection: StorySectionID = .ngaseukIntroduction
    var sections: [StorySectionID] { unlocked ? StorySectionID.allCases : [.ngaseukIntroduction, .ngaseukActivity] }

    init(journey: JourneyViewModel, motion: any MotionProviding) {
        self.journey = journey
        ngaseuk = NgaseukViewModel(motion: motion)
        unlocked = journey.progress.record(for: .ngaseuk).explanationAvailable
        ngaseuk.session.restore(journey.progress.record(for: .ngaseuk).outcome)
    }
    func acceptOutcome() {
        guard ngaseuk.session.showsDescription, let outcome = ngaseuk.session.outcome else { return }
        journey.record(.ngaseuk, outcome: outcome)
        unlocked = true
    }
    func updateVisibility(frames: [StorySectionID: CGRect], viewport: CGRect) {
        guard viewport.height > 0 else { return }
        let visible = frames.filter { sections.contains($0.key) && $0.value.intersects(viewport) }
        if let closest = visible.max(by: { intersectionHeight($0.value, viewport) < intersectionHeight($1.value, viewport) }) {
            readingSection = closest.key
        }
        let frame = frames[.ngaseukActivity] ?? .zero
        let fraction = intersectionHeight(frame, viewport) / max(1, min(frame.height, viewport.height))
        setActivityVisible(fraction >= 0.25)
    }
    private func intersectionHeight(_ frame: CGRect, _ viewport: CGRect) -> CGFloat {
        let intersection = frame.intersection(viewport)
        return intersection.isNull ? 0 : max(0, intersection.height)
    }
    func setActivityVisible(_ visible: Bool) {
        activityVisible = visible
        if !visible { suspend() }
    }
    func suspend() { ngaseuk.stopStoryInteraction() }
    func plant(_ target: Int) {
        guard activityVisible else { return }
        ngaseuk.storyTap(target)
        acceptOutcome()
    }
    func startMotion() {
        guard activityVisible else { return }
        ngaseuk.prepareStoryActivity()
        ngaseuk.startMotion()
    }
    func demonstrate() {
        guard activityVisible else { return }
        ngaseuk.beginStoryDemonstration()
    }
    func replay() {
        ngaseuk.start()
        // Never remove already revealed sections, even while replay is incomplete.
    }
}
