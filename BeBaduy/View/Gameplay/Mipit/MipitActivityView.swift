import SwiftUI

struct MipitActivityView: View {
    let model: MipitViewModel
    @Binding var showsHelp: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }.accessibilityLabel("Kembali ke beranda").accessibilityIdentifier("lesson.back")
                Spacer()
                if model.step == .harvesting {
                    if !showsHelp {
                        Button { showsHelp = true } label: {
                            Image(systemName: "questionmark.circle").frame(width: 44, height: 44)
                        }.accessibilityLabel("Buka petunjuk")
                    }
                }
            }
            Spacer(minLength: 0)
            switch model.step {
            case .harvesting:
                if showsHelp {
                    panel {
                        Text("Panen dengan etem").font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(AppTheme.heading)
                        Text("Cubit padi dengan dua jari untuk memotong batangnya.")
                        LessonButton(title: "Mulai", identifier: "mipit.card.start") { showsHelp = false }
                        Button("Lihat demonstrasi") { showsHelp = false; model.demonstrate() }
                            .frame(minHeight: 44).accessibilityIdentifier("demonstrate")
                    }
                } else {
                VStack(spacing: 8) {
                    Text("Cubit padi dengan dua jari untuk memanen.").font(.subheadline)
                    HStack {
                        ForEach(0..<MipitViewModel.harvestCount, id: \.self) { index in
                            if model.harvested.contains(index) {
                                MipitRiceBundle().frame(width: 23, height: 34).accessibilityHidden(true)
                            }
                        }
                        Text("\(model.harvested.count) / \(MipitViewModel.harvestCount) malai terkumpul")
                    }.accessibilityElement(children: .combine)
                }.padding(12).background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 16))
                }
            case .harvestSuccess:
                panel {
                    Text("Padi berhasil dipanen!").font(.headline)
                    LessonButton(title: "Lihat hasil", identifier: "mipit.rotate", action: model.finishHarvest)
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .disabled(model.isDemonstrating)
    }

    private func panel(@ViewBuilder content: () -> some View) -> some View {
        ActivityCardPanel(content: content)
    }
}
