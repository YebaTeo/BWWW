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
            }
            .padding(.horizontal, 16)
            switch model.step {
            case .awaitingLandscape:
                ActivityCardLayout(placement: .middle) {
                    ActivityCardPanel {
                        Image(systemName: "iphone.landscape").font(.title).accessibilityHidden(true)
                        ActivityCardHeading("Layar harus dalam mode lanskap.")
                        Text("Putar ponselmu untuk memulai. Jika layar tidak berputar, periksa kunci rotasi.")
                    }
                }
            case .balanceInstructions:
                ActivityCardLayout(placement: .middle) {
                    ActivityCardPanel {
                        ActivityCardHeading("Jaga keseimbangan Lantaian bambu!")
                        Text("Miringkan ponselmu untuk mengimbangi pergeseran beban padi. Jaga bambu tetap rata hingga bar penuh. Saat bambu miring, bar berkurang perlahan.")
                    }
                    ActivityAcknowledgement(title: "Mulai menjaga keseimbangan", identifier: "ngalantai.balance.continue",
                                            action: model.beginBalance)
                }
            case .balancing:
                ActivityCardLayout(placement: .bottom) {
                    ActivityCardPanel {
                        ProgressView(value: model.steadyTime, total: NgalantaiViewModel.requiredSteadyTime)
                            .tint(AppTheme.orange)
                            .accessibilityLabel("Waktu seimbang")
                        Text(abs(model.balance) < NgalantaiViewModel.balanceTolerance ? "Seimbang · tahan sebentar" : "Arahkan bambu ke tengah")
                    }
                    if model.usesTouch {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 16) {
                                balanceSlider.frame(minWidth: 120)
                                centerButton.fixedSize(horizontal: true, vertical: false)
                            }
                            VStack(spacing: 4) {
                                balanceSlider
                                centerButton
                            }
                        }
                    } else {
                        Button("Gunakan sentuhan", action: model.useTouch)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("ngalantai.balance.touch")
                    }
                }
            case .balanceDemo:
                ActivityCardLayout(placement: .bottom) {
                    ActivityCardPanel {
                        Text("Demonstrasi keseimbangan")
                        ProgressView(value: model.steadyTime, total: NgalantaiViewModel.requiredSteadyTime).tint(AppTheme.orange)
                    }
                }
            case .awaitingPortrait:
                ActivityCardLayout(placement: .middle) {
                    ActivityCardPanel { Text("Tegakkan ponsel untuk melihat padi dijemur.") }
                }
            case .drying:
                ActivityCardLayout(placement: .middle) {
                    ActivityCardPanel {
                        ActivityCardHeading("Bagus!")
                        Text("Sekarang kita jemur pocong hingga kering.")
                    }
                    ActivityAcknowledgement(title: "Lihat hasil", identifier: "ngalantai.drying.continue",
                                            action: model.finishDrying)
                }
            case .complete:
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(model.isDemonstrating)
        .sensoryFeedback(.success, trigger: model.step) { previous, current in
            previous == .balancing && current == .awaitingPortrait
        }
    }

    private var balanceSlider: some View {
        Slider(value: Binding(get: { model.controlBalance }, set: { model.setBalance($0) }), in: -1...1)
            .accessibilityLabel("Keseimbangan bambu")
            .accessibilityIdentifier("ngalantai.balance.slider")
    }

    private var centerButton: some View {
        Button("Ratakkan bambu", action: model.centerBalance)
            .frame(minHeight: 44)
            .accessibilityIdentifier("ngalantai.balance.center")
    }
}
