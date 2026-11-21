import SceneKit

/// Keep SceneKit and its simulation clock at the same sustainable cadence.
@MainActor
final class SceneFrameBudget: NSObject {
    private weak var view: SCNView?
    private weak var link: CADisplayLink?
    private let normalFPS: Int

    init(view: SCNView, link: CADisplayLink, normalFPS: Int) {
        self.view = view
        self.link = link
        self.normalFPS = normalFPS
        super.init()
        for name in [ProcessInfo.thermalStateDidChangeNotification, Notification.Name.NSProcessInfoPowerStateDidChange] {
            NotificationCenter.default.addObserver(self, selector: #selector(changed), name: name, object: nil)
        }
        apply()
    }

    @objc nonisolated private func changed() {
        Task { @MainActor in self.apply() }
    }

    private func apply() {
        let process = ProcessInfo.processInfo
        let fps: Int
        switch process.thermalState {
        case .critical: fps = 20
        case .serious: fps = 30
        default: fps = process.isLowPowerModeEnabled ? 30 : normalFPS
        }
        view?.preferredFramesPerSecond = fps
        link?.preferredFramesPerSecond = fps
    }
}
