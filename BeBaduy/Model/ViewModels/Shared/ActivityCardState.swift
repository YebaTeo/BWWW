import Observation

@Observable @MainActor final class ActivityCardState {
    enum Mode { case hidden, instruction, help }
    private(set) var mode = Mode.hidden
    private(set) var revision = 0

    func showInstruction() { mode = .instruction; revision += 1 }
    func showHelp() { mode = .help; revision += 1 }
    func dismiss() { mode = .hidden }
}
