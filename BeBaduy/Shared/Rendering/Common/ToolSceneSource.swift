import SceneKit

/// Consumers clone the root before changing any node transforms.
enum ToolSceneSource {
    private static let scenes = NSCache<NSURL, SCNScene>()

    static func load(_ url: URL) -> SCNScene? {
        let key = url as NSURL
        if let scene = scenes.object(forKey: key) { return scene }
        guard let scene = try? SCNScene(url: url, options: nil) else { return nil }
        scenes.setObject(scene, forKey: key)
        return scene
    }
}
