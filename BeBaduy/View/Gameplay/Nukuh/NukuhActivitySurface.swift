import SceneKit
import SwiftUI

struct NukuhActivitySurface: View {
    let model: NukuhViewModel
    @Environment(ActivityCardState.self) private var card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NukuhSurface(scene: model.scene)
            .ignoresSafeArea()
            .accessibilityLabel("Lahan Nukuh tiga dimensi")
            .accessibilityIdentifier("nukuh.field")
            .overlay(alignment: .top) {
                if model.stage == .clearing && card.mode == .hidden && !model.isDemonstrating {
                    Text("Pohon ditebang: \(model.collected.count)/6")
                        .font(.subheadline.monospacedDigit())
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(AppTheme.heading.opacity(0.35), in: Capsule())
                        .padding(.top, 65)
                        .allowsHitTesting(false)
                }
                if (model.stage == .prepared || model.stage == .burning) && card.mode == .hidden && model.ignited.count < 6 && !model.isDemonstrating {
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
            .onChange(of: model.ignited.count) { _, count in
                if count == 6 && !model.isDemonstrating { card.showInstruction() }
            }
            .onChange(of: model.stage) { _, stage in
                if stage == .prepared && !model.isDemonstrating {
                    card.showInstruction()
                }
            }
    }
}

