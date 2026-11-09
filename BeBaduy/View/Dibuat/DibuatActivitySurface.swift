import SwiftUI
struct DibuatActivitySurface: View {
    let model: DibuatViewModel
    @Environment(ActivitySheetState.self) private var sheet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var asset: String {
        switch model.step {
        case .harvesting: "dibuat_before"
        case .balanceInstructions, .balancing: "drying_rice_before"
        case .drying: "drying_rice_after"
        }
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ActivityPhoto(asset: asset)
                    .scaleEffect(model.step == .balancing ? 1.25 : 1)
                    .rotationEffect(.degrees(model.step == .balancing && !reduceMotion ? model.balance * 12 : 0))
                if model.step == .harvesting {
                    ForEach(0..<4) { index in
                        if !model.harvested.contains(index) {
                            FieldTarget(title: "\(index + 1)", symbol: "laurel.leading") { model.harvest(index) }
                                .frame(width: 130, height: 100).contentShape(Rectangle())
                                .simultaneousGesture(MagnifyGesture().onEnded { value in
                                    if value.magnification < 0.85 { model.harvest(index) }
                                })
                                .accessibilityLabel("Panen malai \(index + 1)")
                                .accessibilityIdentifier("field.harvest.\(index)")
                                .position(x: geometry.size.width * (index % 2 == 0 ? 0.28 : 0.72),
                                          y: geometry.size.height * (index < 2 ? 0.25 : 0.42))
                        }
                    }
                }
            }.clipped().disabled(model.isDemonstrating)
        }.onChange(of: model.step) { _, step in
            sheet.expand()
        }
    }
}
