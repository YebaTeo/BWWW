#if DEBUG
import Foundation

/// Supplies three downward strokes to the motion-only activity in UI tests.
@MainActor final class NgaseukUITestMotion: MotionProviding {
    let available = true
    private var task: Task<Void, Never>?

    func start(handler: @escaping @MainActor (MotionSample?) -> Void) {
        stop()
        task = Task {
            for stroke in 0..<9 {
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
                let time = Double(stroke) * 1.1
                handler(.init(time: time, verticalAcceleration: 0))
                handler(.init(time: time + 0.1, verticalAcceleration: -0.90))
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
