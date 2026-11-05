import SwiftUI

struct NgaseukStoryActivityView: View {
    let model: NgaseukViewModel
    let unlocked: Bool
    let plant: (Int) -> Void
    let motion: () -> Void
    let demonstrate: () -> Void
    let replay: () -> Void
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.storyPreviewReduceMotion) private var previewReduceMotion
    private var reduceMotion: Bool { systemReduceMotion || previewReduceMotion }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Membuka tempat untuk benih").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text(model.motionActive ? NgaseukContent.storyMotionInstruction : NgaseukContent.storyInstruction)
            soilScene
            Text("\(model.storyHoles.count) dari 3 lubang berisi benih").font(.headline)
                .accessibilityIdentifier("story.plantingProgress")
            Text(model.session.feedback.isEmpty ? "Benih akan ditempatkan setelah lubang dibuat." : model.session.feedback)
                .font(.subheadline).foregroundStyle(.white)
            // Keep secondary controls in the layout during completion/replay.
            // Adding the next sections never removes the current activity surface.
            Button {
                if model.motionActive { model.stopStoryInteraction() } else { motion() }
            } label: {
                Text(model.motionActive ? "Gunakan sentuhan" : "Aktifkan gerakan lembut (opsional)")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.disabled(model.session.showsDescription)
                .accessibilityIdentifier("story.motion")
            HStack(spacing: 16) {
            Button {
                if model.isDemonstrating { model.cancelStoryDemonstration() } else { demonstrate() }
            } label: {
                Text(model.isDemonstrating ? "Hentikan contoh" : "Lihat caranya")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.disabled(model.session.showsDescription)
                .accessibilityHint("Amati tiga penanaman. Cerita terbuka setelah contoh selesai.")
                .accessibilityIdentifier("story.demonstrate")
            Button(action: replay) {
                Text("Coba lagi").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.accessibilityIdentifier("story.replay")
            }
            StoryScrollCue(text: unlocked ? "Geser ke atas untuk melihat hasilnya" : "Buat tiga lubang untuk melanjutkan.")
                .accessibilityIdentifier("story.gate")
        }
    }

    private var soilScene: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 105))
                    path.addQuadCurve(to: CGPoint(x: geometry.size.width, y: 125),
                        control: CGPoint(x: geometry.size.width / 2, y: 85))
                    path.move(to: CGPoint(x: 0, y: 175))
                    path.addQuadCurve(to: CGPoint(x: geometry.size.width, y: 185),
                        control: CGPoint(x: geometry.size.width / 2, y: 150))
                }.stroke(AppTheme.earth.opacity(0.25), lineWidth: 2).accessibilityHidden(true)
                Capsule().fill(AppTheme.earth).frame(width: 10, height: 115)
                    .rotationEffect(.degrees(16))
                    .position(x: x(model.storyTarget, width: geometry.size.width) + 18,
                              y: y(model.storyTarget) - 70)
                    .allowsHitTesting(false).accessibilityHidden(true)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.storyTarget)
                ForEach(0..<3) { target in
                    let planted = model.storyHoles.contains(target)
                    Button {
                        plant(target) // Only the aseuk and seeds animate; section insertion stays unanimated.
                    } label: {
                        ZStack {
                            Ellipse().fill(planted ? AppTheme.earth : AppTheme.background.opacity(0.7))
                            Ellipse().strokeBorder(AppTheme.earth, style: StrokeStyle(lineWidth: 2, dash: planted ? [] : [5, 4]))
                            if planted {
                                StorySeeds(reduceMotion: reduceMotion)
                            } else {
                                Image(systemName: "plus").resizable().scaledToFit()
                                    .frame(width: 14, height: 14).foregroundStyle(AppTheme.earth)
                                    .accessibilityHidden(true)
                            }
                        }.frame(width: 70, height: 48).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: x(target, width: geometry.size.width), y: y(target))
                    .accessibilityLabel("Sasaran tanam \(target + 1)")
                    .accessibilityValue(planted ? "Sudah berisi benih" : "Belum ditanam")
                    .accessibilityHint(model.motionActive ? "Pilih sasaran untuk gerakan aseuk" : "Buat lubang dan tempatkan benih")
                    .accessibilityIdentifier("story.target.\(target)")
                }
            }
        }.frame(height: 190)
    }
    private func x(_ target: Int, width: CGFloat) -> CGFloat { width * CGFloat(target + 1) / 4 }
    private func y(_ target: Int) -> CGFloat { 85 + CGFloat(target) * 40 }
}

private struct StorySeeds: View {
    let reduceMotion: Bool
    @State private var arrived = false
    var body: some View {
        HStack(spacing: 3) {
            Capsule().fill(Color.yellow).frame(width: 11, height: 5)
            Capsule().fill(Color.yellow).frame(width: 11, height: 5).rotationEffect(.degrees(25))
        }
        .offset(y: arrived ? 0 : -20).opacity(arrived ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(0.15)) { arrived = true }
        }
    }
}
