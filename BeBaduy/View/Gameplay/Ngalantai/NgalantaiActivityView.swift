import SwiftUI

struct NgalantaiActivityView: View {
    let model: NgalantaiViewModel
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
                if model.step == .awaitingLandscape || model.step == .balanceInstructions {
                    Button("Lihat demonstrasi", action: model.demonstrate).frame(minHeight: 44)
                        .accessibilityIdentifier("demonstrate")
                }
            }
            Spacer(minLength: 0)
            switch model.step {
            case .awaitingLandscape:
                panel {
                    Image(systemName: "iphone.landscape").font(.title)
                    Text("Putar ponsel ke posisi mendatar.").font(.system(.title3, design: .rounded).bold()).foregroundStyle(AppTheme.heading)
                    Text("Jika layar tidak berputar, periksa kunci rotasi atau lihat demonstrasi.")
                }
            case .balanceInstructions:
                panel {
                    Text("Jaga keseimbangan bambu").font(.system(.title3, design: .rounded).bold()).foregroundStyle(AppTheme.heading)
                    Text("Miringkan ponsel perlahan ke kiri atau kanan. Tahan bambu tetap rata selama tiga detik.")
                    LessonButton(title: "Mulai", identifier: "ngalantai.balance.continue", action: model.beginBalance)
                }
            case .balancing:
                panel {
                    ProgressView(value: model.steadyTime, total: 3).tint(AppTheme.orange).accessibilityLabel("Waktu seimbang")
                    Text(abs(model.balance) < 0.18 ? "Seimbang · tahan sebentar" : "Arahkan bambu ke tengah")
                        .font(.caption)
                    if model.usesTouch {
                        Slider(value: Binding(get: { model.balance }, set: { model.setBalance($0) }), in: -1...1)
                            .accessibilityLabel("Keseimbangan bambu").accessibilityIdentifier("ngalantai.balance.slider")
                        Button("Ratakkan bambu") { model.setBalance(0) }
                            .frame(minHeight: 44).accessibilityIdentifier("ngalantai.balance.center")
                    } else {
                        Button("Gunakan sentuhan", action: model.useTouch).frame(minHeight: 44)
                            .accessibilityIdentifier("ngalantai.balance.touch")
                    }
                }
            case .balanceDemo:
                panel {
                    Text("Demonstrasi keseimbangan")
                    ProgressView(value: model.steadyTime, total: 3).tint(AppTheme.orange)
                }
            case .awaitingPortrait:
                panel { Text("Tegakkan ponsel untuk melihat padi dijemur.").font(.system(.title3, design: .rounded).bold()).foregroundStyle(AppTheme.heading) }
            case .drying:
                panel {
                    Text("Padi dijemur").font(.system(.title3, design: .rounded).bold()).foregroundStyle(AppTheme.heading)
                    LessonButton(title: "Lihat hasil", identifier: "ngalantai.drying.continue", action: model.finishDrying)
                }
            case .complete:
                EmptyView()
            }
        }.padding(.horizontal, 16).padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .disabled(model.isDemonstrating)
    }

    private func panel(@ViewBuilder content: () -> some View) -> some View {
        ActivityCardPanel(content: content)
    }
}
