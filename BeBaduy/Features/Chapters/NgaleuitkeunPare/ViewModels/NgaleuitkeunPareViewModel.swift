import Observation
import UIKit

@Observable @MainActor final class NgaleuitkeunPareViewModel {
    var session = PhaseSessionState()
    private(set) var isLadderPlaced = false
    private(set) var ladderDragX: Float = 0
    private(set) var ladderDragY: Float = 0
    private(set) var climbProgress: Float = 0
    private(set) var doorOpening: Float = 0
    private(set) var enteringProgress: Float = 0
    private var usedDemo = false

    var sceneState: LeuitActivitySceneState {
        LeuitActivitySceneState(ladderPlaced: isLadderPlaced, dragX: ladderDragX,
                                dragY: ladderDragY, climbProgress: climbProgress,
                                doorOpening: doorOpening, enteringProgress: enteringProgress)
    }

    func start() {
        isLadderPlaced = false
        ladderDragX = 0; ladderDragY = 0; climbProgress = 0
        doorOpening = 0; enteringProgress = 0
        usedDemo = false
        session.start()
    }

    func placeLadder() {
        guard session.isActive, !isLadderPlaced else { return }
        isLadderPlaced = true
        ladderDragX = 0; ladderDragY = 0
        ActivityAudio.shared.play(.bamboo)
        if !usedDemo { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    }

    func moveLadder(x: Float, y: Float) {
        guard session.isActive, !isLadderPlaced else { return }
        ladderDragX = x
        ladderDragY = y
    }

    func setClimbProgress(_ value: Float) { climbProgress = value }
    func setDoorOpening(_ value: Float) { doorOpening = value }
    func setEnteringProgress(_ value: Float) { enteringProgress = value }

    func finish() {
        guard session.isActive, isLadderPlaced else { return }
        session.finish(usedDemo ? .observed : .performed)
    }

    func demonstrate() {
        guard session.isActive, !isLadderPlaced else { return }
        usedDemo = true
        placeLadder()
    }
}
