import SwiftUI
struct NgaseukActivityView: View {
    let model: NgaseukViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Aseuk · \(model.holes.count) dari 3 lubang", systemImage: "line.diagonal").font(.headline)
            Text(model.motionActive ? "Ketuk untuk memilih sasaran. Gerakan lembut membuat lubangnya." : "Ketuk sasaran untuk membuat lubang dan menaruh benih.")
            plantingScene
            ForEach(0..<3) { target in
                ActivityChoice(title: "\(model.holes.contains(target) ? "Benih di lubang" : "Tanam di tanda") \(target + 1)",
                               symbol: model.motionActive && target == model.selectedTarget ? "scope" : "circle.dashed",
                               done: model.holes.contains(target), identifier: "plant_\(target)") {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { model.tap(target) }
                }
            }
            if model.motionActive {
                Button("Gunakan sentuhan") { model.pauseMotion() }.frame(minHeight: 44)
            } else {
                Button("Mulai gerakan ponsel (opsional)") { model.startMotion() }.frame(minHeight: 44)
            }
        }
    }
    private var plantingScene: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(AppTheme.earth.opacity(0.14))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 130))
                    path.addQuadCurve(to: CGPoint(x: geometry.size.width, y: 140), control: CGPoint(x: geometry.size.width / 2, y: 100))
                }.stroke(AppTheme.earth.opacity(0.35), lineWidth: 2)
                ForEach(0..<3) { index in
                    let planted = model.holes.contains(index)
                    Ellipse().fill(planted ? AppTheme.earth : .clear)
                        .overlay(Ellipse().strokeBorder(AppTheme.earth, style: StrokeStyle(lineWidth: 2, dash: planted ? [] : [4, 4])))
                        .frame(width: 40, height: 19)
                        .overlay { if planted { SeedMark(reduceMotion: reduceMotion) } }
                        .position(x: geometry.size.width * CGFloat(index + 1) / 4, y: 144)
                }
                Capsule().fill(AppTheme.earth).frame(width: 9, height: 90)
                    .rotationEffect(.degrees(16))
                    .position(x: geometry.size.width * CGFloat((model.motionActive ? model.selectedTarget : (model.lastPlanted ?? model.selectedTarget)) + 1) / 4 + 15, y: 88)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.lastPlanted)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.selectedTarget)
            }
        }.frame(height: 186).accessibilityHidden(true)
    }
}
private struct SeedMark: View {
    let reduceMotion: Bool
    @State private var visible = false
    var body: some View {
        HStack(spacing: 2) {
            Capsule().fill(Color.yellow).frame(width: 7, height: 3)
            Capsule().fill(Color.yellow).frame(width: 7, height: 3).rotationEffect(.degrees(25))
        }
        .opacity(visible ? 1 : 0).offset(y: visible ? 0 : -18)
        .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(0.2)) { visible = true } }
    }
}
