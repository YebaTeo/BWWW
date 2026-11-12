import SwiftUI

/// 3D Traditional Baduy "Kored" (weeding hoe) rendered in SceneKit.
struct KoredTool: View {
    var isDragging = false
    var swingCount = 0
    var body: some View {
        Kored3DView(isDragging: isDragging, swingCount: swingCount)
            .accessibilityHidden(true)
    }
}

/// 3D Mountain Weed (Gulma Huma) rendered in SceneKit.
struct NgoredWeedArtwork: View {
    var cut: Bool = false
    var hits: Int = 0

    var body: some View {
        NgoredWeed3DView(cut: cut, hits: hits)
            .accessibilityHidden(true)
    }
}
