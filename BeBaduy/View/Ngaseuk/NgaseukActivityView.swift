import SwiftUI
struct NgaseukActivityView: View {
    let model: NgaseukViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch model.step {
            case .instructions:
                InstructionCard(title: "Buat tempat untuk benih", message: "Ketuk satu tanda di tanah. Aseuk akan menancap, membuat lubang, lalu terangkat kembali. Ulangi pada tiga tempat. Kamu juga bisa mengaktifkan gerakan ponsel yang lembut.", identifier: "ngaseuk.instructions", action: model.proceed)
            case .digging:
                Text("\(model.holes.count) / 3 lubang").font(.headline)
                Text("Ketuk satu tanda di tanah dan amati ujung aseuk masuk lalu terangkat. Tarik panel ke bawah untuk melihat lahan.")
                ForEach(0..<3) { index in
                    ActivityChoice(title: "Buat lubang \(index + 1)", done: model.holes.contains(index), identifier: "dig_\(index)") { model.dig(index) }
                }
                Button(model.motionActive ? "Gunakan sentuhan" : "Gunakan gerakan lembut") {
                    if model.motionActive { model.pauseMotion() } else { model.startMotion() }
                }.frame(minHeight: 44)
            case .holesReady:
                InstructionCard(title: "Tanah berhasil dilubangi", message: "Ketuk lubang untuk melihat ke dalam. Gerakkan ponsel perlahan bolak-balik untuk menuang benih, atau ketuk Tuang benih.", identifier: "ngaseuk.seeds", action: model.proceed)
            case .seeding:
                Text("Ketuk lubang di lahan untuk melihat ke dalam dan menuang benih. Pilihan di bawah juga dapat langsung mengisi lubang.")
                Text("\(model.seeds.count) / 3 lubang berisi benih").font(.headline)
                ForEach(0..<3) { index in
                    ActivityChoice(title: "Isi lubang \(index + 1)", symbol: "leaf", done: model.seeds.contains(index), identifier: "seed_\(index)") { model.seed(index) }
                }
            }
        }.disabled(model.isDemonstrating)
    }
}
