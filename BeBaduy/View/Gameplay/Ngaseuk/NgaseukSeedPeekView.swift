import SwiftUI

struct NgaseukSeedPeekView: View {
    let model: NgaseukViewModel
    let target: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var filled: Bool { model.seeds.contains(target) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 3D SceneKit Viewport: 3D soil ground plane, excavated dibble hole, and 3D golden seeds
                SeedPeek3DSceneView(filled: filled, isPouring: model.isPouring)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                // Header Information Card
                VStack(spacing: 8) {
                    Text("Lubang \(target + 1)").font(.title2.bold())
                    Text(filled ? "Benih sudah masuk" : "Gerakkan ponsel perlahan bolak-balik untuk menuang benih")
                        .font(.headline).multilineTextAlignment(.center)
                    if !filled && !model.motionActive && !model.isPouring {
                        Text("Kamu juga bisa menggunakan tombol di bawah.").font(.subheadline)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial.opacity(0.85), in: RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 65)

                // Bottom Action Controls
                VStack(spacing: 12) {
                    if !filled {
                        LessonButton(title: model.isPouring ? "Menuang benih…" : "Tuang benih",
                                     identifier: "ngaseuk.peek.pour",
                                     action: model.pourSeeds)
                            .disabled(model.isPouring)
                    }
                    Button(filled ? "Pilih lubang berikutnya" : "Kembali ke lahan", action: model.closePeek)
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .frame(minHeight: 48)
                        .foregroundStyle(.white)
                        .background(.ultraThinMaterial.opacity(0.92), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.20), lineWidth: 1)
                        )
                        .accessibilityIdentifier("ngaseuk.peek.back")
                }
                .padding(.horizontal, 28)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 48)
            }
        }
        .accessibilityLabel("Tampilan dekat lubang tanam 3 dimensi")
    }
}
