import SwiftUI

struct MipitActivityView: View {
    let model: MipitViewModel
    @Binding var showsHelp: Bool
    @Environment(\.dismiss) private var dismiss

    private let instruction = "Cubit layar untuk memotong batang pare menggunakan etem."

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Kembali ke beranda")
                .accessibilityIdentifier("lesson.back")
                Spacer()
            }
            .padding(.horizontal, 16)

            switch model.step {
            case .harvesting:
                if showsHelp {
                    ActivityCardLayout(placement: .middle) {
                        ActivityCardPanel {
                            ActivityCardHeading("Panen dengan etem")
                            Text(instruction)
                        }
                        ActivityAcknowledgement(title: "Mulai atau kembali memanen", identifier: "mipit.card.start") {
                            showsHelp = false
                        }
                    }
                } else {
                    ActivityCardLayout(placement: .bottom) {
                        ViewThatFits(in: .horizontal) {
                            HStack {
                                ForEach(0..<model.harvested.count, id: \.self) { _ in
                                    MipitRiceBundle().frame(width: 23, height: 34).accessibilityHidden(true)
                                }
                                harvestCount.fixedSize()
                            }
                            harvestCount
                        }
                        .activityCounterStyle()
                        ActivityCardPanel(passesTouchesThrough: true) {
                            Text(instruction)
                        }
                    }
                }
            case .harvestSuccess:
                ActivityCardLayout(placement: .middle) {
                    ActivityCardPanel { ActivityCardHeading("Akhirnya, proses panen sudah selesai!") }
                    ActivityAcknowledgement(title: "Lihat hasil", identifier: "mipit.rotate", action: model.finishHarvest)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(model.isDemonstrating)
    }

    private var harvestCount: some View {
        Text("\(model.harvested.count) / \(MipitViewModel.harvestCount) padi terkumpul")
            .font(.subheadline.monospacedDigit())
    }
}
