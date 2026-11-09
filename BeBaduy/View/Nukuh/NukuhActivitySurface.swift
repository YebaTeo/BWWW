import SceneKit
import SwiftUI

struct NukuhActivitySurface: View {
    let model: NukuhViewModel
    @Environment(ActivitySheetState.self) private var sheet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NukuhSurface(scene: model.scene)
            .ignoresSafeArea()
            .accessibilityLabel("Lahan Nukuh tiga dimensi")
            .task {
                model.configureLookMotion(reduceMotion: reduceMotion)
                model.scene.muted = !ActivityAudio.shared.enabled
                await model.scene.prepareAssets()
                await model.scene.loadAudio()
            }
            .onChange(of: ActivityAudio.shared.enabled) { _, enabled in
                model.scene.muted = !enabled
            }
            .onChange(of: reduceMotion) { _, value in
                model.configureLookMotion(reduceMotion: value)
            }
            .onChange(of: model.scene.stage) { _, stage in
                if stage == .prepared {
                    sheet.expand()
                }
            }
    }
}

