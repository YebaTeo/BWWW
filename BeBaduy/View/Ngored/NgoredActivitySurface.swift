import SwiftUI
struct NgoredActivitySurface: View {
    let model: NgoredViewModel
    @Environment(ActivitySheetState.self) private var sheet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ActivityPhoto(asset: "ngored_after")
                if model.step == .weeding {
                    ForEach(0..<8) { index in
                        if !model.removed.contains(index) {
                            FieldTarget(title: "\(index + 1)", symbol: "leaf.fill") { model.remove(index) }
                                .accessibilityLabel("Cabut gulma \(index + 1)")
                                .accessibilityIdentifier("field.weed.\(index)")
                                .position(x: geometry.size.width * CGFloat(index % 4 + 1) / 5,
                                          y: geometry.size.height * (index < 4 ? 0.27 : 0.42))
                        }
                    }
                }
                if model.step == .rain {
                    TimelineView(.animation(minimumInterval: 0.05, paused: reduceMotion || scenePhase != .active || !model.session.isActive)) { timeline in
                        Canvas { context, size in
                            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                            for i in 0..<80 {
                                let x = CGFloat((i * 73) % 313) / 313 * size.width
                                let y = CGFloat((Double(i * 19) + time * 180).truncatingRemainder(dividingBy: size.height + 20))
                                var path = Path(); path.move(to: CGPoint(x: x, y: y)); path.addLine(to: CGPoint(x: x - 4, y: y + 18))
                                context.stroke(path, with: .color(.white.opacity(0.65)), lineWidth: 1)
                            }
                        }
                    }.allowsHitTesting(false).accessibilityHidden(true)
                }
            }.disabled(model.isDemonstrating)
        }.onChange(of: model.step) { _, step in
            sheet.expand()
        }
    }
}
