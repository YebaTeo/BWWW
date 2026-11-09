import SwiftUI

struct DibuatActivityView: View {
    let model: DibuatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }.accessibilityLabel("Kembali ke beranda").accessibilityIdentifier("lesson.back")
                Spacer()
                if model.step == .balancing {
                    Button("Petunjuk", action: model.showHelp).frame(minHeight: 44)
                }
                if model.step == .harvesting || model.step == .awaitingLandscape || model.step == .balanceInstructions {
                    Button("Lihat demonstrasi", action: model.demonstrate).frame(minHeight: 44)
                        .accessibilityIdentifier("demonstrate")
                }
            }
            Spacer(minLength: 0)
            switch model.step {
            case .harvesting:
                VStack(spacing: 8) {
                    Text("Cubit atau ketuk malai untuk memanen.").font(.subheadline)
                    HStack {
                        ForEach(0..<DibuatViewModel.harvestCount, id: \.self) { index in
                            if model.harvested.contains(index) {
                                DibuatRiceBundle().frame(width: 23, height: 34).accessibilityHidden(true)
                            }
                        }
                        Text("\(model.harvested.count) / \(DibuatViewModel.harvestCount) malai terkumpul")
                    }.accessibilityElement(children: .combine)
                }.padding(12).background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 16))
            case .harvestSuccess:
                panel {
                    Text("Padi berhasil dipanen!").font(.headline)
                    Button("Siap menyeimbangkan", action: model.requestLandscape)
                        .accessibilityIdentifier("dibuat.rotate")
                }
            case .awaitingLandscape:
                panel {
                    Image(systemName: "iphone.landscape").font(.title)
                    Text("Putar ponsel ke posisi mendatar.").font(.headline)
                    Text("Jika layar tidak berputar, periksa kunci rotasi atau lihat demonstrasi.")
                }
            case .balanceInstructions:
                panel {
                    Text("Jaga keseimbangan bambu").font(.headline)
                    Text("Miringkan ponsel perlahan ke kiri atau kanan. Tahan bambu tetap rata selama tiga detik.")
                    Button("Mulai", action: model.beginBalance).accessibilityIdentifier("dibuat.balance.continue")
                }
            case .balancing:
                VStack(spacing: 4) {
                    ProgressView(value: model.steadyTime, total: 3).accessibilityLabel("Waktu seimbang")
                    Text(abs(model.balance) < 0.18 ? "Seimbang · tahan sebentar" : "Arahkan bambu ke tengah")
                        .font(.caption)
                    if model.usesTouch {
                        Slider(value: Binding(get: { model.balance }, set: { model.setBalance($0) }), in: -1...1)
                            .accessibilityLabel("Keseimbangan bambu").accessibilityIdentifier("dibuat.balance.slider")
                        Button("Ratakkan bambu") { model.setBalance(0) }
                            .frame(minHeight: 44).accessibilityIdentifier("dibuat.balance.center")
                    } else {
                        Button("Gunakan sentuhan", action: model.useTouch).frame(minHeight: 44)
                            .accessibilityIdentifier("dibuat.balance.touch")
                    }
                }.padding(.horizontal, 16).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 320)
            case .balanceDemo:
                VStack {
                    Text("Demonstrasi keseimbangan")
                    ProgressView(value: model.steadyTime, total: 3)
                }.padding(12).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 16))
            case .awaitingPortrait:
                panel { Text("Tegakkan ponsel untuk melihat padi dijemur.").font(.headline) }
            case .drying:
                panel {
                    Text("Padi dijemur").font(.headline)
                    Button("Lihat hasil", action: model.finishDrying).accessibilityIdentifier("dibuat.drying.continue")
                }
            case .complete:
                EmptyView()
            }
            if model.step == .balanceInstructions || model.step == .awaitingLandscape {
                Spacer(minLength: 0)
            }
        }.padding(.horizontal, 16).padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .disabled(model.isDemonstrating)
    }

    private func panel(@ViewBuilder content: () -> some View) -> some View {
        ViewThatFits(in: .vertical) {
            panelContent(content)
            ScrollView { panelContent(content) }
        }.frame(maxWidth: 400)
    }

    private func panelContent<Content: View>(_ content: () -> Content) -> some View {
        VStack(spacing: 8, content: content)
            .multilineTextAlignment(.center)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(16)
            .background(.black.opacity(0.83), in: RoundedRectangle(cornerRadius: 20))
    }
}
