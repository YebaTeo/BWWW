#if DEBUG
import Foundation

/// Supplies three downward strokes to the motion-only activity in UI tests.
@MainActor final class NgaseukUITestMotion: MotionProviding {
    let available = true
    private var task: Task<Void, Never>?

    func start(handler: @escaping @MainActor (MotionSample?) -> Void) {
        stop()
        task = Task {
            for stroke in 0..<3 {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                let time = Double(stroke)
                handler(.init(time: time, verticalAcceleration: 0))
                handler(.init(time: time + 0.1, verticalAcceleration: -0.5))
                guard !Task.isCancelled else { return }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
#endif
