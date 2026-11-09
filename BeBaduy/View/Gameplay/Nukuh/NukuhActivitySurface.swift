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
            .accessibilityIdentifier("nukuh.field")
            .overlay(alignment: .top) {
                if (model.stage == .prepared || model.stage == .burning) && model.ignited.count < 6 && !model.isDemonstrating {
                    Text("Ketuk setiap lahan untuk menyalakan api · \(model.ignited.count)/6")
                        .font(.headline).multilineTextAlignment(.center).padding(16)
                        .foregroundStyle(.white).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 24).padding(.top, 70)
                        .allowsHitTesting(false).accessibilityIdentifier("nukuh.fire.hint")
                }
            }
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
            .onChange(of: model.stage) { _, stage in
                if stage == .prepared && !model.isDemonstrating {
                    sheet.collapse()
                }
            }
    }
}

