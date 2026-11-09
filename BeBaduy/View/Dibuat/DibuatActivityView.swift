import SwiftUI
struct DibuatActivityView: View {
    let model: DibuatViewModel
    var body: some View {
        VStack(spacing: 18) {
            switch model.step {
            case .harvesting:
                Text("Cubit satu malai untuk memanen").font(.headline)
                Text("Atau ketuk tiap malai. Bulir tetap bersama tangkainya.")
                ForEach(0..<4) { index in
                    ActivityChoice(title: "Panen malai \(index + 1)", symbol: "laurel.leading", done: model.harvested.contains(index), identifier: "harvest_\(index)") { model.harvest(index) }
                        .simultaneousGesture(MagnifyGesture().onEnded { value in
                            if value.magnification < 0.85 { model.harvest(index) }
                        })
                }
            case .balanceInstructions:
                InstructionCard(title: "Malai sudah terkumpul", message: "Seimbangkan ikatan di bambu. Miringkan ponsel perlahan atau geser pengatur ke tengah. Tahan seimbang selama tiga detik.", identifier: "dibuat.balance", action: model.beginBalance)
            case .balancing:
                Text(abs(model.balance) < 0.18 ? "Seimbang · tahan sebentar" : "Arahkan ke tengah")
                ProgressView(value: model.steadyTime, total: 3).accessibilityLabel("Waktu seimbang")
                Slider(value: Binding(get: { model.balance }, set: { model.pauseMotion(); model.setBalance($0) }), in: -1...1)
                    .accessibilityLabel("Keseimbangan ikatan").accessibilityIdentifier("dibuat.balance.slider")
                Button("Seimbangkan dengan sentuhan") { model.pauseMotion(); model.setBalance(0) }.frame(minHeight: 44).accessibilityIdentifier("dibuat.balance.center")
                Button(model.motionActive ? "Gunakan sentuhan" : "Gunakan kemiringan ponsel") {
                    if model.motionActive { model.pauseMotion() } else { model.startMotion() }
                }.frame(minHeight: 44)
            case .drying:
                InstructionCard(title: "Padi dikeringkan", message: "Pengeringan membutuhkan waktu. Setelah cukup kering, padi dapat disimpan di leuit.", identifier: "dibuat.drying", action: model.finishDrying)
            }
        }.disabled(model.isDemonstrating)
    }
}
