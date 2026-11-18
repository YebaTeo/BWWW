import Foundation

@MainActor protocol MotionProviding: AnyObject {
    var available: Bool { get }
    func start(handler: @escaping @MainActor (MotionSample?) -> Void)
    func stop()
}

