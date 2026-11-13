import SwiftUI

struct NgaseukSeedPeekView: View {
    let model: NgaseukViewModel
    let target: Int
    var dragActive = false
    var canPlant = false
    private var filled: Bool { model.seeds.contains(target) }
    private var isPourSequenceActive: Bool { model.isBasketEntering || model.isBasketTilting || model.isPouring }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 3D SceneKit Viewport: 3D soil ground plane, excavated dibble hole, and 3D golden seeds
                SeedPeek3DSceneView(filled: filled, isPouring: model.isPouring)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                if isPourSequenceActive {
                    NgaseukPouringBowl(
                        size: geometry.size,
                        isEntering: model.isBasketEntering,
                        isTilting: model.isBasketTilting || model.isPouring
                    )
                }

                if dragActive && !filled {
                    Circle()
                        .stroke(canPlant ? AppTheme.heading : AppTheme.cream.opacity(0.78),
                                style: StrokeStyle(lineWidth: canPlant ? 4 : 2, dash: canPlant ? [] : [7, 6]))
                        .background(Circle().fill((canPlant ? AppTheme.earth : AppTheme.cream).opacity(canPlant ? 0.32 : 0.08)))
                        .overlay(Circle().stroke(AppTheme.action.opacity(canPlant ? 0.82 : 0.34), lineWidth: canPlant ? 7 : 4).blur(radius: 5))
                        .frame(width: canPlant ? 116 : 96, height: canPlant ? 116 : 96)
                        .shadow(color: canPlant ? AppTheme.heading.opacity(0.35) : .clear, radius: 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .animation(.easeOut(duration: 0.16), value: canPlant)
                }

                // Header Information Card
                VStack(spacing: 8) {
                    Text("Lubang \(target + 1)").font(.title2.bold())
                    Text(statusText)
                        .font(.headline).multilineTextAlignment(.center)
                    if !dragActive && !filled && !model.motionActive && !isPourSequenceActive {
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
                    if !dragActive && !filled {
                        LessonButton(title: model.isBasketEntering ? "Baskom mendekat…" : (model.isBasketTilting ? "Memiringkan baskom…" : (model.isPouring ? "Menuang benih…" : "Tuang \(NgaseukViewModel.seedsPerHole) benih")),
                                     identifier: "ngaseuk.peek.pour",
                                     action: { model.pourSeeds() })
                            .disabled(isPourSequenceActive)
                    }
                    if !dragActive && !isPourSequenceActive {
                        Button(filled ? "Pilih lubang berikutnya" : "Kembali ke lahan", action: { model.closePeek() })
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
                }
                .padding(.horizontal, 28)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 48)
            }
            .allowsHitTesting(!dragActive)
        }
        .accessibilityLabel("Tampilan dekat lubang tanam 3 dimensi")
    }

    private var statusText: String {
        if model.isBasketEntering { return "Baskom mendekat dari atas…" }
        if model.isBasketTilting { return "Baskom dimiringkan sebelum benih dituangkan…" }
        if model.isPouring { return "4 benih jatuh ke dalam lubang…" }
        if filled { return "Benih sudah masuk" }
        if dragActive { return canPlant ? "Lepaskan untuk menanam 4 benih" : "Dekatkan baskom ke lubang" }
        return "Gerakkan ponsel perlahan bolak-balik untuk menuang benih"
    }
}

private struct NgaseukPouringBowl: View {
    let size: CGSize
    let isEntering: Bool
    let isTilting: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasEntered = false

    var body: some View {
        RiceSeed3DView(isDragging: true)
            .scaleEffect(0.82)
            .rotation3DEffect(.degrees(isTilting ? 34 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
            .rotationEffect(.degrees(isTilting ? -65 : 0))
            .position(x: size.width / 2, y: size.height * 0.28)
            .offset(y: hasEntered ? 0 : -size.height * 0.42)
            .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 8)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { hasEntered = true; return }
                withAnimation(.easeOut(duration: 0.42)) { hasEntered = true }
            }
            .animation(.easeInOut(duration: 0.42), value: isTilting)
            .animation(.easeInOut(duration: 0.42), value: isEntering)
    }
}
