import SwiftUI
import Observation

/// Owns preview selection and cancellable playback.
@Observable @MainActor
final class HomePreviewViewModel {
    private(set) var progress: CGFloat = 0
    private(set) var isTransitioning = false
    private(set) var selectedStage = 0
    @ObservationIgnored private var transitionTask: Task<Void, Never>?
    var isPlayingHarvestTransition: Bool { isTransitioning && selectedStage == 3 }
    var stage: GrowthStage { GrowthStage.currentStage(for: progress) }

    func stop() {
        transitionTask?.cancel()
        transitionTask = nil
        isTransitioning = false
        progress = GrowthStage.allStages[selectedStage].targetProgress
    }

    func canMove(direction: Int, journey: JourneyProgress) -> Bool {
        guard !isTransitioning, direction == -1 || direction == 1 else { return false }
        let destination = selectedStage + direction
        return GrowthStage.allStages.indices.contains(destination)
            && GrowthStage.allStages[destination].isAvailable(in: journey)
    }

    func swipe(direction: Int, journey: JourneyProgress, reduceMotion: Bool) {
        guard canMove(direction: direction, journey: journey) else { return }
        selectStage(selectedStage + direction, journey: journey, reduceMotion: reduceMotion)
    }

    func selectStage(_ index: Int, journey: JourneyProgress, reduceMotion: Bool) {
        guard GrowthStage.allStages.indices.contains(index),
              GrowthStage.allStages[index].isAvailable(in: journey) else { return }
        let previousStage = stage.id
        transitionTask?.cancel()
        selectedStage = index
        if reduceMotion {
            progress = GrowthStage.allStages[index].targetProgress
            isTransitioning = false
        } else {
            isTransitioning = true
            // Preserve the full home time-lapse as the rice matures toward harvest.
            let isHarvestTimeLapse = (previousStage == 2 && index == 3) || (previousStage == 3 && index == 2)
            let isForestClearing = (previousStage == 0 && index == 1) || (previousStage == 1 && index == 0)
            let isLeuitTransition = (previousStage <= 4 && index >= 5) || (previousStage >= 5 && index <= 4) || (previousStage == 5 && index == 6) || (previousStage == 6 && index == 5)
            let isConclusionPan = (previousStage == 5 && index == 6) || (previousStage == 6 && index == 5)
            let start = progress
            let destination = GrowthStage.allStages[index].targetProgress
            let duration: Double = isConclusionPan ? 0.18 : (isHarvestTimeLapse ? 10 : (isLeuitTransition ? 1.35 : (isForestClearing ? 7.2 : 0.23)))
            // Custom scene inputs need actual intermediate state values;
            // withAnimation alone only interpolates animatable view properties.
            transitionTask = Task { @MainActor in
                let clock = ContinuousClock()
                let began = clock.now
                while !Task.isCancelled {
                    let elapsed = began.duration(to: clock.now).components
                    let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                    let fraction = min(1, seconds / duration)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        progress = start + (destination - start) * CGFloat(fraction)
                    }
                    if fraction >= 1 {
                        isTransitioning = false
                        break
                    }
                    do { try await Task.sleep(for: .milliseconds(isConclusionPan ? 8 : 33)) }
                    catch { return }
                }
            }
        }
    }
}
