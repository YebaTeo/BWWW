import SwiftUI

/// 3D Traditional Baduy "Kored" (weeding hoe) rendered in SceneKit.
struct KoredTool: View {
    var isDragging = false
    var swingCount = 0
    var bladeCentered = false
    var body: some View {
        Kored3DView(isDragging: isDragging, swingCount: swingCount, bladeCentered: bladeCentered)
            .accessibilityHidden(true)
    }
}
