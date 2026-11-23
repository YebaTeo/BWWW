import Foundation

@MainActor protocol MotionProviding: AnyObject {
    var available: Bool { get }
    var supportsPolling: Bool { get }
    func start(handler: @escaping @MainActor (MotionSample?) -> Void)
    func beginPolling()
    func currentSample() -> MotionSample?
    func stop()
}

extension MotionProviding {
    var supportsPolling: Bool { false }
    func beginPolling() {}
    func currentSample() -> MotionSample? { nil }
}

